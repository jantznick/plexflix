"""Resolve a sports-feed title to today's ESPN event via alias dictionary."""

from __future__ import annotations

from typing import Any

from .aliases import default_alias_index, default_teams_by_id, find_teams_in_title
from .espn import display_status, score_line
from .leagues import normalize_league


def _pair_key(a: str, b: str) -> frozenset[str]:
    return frozenset((a, b))


def index_events_by_teams(events: list[dict[str, Any]]) -> dict[frozenset[str], list[dict[str, Any]]]:
    out: dict[frozenset[str], list[dict[str, Any]]] = {}
    for event in events:
        key = _pair_key(event["home"]["id"], event["away"]["id"])
        out.setdefault(key, []).append(event)
    return out


def pick_best_event(candidates: list[dict[str, Any]]) -> dict[str, Any] | None:
    if not candidates:
        return None
    if len(candidates) == 1:
        return candidates[0]

    def rank(event: dict[str, Any]) -> tuple[int, str]:
        state = event.get("state") or ""
        # Prefer live, then scheduled, then final (for multi-game same day rare)
        state_rank = {"in": 0, "pre": 1, "post": 2}.get(state, 3)
        return (state_rank, event.get("startTime") or "")

    return sorted(candidates, key=rank)[0]


def format_match(event: dict[str, Any], *, confidence: str, matched_teams: list[str]) -> dict[str, Any]:
    return {
        "matched": True,
        "confidence": confidence,
        "reason": "",
        "league": event["league"],
        "eventId": event["eventId"],
        "name": event["name"],
        "shortName": event["shortName"],
        "scoreLine": score_line(event),
        "status": event["state"],
        "statusDetail": event["statusDetail"],
        "shortDetail": event["shortDetail"],
        "displayStatus": display_status(event),
        "clock": event["clock"],
        "period": event["period"],
        "completed": event["completed"],
        "home": event["home"],
        "away": event["away"],
        "broadcasts": event.get("broadcasts") or [],
        "startTime": event.get("startTime") or "",
        "matchedTeamIds": matched_teams,
    }


def unmatched(reason: str, **extra: Any) -> dict[str, Any]:
    base = {
        "matched": False,
        "confidence": "none",
        "reason": reason,
        "league": extra.get("league"),
        "eventId": "",
        "scoreLine": "",
        "status": "",
        "displayStatus": "",
        "matchedTeamIds": extra.get("matchedTeamIds") or [],
    }
    base.update(extra)
    return base


def resolve_title(
    title: str,
    league: str | None,
    events_by_league: dict[str, list[dict[str, Any]]],
    *,
    alias_index=None,
    teams_by_id=None,
) -> dict[str, Any]:
    canon = normalize_league(league)
    if canon is None:
        return unmatched("unsupported_league", league=league, title=title)

    events = events_by_league.get(canon) or []
    if not events:
        return unmatched("no_scoreboard", league=canon, title=title)

    alias_index = alias_index or default_alias_index()
    teams_by_id = teams_by_id or default_teams_by_id()
    found = find_teams_in_title(title, canon, alias_index=alias_index)
    team_ids: list[str] = list(found["team_ids"])

    # If city-only aliases were ambiguous but exactly one remaining team pairs
    # with an unambiguous hit on today's slate, accept that pair.
    if len(team_ids) < 2 and found["ambiguous"]:
        team_ids = _disambiguate_with_slate(
            team_ids, found["ambiguous"], events, teams_by_id.get(canon) or {}
        )

    if len(team_ids) < 2:
        return unmatched(
            "need_two_teams",
            league=canon,
            title=title,
            matchedTeamIds=team_ids,
            hits=found["hits"],
            ambiguous=found["ambiguous"],
        )

    by_pair = index_events_by_teams(events)

    if len(team_ids) == 2:
        candidates = by_pair.get(_pair_key(team_ids[0], team_ids[1])) or []
        event = pick_best_event(candidates)
        if event is None:
            return unmatched(
                "teams_not_playing",
                league=canon,
                title=title,
                matchedTeamIds=team_ids,
            )
        return format_match(event, confidence="high", matched_teams=team_ids)

    # More than two team mentions — try every pair that appears on the slate
    candidates: list[dict[str, Any]] = []
    used_ids: list[str] = []
    for i in range(len(team_ids)):
        for j in range(i + 1, len(team_ids)):
            pair = _pair_key(team_ids[i], team_ids[j])
            for event in by_pair.get(pair) or []:
                candidates.append(event)
                used_ids = [team_ids[i], team_ids[j]]
    event = pick_best_event(candidates)
    if event is None:
        return unmatched(
            "teams_not_playing",
            league=canon,
            title=title,
            matchedTeamIds=team_ids,
        )
    return format_match(event, confidence="medium", matched_teams=used_ids or team_ids[:2])


def _disambiguate_with_slate(
    known: list[str],
    ambiguous_hits: list[dict[str, Any]],
    events: list[dict[str, Any]],
    teams: dict[str, dict[str, str]],
) -> list[str]:
    """Resolve ambiguous city aliases using who is actually playing today."""
    if not known:
        return known
    opponent = known[0]
    slate_opponents: set[str] = set()
    for event in events:
        ids = event["teamIds"]
        if opponent in ids:
            slate_opponents |= ids - {opponent}

    resolved = list(known)
    for hit in ambiguous_hits:
        options = [tid for tid in hit["team_ids"] if tid in slate_opponents and tid in teams]
        if len(options) == 1 and options[0] not in resolved:
            resolved.append(options[0])
        if len(resolved) >= 2:
            break
    return resolved


def resolve_items(
    items: list[dict[str, Any]],
    events_by_league: dict[str, list[dict[str, Any]]],
    **kwargs: Any,
) -> list[dict[str, Any]]:
    results = []
    for item in items:
        title = str(item.get("title") or item.get("name") or "")
        league = item.get("league") or item.get("category") or item.get("sport")
        match = resolve_title(title, league, events_by_league, **kwargs)
        result = {
            "id": item.get("id") or item.get("key") or "",
            "title": title,
            "requestLeague": league,
            **match,
        }
        results.append(result)
    return results
