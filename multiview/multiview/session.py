"""One multiview: a set of feeds, a layout, and the ffmpeg that tiles them.

The supervisor's job is to keep the stitched playlists growing no matter what
the feeds do. When ffmpeg dies or stops producing, every feed is probed on its
own; the ones that fail are swapped for a "Reconnecting" slate and ffmpeg is
started again without them. Feeds that are down keep being probed, and come
back once they have stayed healthy for a while. Each restart is a short blip
for every tile, which is the trade-off of running a single ffmpeg.
"""

import collections
import concurrent.futures
import os
import shutil
import subprocess
import threading
import time

from . import ffmpeg_cmd
from .layouts import LAYOUTS, tiles_for
from .playlist import StitchedPlaylist, master_playlist, read_media_playlist, write_atomic
from .probe import FeedProbe

TICK = 0.5
PROBE_INTERVAL = 10
# Two misses in a row before a feed that ffmpeg is still reading is pulled:
# one failed fetch is too common to justify blipping every tile
DOWN_AFTER_FAILURES = 2
RECOVER_SECONDS = 20
STARTUP_TIMEOUT = 45
STALL_TIMEOUT = 12
FAILURE_WINDOW = 60
MAX_BACKOFF = 30
RETIRED_GENERATION_GRACE = 30
STITCH_WINDOW = 10


class Feed:
    def __init__(self, spec, probe):
        self.url = spec["url"]
        self.title = spec.get("title") or "Stream"
        self.headers = spec.get("headers") or {}
        self.probe = probe
        self.status = "starting"  # starting | live | down
        self.failures = 0
        self.healthy_since = None
        self.future = None


class Session:
    def __init__(self, session_id, feeds, layout, root_dir, settings,
                 probe_factory=FeedProbe, popen=subprocess.Popen, clock=time.monotonic):
        if layout not in LAYOUTS:
            raise ValueError(f"layout must be one of {', '.join(LAYOUTS)}")
        tiles_for(layout, len(feeds))
        for spec in feeds:
            url = spec.get("url") or ""
            if not url.startswith(("http://", "https://")) and not settings.get("allow_local_inputs"):
                raise ValueError(f"stream URLs must be http(s): {url!r}")

        self.id = session_id
        self.layout = layout
        self.dir = os.path.join(root_dir, session_id)
        self.settings = settings
        self._popen = popen
        self._clock = clock
        self.feeds = [
            Feed(spec, probe_factory(spec["url"], spec.get("headers"), 540))
            for spec in feeds
        ]
        self.order = list(range(len(feeds)))

        self.state = "starting"  # starting | running | error | stopped
        self.error = ""
        self.generation = 0
        self.restarts = 0
        self.created_at = clock()
        self.last_seen = clock()

        self._lock = threading.RLock()
        self._stop = threading.Event()
        self._restart_requested = False
        self._proc = None
        self._gen_started = 0.0
        self._last_video_at = None
        self._failures = collections.deque()
        self._next_start = 0.0
        self._next_probe = 0.0
        self._retired = {}
        self._stderr = collections.deque(maxlen=20)
        self._playlists = {}
        self._pool = concurrent.futures.ThreadPoolExecutor(max_workers=max(2, len(feeds)))
        self._thread = threading.Thread(target=self._run, name=f"session-{session_id[:8]}", daemon=True)

    # ------------------------------------------------------------------
    # Public surface
    # ------------------------------------------------------------------

    def start(self):
        os.makedirs(self.dir, exist_ok=True)
        names = self._rendition_names()
        self._playlists = {name: StitchedPlaylist(window=STITCH_WINDOW) for name in names}
        bandwidth = _bitrate_bps(self.settings["video_bitrate"]) + 128000 * len(self.feeds)
        write_atomic(os.path.join(self.dir, "master.m3u8"), master_playlist(len(self.feeds), bandwidth))
        self._thread.start()

    def stop(self):
        self._stop.set()
        if self._thread.is_alive() and threading.current_thread() is not self._thread:
            self._thread.join(timeout=10)
        self._kill_ffmpeg()
        self._pool.shutdown(wait=False, cancel_futures=True)
        with self._lock:
            self.state = "stopped"
        shutil.rmtree(self.dir, ignore_errors=True)

    def touch(self):
        self.last_seen = self._clock()

    def reconfigure(self, layout=None, order=None):
        with self._lock:
            if layout is not None:
                if layout not in LAYOUTS:
                    raise ValueError(f"layout must be one of {', '.join(LAYOUTS)}")
                self.layout = layout
            if order is not None:
                if sorted(order) != list(range(len(self.feeds))):
                    raise ValueError("order must list every stream index exactly once")
                self.order = list(order)
            self._restart_requested = True

    def snapshot(self):
        with self._lock:
            rects = tiles_for(self.layout, len(self.feeds))
            tiles = []
            for slot, feed_index in enumerate(self.order):
                feed = self.feeds[feed_index]
                status = feed.status
                if status == "live" and self.state != "running":
                    status = "starting"
                if status == "down":
                    status = "reconnecting"
                tiles.append(dict(
                    rects[slot],
                    slot=slot,
                    stream=feed_index,
                    title=feed.title,
                    status=status,
                    error=feed.probe.error if feed.status == "down" else "",
                    audioTrack=slot,
                ))
            return {
                "id": self.id,
                "state": self.state,
                "error": self.error,
                "layout": self.layout,
                "layouts": list(LAYOUTS),
                "order": list(self.order),
                "generation": self.generation,
                "restarts": self.restarts,
                "playlistUrl": f"/sessions/{self.id}/master.m3u8",
                "tiles": tiles,
            }

    # ------------------------------------------------------------------
    # Supervisor loop
    # ------------------------------------------------------------------

    def _run(self):
        try:
            self._probe_all_now()
            while not self._stop.is_set():
                self._tick()
                self._stop.wait(TICK)
        except Exception as exc:  # keep a bug from leaving ffmpeg orphaned
            with self._lock:
                self.state = "error"
                self.error = f"supervisor crashed: {exc}"
            self._log(self.error)
        finally:
            self._kill_ffmpeg()

    def _tick(self):
        now = self._clock()

        with self._lock:
            restart = self._restart_requested
            self._restart_requested = False
        if restart and self._proc is not None:
            self._log("restarting for new layout or feed state")
            self._stop_ffmpeg()
            self._stitch()
            self._next_start = now

        if self._proc is None:
            if now >= self._next_start:
                self._start_generation()
        else:
            self._stitch()
            code = self._proc.poll()
            if code is not None:
                self._proc = None
                self._stitch()
                self._on_failure(f"ffmpeg exited with code {code}")
            elif self._stalled(now):
                self._log("no new video segment; treating ffmpeg as stalled")
                self._kill_ffmpeg()
                self._stitch()
                self._on_failure("ffmpeg stopped producing video")

        self._collect_probes()
        if now >= self._next_probe:
            self._next_probe = now + PROBE_INTERVAL
            self._submit_probes()
        self._cleanup_generations(now)

    def _stalled(self, now):
        if self._last_video_at is None:
            return now - self._gen_started > STARTUP_TIMEOUT
        return now - self._last_video_at > STALL_TIMEOUT

    def _start_generation(self):
        self.generation += 1
        gen_dir = os.path.join(self.dir, f"gen-{self.generation}")
        os.makedirs(gen_dir, exist_ok=True)

        with self._lock:
            rects = tiles_for(self.layout, len(self.feeds))
            order = list(self.order)

        slots = []
        for slot, feed_index in enumerate(order):
            feed = self.feeds[feed_index]
            rect = rects[slot]
            if feed.status != "down" and feed.probe.tile_height != rect["h"]:
                self._retarget(feed, rect["h"])
            if feed.status == "down":
                text_file = os.path.join(gen_dir, f"slate-{slot}.txt")
                with open(text_file, "w", encoding="utf-8") as handle:
                    handle.write(f"{feed.title}\nReconnecting...")
                slots.append({"rect": rect, "live": False, "slate_text_file": text_file})
            else:
                url, program = feed.probe.input_target()
                slots.append({
                    "rect": rect,
                    "live": True,
                    "url": url,
                    "program": program,
                    "headers": feed.headers,
                    "has_audio": bool(feed.probe.has_audio),
                })

        cmd = ffmpeg_cmd.build_command(slots, gen_dir, self.settings)
        live = sum(1 for s in slots if s["live"])
        self._log(f"generation {self.generation}: {live}/{len(slots)} feeds live, layout {self.layout}")
        try:
            self._proc = self._popen(
                cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
            )
        except OSError as exc:
            self._proc = None
            self._on_failure(f"could not start ffmpeg: {exc}")
            return
        if getattr(self._proc, "stderr", None) is not None:
            threading.Thread(target=self._pump_stderr, args=(self._proc,), daemon=True).start()
        self._gen_started = self._clock()
        self._last_video_at = None

    def _retarget(self, feed, tile_height):
        """A resized tile may want a different rendition of the same feed."""
        previous = feed.probe.variant["program"] if feed.probe.variant else None
        feed.probe.tile_height = tile_height
        if not feed.probe.check():
            return
        current = feed.probe.variant["program"] if feed.probe.variant else None
        if current != previous:
            feed.probe.has_audio = None
            if feed.probe.detect_audio(self.settings["ffprobe"]) is None:
                feed.probe.has_audio = False

    def _on_failure(self, reason):
        now = self._clock()
        self.restarts += 1
        tail = " | ".join(list(self._stderr)[-3:])
        self._log(f"{reason}{': ' + tail if tail else ''}")

        changed = self._probe_all_now()

        self._failures.append(now)
        while self._failures and now - self._failures[0] > FAILURE_WINDOW:
            self._failures.popleft()

        all_slates = all(feed.status == "down" for feed in self.feeds)
        if changed:
            delay = 0
        else:
            # Nothing to blame: retry the same set, backing off so a feed that
            # breaks ffmpeg without failing its probe can't spin us in a loop
            delay = min(MAX_BACKOFF, 2 ** (len(self._failures) - 1))
        with self._lock:
            if all_slates and len(self._failures) >= 3:
                self.state = "error"
                self.error = f"ffmpeg keeps failing even with no feeds: {reason}"
            elif self.state == "running":
                self.state = "starting"
        self._next_start = now + delay

    # ------------------------------------------------------------------
    # Probing
    # ------------------------------------------------------------------

    def _probe_all_now(self):
        """Synchronous pass after a failure. True if any feed changed state."""
        pending = {}
        for feed in self.feeds:
            # A background probe already in flight is waited on rather than
            # doubled up, since both would be driving the same FeedProbe
            future = feed.future or self._pool.submit(self._probe_job, feed)
            feed.future = None
            pending[future] = feed
        changed = False
        done, not_done = concurrent.futures.wait(pending, timeout=60)
        for future in not_done:
            pending[future].probe.error = "probe timed out"
        for future, feed in pending.items():
            try:
                healthy = future in done and future.result()
            except Exception as exc:
                feed.probe.error = str(exc)
                healthy = False
            with self._lock:
                if healthy:
                    if feed.status != "live":
                        changed = True
                    feed.status = "live"
                    feed.failures = 0
                    feed.healthy_since = self._clock()
                else:
                    if feed.status != "down":
                        changed = True
                        self._log(f"{feed.title}: down ({feed.probe.error})")
                    feed.status = "down"
                    feed.healthy_since = None
        return changed

    def _probe_job(self, feed):
        healthy = feed.probe.check()
        if healthy and feed.probe.has_audio is None:
            if feed.probe.detect_audio(self.settings["ffprobe"]) is None:
                # Unknown is treated as silent: mapping audio that isn't there
                # would fail every generation, a missing soundtrack only this tile
                feed.probe.has_audio = False
        return healthy

    def _submit_probes(self):
        for feed in self.feeds:
            if feed.future is None:
                feed.future = self._pool.submit(self._probe_job, feed)

    def _collect_probes(self):
        now = self._clock()
        for feed in self.feeds:
            future = feed.future
            if future is None or not future.done():
                continue
            feed.future = None
            try:
                healthy = future.result()
            except Exception as exc:
                feed.probe.error = str(exc)
                healthy = False
            with self._lock:
                if feed.status == "down":
                    if not healthy:
                        feed.healthy_since = None
                        continue
                    if feed.healthy_since is None:
                        feed.healthy_since = now
                    if now - feed.healthy_since >= RECOVER_SECONDS:
                        self._log(f"{feed.title}: recovered, bringing it back")
                        feed.status = "live"
                        feed.failures = 0
                        self._restart_requested = True
                elif healthy:
                    feed.failures = 0
                else:
                    feed.failures += 1
                    if feed.failures >= DOWN_AFTER_FAILURES:
                        self._log(f"{feed.title}: down ({feed.probe.error})")
                        feed.status = "down"
                        feed.healthy_since = None
                        self._restart_requested = True

    # ------------------------------------------------------------------
    # Output
    # ------------------------------------------------------------------

    def _rendition_names(self):
        return ["v"] + [f"a{i}" for i in range(len(self.feeds))]

    def _stitch(self):
        gen = self.generation
        if gen == 0:
            return
        gen_dir = os.path.join(self.dir, f"gen-{gen}")
        ready = True
        for name, playlist in self._playlists.items():
            segments = read_media_playlist(os.path.join(gen_dir, f"{name}.m3u8"))
            if playlist.add(gen, segments, f"gen-{gen}"):
                write_atomic(os.path.join(self.dir, f"{name}.m3u8"), playlist.render())
                if name == "v":
                    self._last_video_at = self._clock()
            if len(playlist.entries) < 2:
                ready = False
        with self._lock:
            if ready and self.state == "starting" and self._last_video_at is not None:
                self.state = "running"
                self.error = ""

    def _cleanup_generations(self, now):
        referenced = set()
        for playlist in self._playlists.values():
            referenced |= playlist.generations()
        for entry in os.listdir(self.dir) if os.path.isdir(self.dir) else []:
            if not entry.startswith("gen-"):
                continue
            try:
                gen = int(entry[4:])
            except ValueError:
                continue
            if gen == self.generation or gen in referenced:
                self._retired.pop(gen, None)
                continue
            retired_at = self._retired.setdefault(gen, now)
            # Players can still be partway through a segment that just left
            # the window
            if now - retired_at > RETIRED_GENERATION_GRACE:
                shutil.rmtree(os.path.join(self.dir, entry), ignore_errors=True)
                self._retired.pop(gen, None)

    # ------------------------------------------------------------------
    # ffmpeg process
    # ------------------------------------------------------------------

    def _stop_ffmpeg(self):
        """Ask ffmpeg to finish cleanly, so its last segment is usable."""
        proc = self._proc
        self._proc = None
        if proc is None:
            return
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=4)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=4)

    def _kill_ffmpeg(self):
        proc = self._proc
        self._proc = None
        if proc is None:
            return
        if proc.poll() is None:
            proc.kill()
            try:
                proc.wait(timeout=4)
            except subprocess.TimeoutExpired:
                pass

    def _pump_stderr(self, proc):
        try:
            for raw in proc.stderr:
                line = raw.decode("utf-8", "replace").rstrip()
                # Printed once per audio-only output on every start; harmless
                if not line or line.endswith("frame size not set"):
                    continue
                self._stderr.append(line)
                self._log(f"ffmpeg: {line}")
        except (OSError, ValueError):
            pass
        finally:
            _close_stderr(proc)

    def _log(self, message):
        print(f"[session {self.id[:8]}] {message}", flush=True)


def _close_stderr(proc):
    stream = getattr(proc, "stderr", None)
    if stream is not None:
        try:
            stream.close()
        except (OSError, ValueError):
            pass


def _bitrate_bps(value):
    multipliers = {"k": 1000, "m": 1000000}
    suffix = value[-1].lower() if value else ""
    try:
        if suffix in multipliers:
            return int(float(value[:-1]) * multipliers[suffix])
        return int(value)
    except ValueError:
        return 6000000
