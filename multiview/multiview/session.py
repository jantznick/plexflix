"""Multiview session: proxy → one ffmpeg mosaic → HLS for the Roku.

Feed URLs are warmed through the vendored advanced-proxy (same unwrap path as
roku-feed). A single ffmpeg filtergraph places live feeds into layout tiles,
draws placeholder slates for the rest, and writes 1080p HLS. The Roku plays
that one stream fullscreen.
"""

import collections
import os
import shutil
import threading
import time

from .layouts import LAYOUTS, tiles_for
from .mosaic import Mosaic, bitrate_bps
from .playlist import StitchedPlaylist, master_playlist, read_media_playlist, write_atomic
from .relay import rewrite_to_local_proxy, source_for

TICK = 0.5
STARTUP_TIMEOUT = 45
STALL_TIMEOUT = 15
FAILURE_WINDOW = 60
MAX_BACKOFF = 30
RETIRED_GENERATION_GRACE = 30
STITCH_WINDOW = 10


class Feed:
    def __init__(self, index, spec, live=True):
        self.index = index
        self.url = spec["url"]
        self.title = spec.get("title") or "Stream"
        self.live = live


class Session:
    def __init__(self, session_id, feeds, layout, root_dir, settings, relay=None,
                 mosaic_factory=Mosaic, clock=time.monotonic, **_ignored):
        if layout not in LAYOUTS:
            raise ValueError(f"layout must be one of {', '.join(LAYOUTS)}")
        if not feeds:
            raise ValueError("at least one stream is required")
        tiles_for(layout, len(feeds))
        for spec in feeds:
            url = spec.get("url") or ""
            if not url.startswith(("http://", "https://")) and not settings.get("allow_local_inputs"):
                raise ValueError(f"stream URLs must be http(s): {url!r}")
        if relay is None:
            raise ValueError("relay is required")

        self.id = session_id
        self.layout = layout
        self.dir = os.path.join(root_dir, session_id)
        self.settings = settings
        self._clock = clock
        self._relay = relay
        self._mosaic_factory = mosaic_factory

        # Incremental build: only the first stream is decoded into the mosaic.
        # Everything else is a placeholder tile until more of the function lands.
        self.feeds = [Feed(i, spec, live=(i == 0)) for i, spec in enumerate(feeds)]
        self.order = list(range(len(feeds)))

        self.state = "starting"
        self.error = ""
        self.generation = 0
        self.restarts = 0
        self.created_at = clock()
        self.last_seen = clock()

        self._lock = threading.RLock()
        self._stop = threading.Event()
        self._mosaic = None
        self._gen_started = 0.0
        self._last_video_at = None
        self._failures = collections.deque()
        self._next_start = 0.0
        self._retired = {}
        self._playlists = {}
        self._last_wait_log = 0.0
        self._thread = threading.Thread(target=self._run, name=f"session-{session_id[:8]}", daemon=True)

    def start(self):
        os.makedirs(self.dir, exist_ok=True)
        names = ["v"] + [f"a{i}" for i in range(len(self.feeds))]
        self._playlists = {name: StitchedPlaylist(window=STITCH_WINDOW) for name in names}
        bandwidth = bitrate_bps(self.settings.get("video_bitrate", "3M")) + 128000 * len(self.feeds)
        write_atomic(os.path.join(self.dir, "master.m3u8"), master_playlist(len(self.feeds), bandwidth))
        self._thread.start()

    def stop(self):
        self._stop.set()
        if self._thread.is_alive() and threading.current_thread() is not self._thread:
            self._thread.join(timeout=15)
        self._shutdown()
        with self._lock:
            self.state = "stopped"
        shutil.rmtree(self.dir, ignore_errors=True)

    def touch(self):
        self.last_seen = self._clock()

    def reconfigure(self, layout=None, order=None):
        with self._lock:
            if layout is not None and layout not in LAYOUTS:
                raise ValueError(f"layout must be one of {', '.join(LAYOUTS)}")
            if order is not None and sorted(order) != list(range(len(self.feeds))):
                raise ValueError("order must list every stream index exactly once")
            changed = False
            if layout is not None and layout != self.layout:
                self.layout = layout
                changed = True
            if order is not None and list(order) != self.order:
                self.order = list(order)
                changed = True
            if changed:
                # ffmpeg filtergraph is static — restart with the new layout
                self._next_start = self._clock()
                mosaic = self._mosaic
                self._mosaic = None
            else:
                mosaic = None
        if mosaic is not None:
            try:
                mosaic.stop()
            except Exception:
                pass

    def snapshot(self):
        with self._lock:
            rects = tiles_for(self.layout, len(self.feeds))
            tiles = []
            for slot, feed_index in enumerate(self.order):
                feed = self.feeds[feed_index]
                if not feed.live:
                    status = "placeholder"
                elif self.state == "running":
                    status = "live"
                else:
                    status = "starting"
                tiles.append(dict(
                    rects[slot],
                    slot=slot,
                    stream=feed_index,
                    title=feed.title,
                    status=status,
                    error="",
                    reconnects=0,
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

    def _run(self):
        try:
            live = [f for f in self.feeds if f.live]
            held = [f for f in self.feeds if not f.live]
            if held:
                self._log(f"decoding feed 1; placeholder on {len(held)} tile(s)")
            if live:
                targets = [rewrite_to_local_proxy(f.url) for f in live]
                self._log(f"warming {len(targets)} feed(s) through vendored proxy")
                self._relay.warm(targets)
            self._start_mosaic()
            while not self._stop.is_set():
                self._tick()
                self._stop.wait(TICK)
        except Exception as exc:
            with self._lock:
                self.state = "error"
                self.error = f"supervisor crashed: {exc}"
            self._log(self.error)
        finally:
            self._shutdown()

    def _tick(self):
        now = self._clock()
        self._stitch()
        mosaic = self._mosaic
        if mosaic is None:
            if now >= self._next_start:
                self._start_mosaic()
            return
        error = mosaic.poll_error()
        if error:
            self._replace_mosaic(error)
        elif self._stalled(now):
            self._replace_mosaic("mosaic stopped producing video")
        self._cleanup_generations(now)

    def _stalled(self, now):
        if self._last_video_at is None:
            return now - self._gen_started > STARTUP_TIMEOUT
        return now - self._last_video_at > STALL_TIMEOUT

    def _feed_specs(self):
        specs = []
        for feed in self.feeds:
            url = ""
            if feed.live:
                url = source_for({"url": feed.url}, self._relay)
            specs.append({"live": feed.live, "url": url, "title": feed.title})
        return specs

    def _placements(self):
        rects = tiles_for(self.layout, len(self.feeds))
        return [(feed_index, rects[slot], 0 if slot == 0 else slot)
                for slot, feed_index in enumerate(self.order)]

    def _start_mosaic(self):
        self.generation += 1
        gen_dir = os.path.join(self.dir, f"gen-{self.generation}")
        os.makedirs(gen_dir, exist_ok=True)
        with self._lock:
            placements = self._placements()
            specs = self._feed_specs()
        mosaic = self._mosaic_factory(gen_dir, specs, placements, self.settings)
        try:
            mosaic.start()
        except Exception as exc:
            try:
                mosaic.stop()
            except Exception:
                pass
            self._on_failure(f"could not start mosaic: {exc}")
            return
        self._gen_started = self._clock()
        self._last_video_at = None
        self._mosaic = mosaic
        self._log(f"mosaic generation {self.generation} started, layout {self.layout}")

    def _replace_mosaic(self, reason):
        mosaic = self._mosaic
        self._mosaic = None
        if mosaic is not None:
            try:
                mosaic.stop()
            except Exception as exc:
                self._log(f"mosaic stop failed: {exc}")
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

    def _shutdown(self):
        mosaic = self._mosaic
        self._mosaic = None
        if mosaic is not None:
            try:
                mosaic.stop()
            except Exception:
                pass

    def _stitch(self):
        gen = self.generation
        if gen == 0:
            return
        gen_dir = os.path.join(self.dir, f"gen-{gen}")
        counts = {}
        for name, playlist in self._playlists.items():
            segments = read_media_playlist(os.path.join(gen_dir, f"{name}.m3u8"))
            if playlist.add(gen, segments, f"gen-{gen}"):
                write_atomic(os.path.join(self.dir, f"{name}.m3u8"), playlist.render())
                if name == "v":
                    self._last_video_at = self._clock()
            counts[name] = len(playlist.entries)
        # Video gates playback; audio of silence tiles can lag without blocking.
        ready = counts.get("v", 0) >= 2 and self._last_video_at is not None and self._mosaic is not None
        with self._lock:
            if ready and self.state != "running":
                self.state = "running"
                self.error = ""
                self._log(f"running — mosaic playlists {counts}")
            elif self.state != "running" and self.generation:
                now = self._clock()
                if now - self._last_wait_log >= 5:
                    self._last_wait_log = now
                    self._log(f"waiting for mosaic playlist — {counts}")

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
            if now - retired_at > RETIRED_GENERATION_GRACE:
                shutil.rmtree(os.path.join(self.dir, entry), ignore_errors=True)
                self._retired.pop(gen, None)

    def _log(self, message):
        print(f"[session {self.id[:8]}] {message}", flush=True)
