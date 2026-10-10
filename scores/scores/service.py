"""In-memory scoreboard cache with background refresh."""

from __future__ import annotations

import threading
import time
from datetime import datetime, timezone
from typing import Any, Callable

from .espn import EspnClient, EspnError
from .leagues import LEAGUES, normalize_league
from .matcher import resolve_items, resolve_title


class ScoreService:
    def __init__(
        self,
        client: EspnClient | None = None,
        *,
        refresh_seconds: float = 30.0,
        idle_refresh_seconds: float = 300.0,
        clock: Callable[[], float] | None = None,
        autostart: bool = True,
    ):
        self.client = client or EspnClient()
        self.refresh_seconds = refresh_seconds
        self.idle_refresh_seconds = idle_refresh_seconds
        self._clock = clock or time.monotonic
        self._lock = threading.RLock()
        self._events: dict[str, list[dict[str, Any]]] = {k: [] for k in LEAGUES}
        self._fetched_at: dict[str, float] = {}
        self._errors: dict[str, str] = {}
        self._updated_iso = ""
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        if autostart:
            self.refresh_all(force=True)
            self.start()

    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._stop.clear()
        self._thread = threading.Thread(target=self._loop, name="scores-refresh", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=2.0)

    def _loop(self) -> None:
        while not self._stop.wait(self._next_delay()):
            try:
                self.refresh_all(force=False)
            except Exception:
                # Keep the loop alive; per-league errors are recorded in refresh
                pass

    def _next_delay(self) -> float:
        with self._lock:
            any_live = any(
                event.get("state") == "in"
                for events in self._events.values()
                for event in events
            )
        return self.refresh_seconds if any_live else self.idle_refresh_seconds

    def refresh_all(self, force: bool = False) -> dict[str, Any]:
        summary = {}
        for league in LEAGUES:
            summary[league] = self.refresh_league(league, force=force)
        with self._lock:
            self._updated_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        return summary

    def refresh_league(self, league: str, force: bool = False) -> dict[str, Any]:
        canon = normalize_league(league) or league
        if canon not in LEAGUES:
            return {"ok": False, "error": "unsupported_league"}

        now = self._clock()
        with self._lock:
            last = self._fetched_at.get(canon, 0.0)
            delay = self._next_delay()
            if not force and last and (now - last) < delay:
                return {"ok": True, "skipped": True, "events": len(self._events[canon])}

        try:
            events = self.client.fetch_scoreboard(canon)
            error = ""
            ok = True
        except EspnError as exc:
            events = None
            error = str(exc)
            ok = False

        with self._lock:
            if ok and events is not None:
                self._events[canon] = events
                self._fetched_at[canon] = now
                self._errors.pop(canon, None)
                count = len(events)
            else:
                self._errors[canon] = error
                count = len(self._events.get(canon) or [])
            return {"ok": ok, "error": error, "events": count}

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            return {
                "updated": self._updated_iso,
                "leagues": {
                    league: {
                        "events": list(events),
                        "fetchedAt": self._fetched_at.get(league),
                        "error": self._errors.get(league, ""),
                    }
                    for league, events in self._events.items()
                },
            }

    def events(self, league: str | None = None) -> dict[str, list[dict[str, Any]]]:
        with self._lock:
            if league:
                canon = normalize_league(league)
                if canon is None:
                    return {}
                return {canon: list(self._events.get(canon) or [])}
            return {k: list(v) for k, v in self._events.items()}

    def resolve(self, title: str, league: str | None) -> dict[str, Any]:
        return resolve_title(title, league, self.events())

    def resolve_many(self, items: list[dict[str, Any]]) -> dict[str, Any]:
        # Touch scoreboards for leagues referenced so first resolve isn't stale
        needed = set()
        for item in items:
            canon = normalize_league(item.get("league") or item.get("category") or item.get("sport"))
            if canon:
                needed.add(canon)
        for league in needed or LEAGUES:
            self.refresh_league(league, force=False)

        with self._lock:
            updated = self._updated_iso
            events = {k: list(v) for k, v in self._events.items()}
        results = resolve_items(items, events)
        matched = sum(1 for r in results if r.get("matched"))
        return {
            "updated": updated,
            "matched": matched,
            "total": len(results),
            "results": results,
        }
