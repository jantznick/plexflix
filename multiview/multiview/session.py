"""One multiview: its feeds, the compositor that tiles them, and the pump
that moves frames between the two.

Every feed is decoded by its own ffmpeg (see ingest.py), so a feed that
drops only blanks its own tile: the pump keeps pushing a frame for every
tile on every tick, using a frozen frame or a slate for feeds that have
nothing new. The compositor pipeline is only rebuilt if it fails itself;
that becomes a discontinuity in the stitched playlists, which the Roku plays
through.
"""

import collections
import os
import shutil
import threading
import time

from . import slate
from .compositor import Compositor, bitrate_bps
from .ingest import AUDIO_RATE, Ingest
from .layouts import LAYOUTS, tiles_for
from .playlist import StitchedPlaylist, master_playlist, read_media_playlist, write_atomic
from .relay import source_for

TICK = 0.5
STARTUP_TIMEOUT = 20
STALL_TIMEOUT = 12
FAILURE_WINDOW = 60
MAX_BACKOFF = 30
RETIRED_GENERATION_GRACE = 30
STITCH_WINDOW = 10


class Feed:
    def __init__(self, index, spec, ingest):
        self.index = index
        self.url = spec["url"]
        self.title = spec.get("title") or "Stream"
        self.ingest = ingest
        self.frame = None
        blank = slate.blank_frame()
        self.slates = {"starting": blank, "reconnecting": blank}

    def picture(self):
        fresh = self.ingest.take_video()
        if fresh is not None:
            self.frame = fresh
        if self.frame is not None and self.ingest.showing_live():
            return self.frame
        return self.slates["starting" if self.ingest.status == "starting" else "reconnecting"]


class Session:
    def __init__(self, session_id, feeds, layout, root_dir, settings, relay=None,
                 ingest_factory=Ingest, compositor_factory=Compositor, clock=time.monotonic):
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
        self._clock = clock
        self._compositor_factory = compositor_factory
        self.feeds = [
            Feed(i, spec, ingest_factory(source_for(spec, relay), settings, f"{session_id[:8]}/{i}"))
            for i, spec in enumerate(feeds)
        ]
        self.order = list(range(len(feeds)))

        self.state = "starting"  # starting | running | error | stopped
        self.error = ""
        self.generation = 0
        self.restarts = 0
        self.created_at = clock()
        self.last_seen = clock()

        self._lock = threading.RLock()
        # Held by the pump while it pushes, so a compositor is never swapped
        # out from under a push
        self._push_lock = threading.Lock()
        self._stop = threading.Event()
        self._compositor = None
        self._pump_error = ""
        self._gen_started = 0.0
        self._last_video_at = None
        self._failures = collections.deque()
        self._next_start = 0.0
        self._retired = {}
        self._playlists = {}
        self._thread = threading.Thread(target=self._run, name=f"session-{session_id[:8]}", daemon=True)
        self._pump_thread = threading.Thread(target=self._pump, name=f"pump-{session_id[:8]}", daemon=True)

    # ------------------------------------------------------------------
    # Public surface
    # ------------------------------------------------------------------

    def start(self):
        os.makedirs(self.dir, exist_ok=True)
        names = ["v"] + [f"a{i}" for i in range(len(self.feeds))]
        self._playlists = {name: StitchedPlaylist(window=STITCH_WINDOW) for name in names}
        bandwidth = bitrate_bps(self.settings.get("video_bitrate", "6M")) + 128000 * len(self.feeds)
        write_atomic(os.path.join(self.dir, "master.m3u8"), master_playlist(len(self.feeds), bandwidth))
        self._thread.start()

    def stop(self):
        self._stop.set()
        for thread in (self._thread, self._pump_thread):
            if thread.is_alive() and threading.current_thread() is not thread:
                thread.join(timeout=10)
        self._shutdown()
        with self._lock:
            self.state = "stopped"
        shutil.rmtree(self.dir, ignore_errors=True)

    def touch(self):
        self.last_seen = self._clock()

    def reconfigure(self, layout=None, order=None):
        """Takes effect on the next frame; nothing restarts."""
        with self._lock:
            if layout is not None and layout not in LAYOUTS:
                raise ValueError(f"layout must be one of {', '.join(LAYOUTS)}")
            if order is not None and sorted(order) != list(range(len(self.feeds))):
                raise ValueError("order must list every stream index exactly once")
            if layout is not None:
                self.layout = layout
            if order is not None:
                self.order = list(order)
            compositor = self._compositor
            placements = self._placements()
        if compositor is not None:
            compositor.apply_layout(placements)

    def snapshot(self):
        with self._lock:
            rects = tiles_for(self.layout, len(self.feeds))
            tiles = []
            for slot, feed_index in enumerate(self.order):
                feed = self.feeds[feed_index]
                status = feed.ingest.status
                if status == "live" and self.state != "running":
                    status = "starting"
                tiles.append(dict(
                    rects[slot],
                    slot=slot,
                    stream=feed_index,
                    title=feed.title,
                    status=status,
                    error=feed.ingest.error if status != "live" else "",
                    reconnects=feed.ingest.restarts,
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
    # Supervisor
    # ------------------------------------------------------------------

    def _run(self):
        try:
            for feed in self.feeds:
                feed.ingest.start()
            self._start_compositor()
            self._pump_thread.start()
            self._render_slates()
            while not self._stop.is_set():
                self._tick()
                self._stop.wait(TICK)
        except Exception as exc:  # keep a bug from leaving ffmpegs orphaned
            with self._lock:
                self.state = "error"
                self.error = f"supervisor crashed: {exc}"
            self._log(self.error)
        finally:
            self._shutdown()

    def _render_slates(self):
        for feed in self.feeds:
            for key, message in (("starting", "Starting..."), ("reconnecting", "Reconnecting...")):
                if self._stop.is_set():
                    return
                feed.slates[key] = slate.render(self.settings.get("ffmpeg", "ffmpeg"),
                                                self.settings.get("font_file", ""), feed.title, message)

    def _tick(self):
        now = self._clock()
        self._stitch()
        compositor = self._compositor
        if compositor is None:
            if now >= self._next_start:
                self._start_compositor()
        else:
            error = compositor.poll_error() or self._pump_error
            if error:
                self._replace_compositor(f"pipeline error: {error}")
            elif self._stalled(now):
                self._replace_compositor("compositor stopped producing video")
        self._cleanup_generations(now)

    def _stalled(self, now):
        if self._last_video_at is None:
            return now - self._gen_started > STARTUP_TIMEOUT
        return now - self._last_video_at > STALL_TIMEOUT

    def _start_compositor(self):
        self.generation += 1
        gen_dir = os.path.join(self.dir, f"gen-{self.generation}")
        os.makedirs(gen_dir, exist_ok=True)
        compositor = self._compositor_factory(gen_dir, len(self.feeds), self.settings)
        try:
            compositor.start()
            with self._lock:
                compositor.apply_layout(self._placements())
        except Exception as exc:
            try:
                compositor.stop()
            except Exception:
                pass
            self._on_failure(f"could not start the compositor: {exc}")
            return
        self._gen_started = self._clock()
        self._last_video_at = None
        self._pump_error = ""
        with self._push_lock:
            self._compositor = compositor
        self._log(f"compositor generation {self.generation} started, layout {self.layout}")

    def _replace_compositor(self, reason):
        with self._push_lock:
            compositor = self._compositor
            self._compositor = None
        if compositor is not None:
            try:
                compositor.stop()
            except Exception as exc:
                self._log(f"compositor stop failed: {exc}")
        self._stitch()
        self._on_failure(reason)

    def _on_failure(self, reason):
        now = self._clock()
        self.restarts += 1
        self._log(reason)
        self._failures.append(now)
        while self._failures and now - self._failures[0] > FAILURE_WINDOW:
            self._failures.popleft()
        delay = 0 if len(self._failures) == 1 else min(MAX_BACKOFF, 2 ** (len(self._failures) - 1))
        with self._lock:
            if len(self._failures) >= 3:
                self.state = "error"
                self.error = reason
            elif self.state == "running":
                self.state = "starting"
        self._next_start = now + delay

    def _placements(self):
        rects = tiles_for(self.layout, len(self.feeds))
        # The main tile sits underneath, so picture-in-picture insets show on top
        return [(feed_index, rects[slot], 0 if slot == 0 else slot)
                for slot, feed_index in enumerate(self.order)]

    def _shutdown(self):
        for feed in self.feeds:
            feed.ingest.stop()
        with self._push_lock:
            compositor = self._compositor
            self._compositor = None
        if compositor is not None:
            try:
                compositor.stop()
            except Exception:
                pass

    # ------------------------------------------------------------------
    # Pump
    # ------------------------------------------------------------------

    def _pump(self):
        fps = self.settings.get("fps", 30)
        current = None
        n = 0
        started = 0.0
        while not self._stop.is_set():
            with self._push_lock:
                compositor = self._compositor
                if compositor is None:
                    current = None
                else:
                    if compositor is not current:
                        current, n, started = compositor, 0, self._clock()
                    try:
                        self._push_tick(compositor, fps, n)
                    except Exception as exc:
                        self._pump_error = str(exc) or exc.__class__.__name__
            if compositor is None or self._pump_error:
                self._stop.wait(0.05)
                continue
            n += 1
            # Falling behind means pushing frames back to back until caught
            # up; skipping would leave holes in the timeline
            delay = started + n / fps - self._clock()
            if delay > 0:
                self._stop.wait(delay)

    def _push_tick(self, compositor, fps, n):
        with self._lock:
            order = list(self.order)
        for feed in self.feeds:
            compositor.push_video(feed.index, feed.picture(), n)
        samples = (n + 1) * AUDIO_RATE // fps - n * AUDIO_RATE // fps
        for slot, feed_index in enumerate(order):
            compositor.push_audio(slot, self.feeds[feed_index].ingest.take_audio(samples * 4), n)

    # ------------------------------------------------------------------
    # Output
    # ------------------------------------------------------------------

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
            if ready and self.state != "running" and self._last_video_at is not None \
                    and self._compositor is not None:
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

    def _log(self, message):
        print(f"[session {self.id[:8]}] {message}", flush=True)
