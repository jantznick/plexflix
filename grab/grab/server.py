"""HTTP API for PlexFlix grab jobs.

    POST /jobs              start a movie (or episode) grab
    GET  /jobs/<id>         status / progress (Roku polls every 2–3s)
    GET  /jobs?guid=&tmdbId=&imdbId=   resume lookup
    GET  /healthz
"""

from __future__ import annotations

import json
import re
import threading
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

from .jobs import JobStore
from .settings import settings_from_env

JOB_PATH = re.compile(r"^/jobs/([0-9a-f-]{36})$")


def make_handler(store: JobStore):
    settings = store.settings

    class Handler(BaseHTTPRequestHandler):
        server_version = "PlexFlixGrab/0.1"

        def log_message(self, fmt, *args):
            print(f"[http] {self.address_string()} {fmt % args}", flush=True)

        def do_GET(self):
            parsed = urlparse(self.path)
            if parsed.path == "/healthz":
                return self._json(HTTPStatus.OK, {"ok": True})

            if parsed.path == "/jobs":
                if not self._authorized():
                    return
                qs = parse_qs(parsed.query)
                guid = (qs.get("guid") or [""])[0]
                tmdb_id = (qs.get("tmdbId") or qs.get("tmdb_id") or [""])[0]
                imdb_id = (qs.get("imdbId") or qs.get("imdb_id") or [""])[0]
                if not (guid or tmdb_id or imdb_id):
                    return self._json(
                        HTTPStatus.BAD_REQUEST,
                        {"error": "pass guid, tmdbId, or imdbId to look up a job"},
                    )
                job = store.find_by_query(guid=guid, tmdb_id=tmdb_id, imdb_id=imdb_id)
                if job is None:
                    return self._json(HTTPStatus.NOT_FOUND, {"error": "no job"})
                return self._json(HTTPStatus.OK, job)

            match = JOB_PATH.match(parsed.path)
            if not match:
                return self._json(HTTPStatus.NOT_FOUND, {"error": "not found"})
            if not self._authorized():
                return
            job = store.get(match.group(1))
            if job is None:
                return self._json(HTTPStatus.NOT_FOUND, {"error": "no such job"})
            return self._json(HTTPStatus.OK, job)

        def do_POST(self):
            parsed = urlparse(self.path)
            if parsed.path != "/jobs":
                return self._json(HTTPStatus.NOT_FOUND, {"error": "not found"})
            if not self._authorized():
                return
            body = self._body()
            if body is None:
                return
            try:
                job = store.create(body)
            except ValueError as exc:
                return self._json(HTTPStatus.BAD_REQUEST, {"error": str(exc)})
            except Exception as exc:  # noqa: BLE001
                return self._json(HTTPStatus.INTERNAL_SERVER_ERROR, {"error": str(exc)})
            return self._json(HTTPStatus.CREATED, job)

        def _authorized(self):
            if not settings["token"] or self.headers.get("X-Grab-Token") == settings["token"]:
                return True
            self._json(HTTPStatus.UNAUTHORIZED, {"error": "bad or missing X-Grab-Token"})
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
    store = JobStore(settings)
    server = ThreadingHTTPServer(("0.0.0.0", settings["port"]), make_handler(store))
    server.daemon_threads = True

    def reaper():
        while True:
            time.sleep(30)
            store.reap()

    threading.Thread(target=reaper, daemon=True).start()
    print(f"[grab] listening on :{settings['port']}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
