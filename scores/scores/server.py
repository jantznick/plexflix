"""HTTP API the Roku channel calls for live scores.

    GET  /healthz
    GET  /v1/leagues
    GET  /v1/scoreboard?league=nhl
    GET  /v1/match?title=Kraken%20@%20Wings&league=hockey
    POST /v1/resolve   {"items":[{"id","title","league"}, ...]}
    POST /v1/refresh   optional {"league":"nhl"} — force ESPN pull
"""

from __future__ import annotations

import json
import os
import re
import urllib.parse
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

from .leagues import LEAGUES
from .service import ScoreService

MATCH_PATH = re.compile(r"^/v1/match/?$")
SCOREBOARD_PATH = re.compile(r"^/v1/scoreboard/?$")
RESOLVE_PATH = re.compile(r"^/v1/resolve/?$")
REFRESH_PATH = re.compile(r"^/v1/refresh/?$")
LEAGUES_PATH = re.compile(r"^/v1/leagues/?$")
HEALTH_PATH = re.compile(r"^/healthz/?$")


def settings_from_env(env=os.environ) -> dict[str, Any]:
    return {
        "host": env.get("HOST", "0.0.0.0"),
        "port": int(env.get("PORT", "8096")),
        "token": env.get("SCORES_TOKEN", ""),
        "refresh_seconds": float(env.get("REFRESH_SECONDS", "30")),
        "idle_refresh_seconds": float(env.get("IDLE_REFRESH_SECONDS", "300")),
    }


class ScoresHandler(BaseHTTPRequestHandler):
    server_version = "PlexFlixScores/0.1"

    @property
    def service(self) -> ScoreService:
        return self.server.score_service  # type: ignore[attr-defined]

    @property
    def token(self) -> str:
        return getattr(self.server, "token", "") or ""

    def log_message(self, fmt: str, *args) -> None:
        print(f"[scores] {self.address_string()} {fmt % args}")

    def _unauthorized(self) -> None:
        self._json(HTTPStatus.UNAUTHORIZED, {"ok": False, "error": "unauthorized"})

    def _check_auth(self) -> bool:
        expected = self.token
        if not expected:
            return True
        header = self.headers.get("Authorization") or ""
        if header == f"Bearer {expected}":
            return True
        if (self.headers.get("X-Scores-Token") or "") == expected:
            return True
        # Also allow ?token= for simple Roku GETs
        parsed = urllib.parse.urlparse(self.path)
        qs = urllib.parse.parse_qs(parsed.query)
        if (qs.get("token") or [""])[0] == expected:
            return True
        self._unauthorized()
        return False

    def _read_json(self) -> Any:
        length = int(self.headers.get("Content-Length") or "0")
        if length <= 0:
            return None
        raw = self.rfile.read(length)
        if not raw:
            return None
        return json.loads(raw.decode("utf-8"))

    def _json(self, status: int, payload: Any) -> None:
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(HTTPStatus.NO_CONTENT)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers",
            "Content-Type, Authorization, X-Scores-Token",
        )
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        qs = urllib.parse.parse_qs(parsed.query)

        if HEALTH_PATH.match(path):
            snap = self.service.snapshot()
            self._json(
                HTTPStatus.OK,
                {
                    "ok": True,
                    "updated": snap.get("updated") or "",
                    "leagues": {
                        league: {
                            "events": len(info["events"]),
                            "error": info.get("error") or "",
                        }
                        for league, info in snap["leagues"].items()
                    },
                },
            )
            return

        if not self._check_auth():
            return

        if LEAGUES_PATH.match(path):
            self._json(
                HTTPStatus.OK,
                {
                    "leagues": [
                        {"id": key, **meta}
                        for key, meta in LEAGUES.items()
                    ]
                },
            )
            return

        if SCOREBOARD_PATH.match(path):
            league = (qs.get("league") or [""])[0]
            events_map = self.service.events(league or None)
            if league and not events_map:
                self._json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": "unsupported_league"})
                return
            snap = self.service.snapshot()
            self._json(
                HTTPStatus.OK,
                {
                    "updated": snap.get("updated") or "",
                    "leagues": {
                        key: {
                            "events": events,
                            "error": snap["leagues"].get(key, {}).get("error") or "",
                        }
                        for key, events in events_map.items()
                    },
                },
            )
            return

        if MATCH_PATH.match(path):
            title = (qs.get("title") or [""])[0]
            league = (qs.get("league") or [""])[0]
            if not title:
                self._json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": "title required"})
                return
            # Ensure cache is warm for this league
            if league:
                self.service.refresh_league(league, force=False)
            else:
                self.service.refresh_all(force=False)
            result = self.service.resolve(title, league or None)
            self._json(HTTPStatus.OK, {"updated": self.service.snapshot().get("updated"), **result, "title": title})
            return

        self._json(HTTPStatus.NOT_FOUND, {"ok": False, "error": "not_found"})

    def do_POST(self) -> None:  # noqa: N802
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if not self._check_auth():
            return

        try:
            payload = self._read_json()
        except json.JSONDecodeError:
            self._json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": "invalid_json"})
            return

        if RESOLVE_PATH.match(path):
            items = []
            if isinstance(payload, dict):
                items = payload.get("items") or payload.get("events") or []
            elif isinstance(payload, list):
                items = payload
            if not isinstance(items, list):
                self._json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": "items must be a list"})
                return
            # Cap batch size so a bad client can't stall the stick
            if len(items) > 200:
                self._json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": "max 200 items"})
                return
            clean = []
            for item in items:
                if isinstance(item, dict):
                    clean.append(item)
                elif isinstance(item, str):
                    clean.append({"title": item})
            body = self.service.resolve_many(clean)
            self._json(HTTPStatus.OK, {"ok": True, **body})
            return

        if REFRESH_PATH.match(path):
            league = ""
            if isinstance(payload, dict):
                league = str(payload.get("league") or "")
            if league:
                summary = {league: self.service.refresh_league(league, force=True)}
            else:
                summary = self.service.refresh_all(force=True)
            self._json(HTTPStatus.OK, {"ok": True, "refreshed": summary, "updated": self.service.snapshot().get("updated")})
            return

        self._json(HTTPStatus.NOT_FOUND, {"ok": False, "error": "not_found"})


class ScoresServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, host: str, port: int, service: ScoreService, token: str = ""):
        super().__init__((host, port), ScoresHandler)
        self.score_service = service
        self.token = token


def make_server(settings: dict[str, Any] | None = None, service: ScoreService | None = None) -> ScoresServer:
    cfg = settings or settings_from_env()
    svc = service or ScoreService(
        refresh_seconds=cfg["refresh_seconds"],
        idle_refresh_seconds=cfg["idle_refresh_seconds"],
    )
    return ScoresServer(cfg["host"], cfg["port"], svc, token=cfg.get("token") or "")


def main(env=os.environ) -> None:
    cfg = settings_from_env(env)
    server = make_server(cfg)
    print(
        f"[scores] listening on http://{cfg['host']}:{cfg['port']} "
        f"(refresh={cfg['refresh_seconds']}s live / {cfg['idle_refresh_seconds']}s idle)"
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("[scores] shutting down")
    finally:
        server.score_service.stop()
        server.server_close()
