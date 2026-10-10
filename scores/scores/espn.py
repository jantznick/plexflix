"""Thin ESPN Site API v2 client (scoreboards + optional team refresh)."""

from __future__ import annotations

import json
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Callable

from .leagues import LEAGUES

DEFAULT_UA = "PlexFlixScores/0.1 (+https://github.com/jantznick/plexflix)"
SITE_V2 = "https://site.api.espn.com/apis/site/v2/sports"


class EspnError(RuntimeError):
    pass


def _default_fetch(url: str, timeout: float = 12.0) -> dict[str, Any]:
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": DEFAULT_UA,
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read()
    except urllib.error.HTTPError as exc:
        raise EspnError(f"ESPN HTTP {exc.code} for {url}") from exc
    except urllib.error.URLError as exc:
        raise EspnError(f"ESPN network error for {url}: {exc.reason}") from exc
    try:
        return json.loads(body.decode("utf-8"))
    except json.JSONDecodeError as exc:
        raise EspnError(f"ESPN returned non-JSON for {url}") from exc


def scoreboard_url(league: str, dates: str | None = None) -> str:
    meta = LEAGUES[league]
    path = f"{SITE_V2}/{meta['sport']}/{meta['league']}/scoreboard"
    if dates:
        path += "?" + urllib.parse.urlencode({"dates": dates})
    return path


def teams_url(league: str) -> str:
    meta = LEAGUES[league]
    return f"{SITE_V2}/{meta['sport']}/{meta['league']}/teams?limit=100"


def parse_competitors(competition: dict[str, Any]) -> dict[str, dict[str, str]]:
    home: dict[str, str] = {}
    away: dict[str, str] = {}
    for row in competition.get("competitors") or []:
        team = row.get("team") or {}
        entry = {
            "id": str(team.get("id") or row.get("id") or ""),
            "abbreviation": str(team.get("abbreviation") or ""),
            "name": str(team.get("displayName") or team.get("name") or ""),
            "shortName": str(team.get("shortDisplayName") or team.get("name") or ""),
            "score": str(row.get("score") if row.get("score") is not None else ""),
            "homeAway": str(row.get("homeAway") or ""),
        }
        if entry["homeAway"] == "home":
            home = entry
        elif entry["homeAway"] == "away":
            away = entry
    return {"home": home, "away": away}


def normalize_event(raw: dict[str, Any], league: str) -> dict[str, Any] | None:
    competitions = raw.get("competitions") or []
    if not competitions:
        return None
    comp = competitions[0]
    status = (comp.get("status") or {}).get("type") or {}
    clock_status = comp.get("status") or {}
    sides = parse_competitors(comp)
    home = sides["home"]
    away = sides["away"]
    if not home.get("id") or not away.get("id"):
        return None

    broadcasts: list[str] = []
    for b in comp.get("broadcasts") or []:
        for name in b.get("names") or []:
            if name and name not in broadcasts:
                broadcasts.append(str(name))

    return {
        "eventId": str(raw.get("id") or ""),
        "league": league,
        "name": str(raw.get("name") or ""),
        "shortName": str(raw.get("shortName") or ""),
        "state": str(status.get("state") or ""),  # pre | in | post
        "statusName": str(status.get("name") or ""),
        "statusDetail": str(status.get("detail") or ""),
        "shortDetail": str(status.get("shortDetail") or ""),
        "completed": bool(status.get("completed")),
        "clock": str(clock_status.get("displayClock") or ""),
        "period": int(clock_status.get("period") or 0),
        "home": home,
        "away": away,
        "teamIds": {home["id"], away["id"]},
        "broadcasts": broadcasts,
        "startTime": str(comp.get("date") or raw.get("date") or ""),
    }


def score_line(event: dict[str, Any]) -> str:
    away = event["away"]
    home = event["home"]
    a_abbr = away.get("abbreviation") or "?"
    h_abbr = home.get("abbreviation") or "?"
    state = event.get("state") or ""
    if state == "pre":
        return f"{a_abbr} @ {h_abbr}"
    a_score = away.get("score") or "0"
    h_score = home.get("score") or "0"
    return f"{a_abbr} {a_score}-{h_score} {h_abbr}"


def display_status(event: dict[str, Any]) -> str:
    state = event.get("state") or ""
    if state == "in":
        detail = event.get("shortDetail") or event.get("statusDetail") or "Live"
        return detail
    if state == "post":
        return event.get("shortDetail") or event.get("statusDetail") or "Final"
    return event.get("shortDetail") or event.get("statusDetail") or "Scheduled"


class EspnClient:
    def __init__(self, fetch: Callable[[str], dict[str, Any]] | None = None):
        self._fetch = fetch or _default_fetch

    def fetch_scoreboard(self, league: str, dates: str | None = None) -> list[dict[str, Any]]:
        if league not in LEAGUES:
            raise EspnError(f"Unsupported league: {league}")
        payload = self._fetch(scoreboard_url(league, dates=dates))
        events = []
        for raw in payload.get("events") or []:
            normalized = normalize_event(raw, league)
            if normalized is not None:
                events.append(normalized)
        return events

    def fetch_teams(self, league: str) -> list[dict[str, str]]:
        if league not in LEAGUES:
            raise EspnError(f"Unsupported league: {league}")
        payload = self._fetch(teams_url(league))
        sports = payload.get("sports") or []
        if not sports:
            return []
        leagues = sports[0].get("leagues") or []
        if not leagues:
            return []
        out: list[dict[str, str]] = []
        for row in leagues[0].get("teams") or []:
            team = row.get("team") or row
            out.append(
                {
                    "id": str(team.get("id") or ""),
                    "abbreviation": str(team.get("abbreviation") or ""),
                    "name": str(team.get("name") or ""),
                    "location": str(team.get("location") or ""),
                    "displayName": str(team.get("displayName") or ""),
                    "shortDisplayName": str(team.get("shortDisplayName") or ""),
                    "slug": str(team.get("slug") or ""),
                }
            )
        return [t for t in out if t["id"]]
