"""One multiview session: feed 1 via the vendored proxy, other tiles placeholder.

Roku POSTs streams, polls until state=running, then plays
/sessions/<id>/master.m3u8 — that playlist is the same proxied HLS the
roku-feed proxy would serve (unwrap and all), with segment URLs rewritten
so the Roku can fetch them on :8095.
"""

import os
import shutil
import threading
import time

from .layouts import LAYOUTS, tiles_for
from .relay import rewrite_to_local_proxy


class Feed:
    def __init__(self, index, spec, live=True):
        self.index = index
        self.url = spec["url"]
        self.title = spec.get("title") or "Stream"
        self.live = live


class Session:
    def __init__(self, session_id, feeds, layout, root_dir, settings, relay=None,
                 clock=time.monotonic, **_ignored):
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
        # Feed 0 is the one we proxy; everything else is UI-only placeholder.
        self.feeds = [Feed(i, spec, live=(i == 0)) for i, spec in enumerate(feeds)]
        self.order = list(range(len(feeds)))
        self.passthrough = True
        self.passthrough_url = rewrite_to_local_proxy(self.feeds[0].url)

        self.state = "starting"  # starting | running | error | stopped
        self.error = ""
        self.generation = 0
        self.restarts = 0
        self.created_at = clock()
        self.last_seen = clock()

        self._lock = threading.RLock()
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, name=f"session-{session_id[:8]}", daemon=True)

    def start(self):
        os.makedirs(self.dir, exist_ok=True)
        self._thread.start()

    def stop(self):
        self._stop.set()
        if self._thread.is_alive() and threading.current_thread() is not self._thread:
            self._thread.join(timeout=10)
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
            if layout is not None:
                self.layout = layout
            if order is not None:
                self.order = list(order)

    def snapshot(self):
        with self._lock:
            rects = tiles_for(self.layout, len(self.feeds))
            tiles = []
            for slot, feed_index in enumerate(self.order):
                feed = self.feeds[feed_index]
                if feed.live:
                    status = "live" if self.state == "running" else "starting"
                else:
                    status = "placeholder"
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
        held = len(self.feeds) - 1
        if held:
            self._log(f"pass-through feed 1; placeholder on {held} tile(s)")
        self._log("warming feed 1 through vendored proxy")
        try:
            self._relay.warm([self.passthrough_url])
            self._relay.fetch(self.passthrough_url)
        except Exception as exc:
            with self._lock:
                self.state = "error"
                self.error = f"pass-through failed: {exc}"
            self._log(self.error)
            self._stop.wait()
            return
        with self._lock:
            self.state = "running"
            self.error = ""
        self._log("running — pass-through proxy HLS on master.m3u8")
        self._stop.wait()

    def _log(self, message):
        print(f"[session {self.id[:8]}] {message}", flush=True)
