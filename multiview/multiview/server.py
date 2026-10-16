"""HTTP API and HLS pass-through for multiview sessions.

    POST   /sessions            {"streams": [{"url", "title"}], "layout"?}
    GET    /sessions/<id>       status, tile rectangles; doubles as a heartbeat
    PUT    /sessions/<id>       {"layout"?, "order"?}
    DELETE /sessions/<id>
    GET    /sessions/<id>/master.m3u8   proxied HLS for feed 1
    GET    /sessions/<id>/r/<token>.ts  segments (relative from the playlist)
    GET    /healthz
"""

import json
import os
import re
import tempfile
import threading
import time
import uuid
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from .relay import Relay, RelayError
from .session import Session

SESSION_PATH = re.compile(r"^/sessions/([0-9a-f-]{36})(?:/(.*))?$")
PASS_FILE = re.compile(r"^(?:master\.m3u8|r/[A-Za-z0-9_-]+\.(?:m3u8|ts))$")


def _default_data_dir():
    if os.path.isdir("/data"):
        return "/data/sessions"
    return os.path.join(tempfile.gettempdir(), "multiview-sessions")


def settings_from_env(env=os.environ):
    return {
        "variant_height": int(env.get("VARIANT_HEIGHT", "480")),
        "data_dir": env.get("DATA_DIR") or _default_data_dir(),
        "idle_timeout": int(env.get("IDLE_TIMEOUT", "90")),
        "max_sessions": int(env.get("MAX_SESSIONS", "2")),
        "token": env.get("MULTIVIEW_TOKEN", ""),
        "port": int(env.get("PORT", "8095")),
        "allow_local_inputs": env.get("ALLOW_LOCAL_INPUTS", "") == "1",
    }


class SessionManager:
    def __init__(self, settings, session_factory=Session, clock=time.monotonic, relay=None):
        self.settings = settings
        self.relay = relay
        self._factory = session_factory
        self._clock = clock
        self._sessions = {}
        self._lock = threading.Lock()
        os.makedirs(settings["data_dir"], exist_ok=True)

    def create(self, streams, layout):
        session_id = str(uuid.uuid4())
        extra = {"relay": self.relay} if self.relay is not None else {}
        session = self._factory(session_id, streams, layout, self.settings["data_dir"], self.settings, **extra)
        evicted = []
        with self._lock:
            while len(self._sessions) >= self.settings["max_sessions"]:
                oldest = min(self._sessions.values(), key=lambda s: s.last_seen)
                evicted.append(self._sessions.pop(oldest.id))
            self._sessions[session_id] = session
        for old in evicted:
            old.stop()
        session.start()
        return session

    def get(self, session_id):
        with self._lock:
            return self._sessions.get(session_id)

    def remove(self, session_id):
        with self._lock:
            session = self._sessions.pop(session_id, None)
        if session is not None:
            session.stop()
        return session is not None

    def reap(self):
        now = self._clock()
        with self._lock:
            idle = [s for s in self._sessions.values() if now - s.last_seen > self.settings["idle_timeout"]]
            for session in idle:
                self._sessions.pop(session.id, None)
        for session in idle:
            print(f"[manager] session {session.id[:8]} idle, stopping", flush=True)
            session.stop()

    def stop_all(self):
        with self._lock:
            sessions = list(self._sessions.values())
            self._sessions.clear()
        for session in sessions:
            session.stop()


def make_handler(manager):
    settings = manager.settings

    class Handler(BaseHTTPRequestHandler):
        server_version = "PlexFlixMultiview/1.0"

        def log_message(self, fmt, *args):
            if self.command == "GET" and (self.path.endswith(".ts") or self.path.endswith(".m3u8")):
                return
            print(f"[http] {self.address_string()} {fmt % args}", flush=True)

        def handle(self):
            try:
                super().handle()
            except (ConnectionResetError, BrokenPipeError):
                pass

        def do_OPTIONS(self):
            self.send_response(HTTPStatus.NO_CONTENT)
            self.send_header("Allow", "GET, POST, PUT, DELETE, OPTIONS")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type, X-Multiview-Token")
            self.send_header("Content-Length", "0")
            self.end_headers()

        def do_GET(self):
            if self.path == "/healthz":
                relay = manager.relay.snapshot() if manager.relay is not None else {}
                return self._json(HTTPStatus.OK, {"ok": True, "relay": relay})
            match = SESSION_PATH.match(self.path.split("?", 1)[0])
            if not match:
                return self._json(HTTPStatus.NOT_FOUND, {"error": "not found"})
            session = manager.get(match.group(1))
            if session is None:
                return self._json(HTTPStatus.NOT_FOUND, {"error": "no such session"})
            session.touch()
            if match.group(2):
                return self._media(session, match.group(2))
            if not self._authorized():
                return
            return self._json(HTTPStatus.OK, session.snapshot())

        def do_POST(self):
            if self.path.split("?", 1)[0] != "/sessions":
                return self._json(HTTPStatus.NOT_FOUND, {"error": "not found"})
            if not self._authorized():
                return
            body = self._body()
            if body is None:
                return
            streams = body.get("streams")
            if not isinstance(streams, list) or not all(isinstance(s, dict) and s.get("url") for s in streams):
                return self._json(HTTPStatus.BAD_REQUEST, {"error": "streams must be a list of {url, title}"})
            try:
                session = manager.create(streams, body.get("layout") or "grid")
            except ValueError as exc:
                return self._json(HTTPStatus.BAD_REQUEST, {"error": str(exc)})
            return self._json(HTTPStatus.CREATED, session.snapshot())

        def do_PUT(self):
            session = self._session_for_api()
            if session is None:
                return
            body = self._body()
            if body is None:
                return
            try:
                session.reconfigure(layout=body.get("layout"), order=body.get("order"))
            except ValueError as exc:
                return self._json(HTTPStatus.BAD_REQUEST, {"error": str(exc)})
            session.touch()
            return self._json(HTTPStatus.OK, session.snapshot())

        def do_DELETE(self):
            match = SESSION_PATH.match(self.path.split("?", 1)[0])
            if not match or match.group(2):
                return self._json(HTTPStatus.NOT_FOUND, {"error": "not found"})
            if not self._authorized():
                return
            manager.remove(match.group(1))
            return self._json(HTTPStatus.OK, {"ok": True})

        def _session_for_api(self):
            match = SESSION_PATH.match(self.path.split("?", 1)[0])
            if not match or match.group(2):
                self._json(HTTPStatus.NOT_FOUND, {"error": "not found"})
                return None
            if not self._authorized():
                return None
            session = manager.get(match.group(1))
            if session is None:
                self._json(HTTPStatus.NOT_FOUND, {"error": "no such session"})
            return session

        def _authorized(self):
            if not settings["token"] or self.headers.get("X-Multiview-Token") == settings["token"]:
                return True
            self._json(HTTPStatus.UNAUTHORIZED, {"error": "bad or missing X-Multiview-Token"})
            return False

        def _body(self):
            try:
                length = int(self.headers.get("Content-Length") or 0)
                raw = self.rfile.read(length) if length else b"{}"
                body = json.loads(raw or b"{}")
            except (ValueError, OSError):
                self._json(HTTPStatus.BAD_REQUEST, {"error": "body must be JSON"})
                return None
            if not isinstance(body, dict):
                self._json(HTTPStatus.BAD_REQUEST, {"error": "body must be a JSON object"})
                return None
            return body

        def _media(self, session, name):
            if not PASS_FILE.match(name) or manager.relay is None:
                return self._json(HTTPStatus.NOT_FOUND, {"error": "not found"})
            try:
                if name == "master.m3u8":
                    upstream = session.passthrough_url
                    if not upstream:
                        return self._json(HTTPStatus.NOT_FOUND, {"error": "not ready"})
                    content_type, data = manager.relay.fetch(upstream)
                else:
                    token = name[2:].rsplit(".", 1)[0]
                    content_type, data = manager.relay.handle(token)
            except RelayError as exc:
                return self._json(exc.status, {"error": str(exc)})
            if content_type.startswith("application/vnd.apple.mpegurl") or data.lstrip()[:7] == b"#EXTM3U":
                data = manager.relay.relative_playlist(data)
                content_type = "application/vnd.apple.mpegurl"
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            try:
                self.wfile.write(data)
            except (BrokenPipeError, ConnectionResetError):
                pass

        def _json(self, status, payload):
            data = json.dumps(payload).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

    return Handler


def main():
    settings = settings_from_env()
    relay = Relay(variant_height=settings["variant_height"]).serve()
    manager = SessionManager(settings, relay=relay)
    server = ThreadingHTTPServer(("0.0.0.0", settings["port"]), make_handler(manager))
    server.daemon_threads = True

    def reaper():
        while True:
            time.sleep(10)
            manager.reap()

    threading.Thread(target=reaper, daemon=True).start()
    print(f"[manager] multiview listening on :{settings['port']} (pass-through)", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        manager.stop_all()
        relay.close()


if __name__ == "__main__":
    main()
