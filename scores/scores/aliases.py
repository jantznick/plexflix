"""Alias dictionary: normalized string → team id(s) within a league.

Matching is intentionally dictionary-first. ESPN team catalogs seed the map;
EXTRA_ALIASES covers nicknames / abbreviations stream titles actually use.
"""

from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path
from typing import Any

from .leagues import LEAGUES

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
TEAMS_PATH = DATA_DIR / "teams.json"

# Hand-maintained extras keyed by league → alias → team abbreviation (or id).
# Prefer abbreviations so the seed stays readable; resolved against catalog at build time.
EXTRA_ALIASES: dict[str, dict[str, str]] = {
    "nhl": {
        "bolts": "TB",
        "lightning": "TB",
        "caps": "WSH",
        "capitals": "WSH",
        "hawks": "CHI",  # Blackhawks; NBA Hawks are separate league
        "blackhawks": "CHI",
        "jackets": "CBJ",
        "blue jackets": "CBJ",
        "canes": "CAR",
        "hurricanes": "CAR",
        "avs": "COL",
        "avalanche": "COL",
        "preds": "NSH",
        "predators": "NSH",
        "yotes": "UTAH",  # historical Coyotes titles → Utah franchise
        "coyotes": "UTAH",
        "utah": "UTAH",
        "mammoth": "UTAH",
        "hockey club": "UTAH",
        "kraken": "SEA",
        "leafs": "TOR",
        "maple leafs": "TOR",
        "habs": "MTL",
        "canadiens": "MTL",
        "montreal": "MTL",
        "sens": "OTT",
        "senators": "OTT",
        "isles": "NYI",
        "islanders": "NYI",
        "rangers": "NYR",
        "nyr": "NYR",
        "nyi": "NYI",
        "devils": "NJD",
        "nj": "NJD",
        "njd": "NJD",
        "wings": "DET",
        "red wings": "DET",
        "pens": "PIT",
        "penguins": "PIT",
        "gags": "VGK",  # rare
        "golden knights": "VGK",
        "knights": "VGK",
        "vegas": "VGK",
        "la kings": "LA",
        "kings": "LA",
        "sj": "SJ",
        "sharks": "SJ",
        "san jose": "SJ",
    },
    "nba": {
        "sixers": "PHI",
        "76ers": "PHI",
        "cavs": "CLE",
        "cavaliers": "CLE",
        "mavs": "DAL",
        "mavericks": "DAL",
        "okc": "OKC",
        "thunder": "OKC",
        "blazers": "POR",
        "trail blazers": "POR",
        "portland": "POR",
        "wolves": "MIN",
        "timberwolves": "MIN",
        "pels": "NO",
        "pelicans": "NO",
        "nyk": "NY",
        "knicks": "NY",
        "knickerbockers": "NY",
        "gs": "GS",
        "gsw": "GS",
        "warriors": "GS",
        "golden state": "GS",
        "dubs": "GS",
        "clips": "LAC",
        "clippers": "LAC",
        "lakers": "LAL",
        "lal": "LAL",
        "lac": "LAC",
        "spurs": "SA",
        "san antonio": "SA",
        "nets": "BKN",
        "brooklyn": "BKN",
    },
    "nfl": {
        "niners": "SF",
        "49ers": "SF",
        "nine rs": "SF",
        "pats": "NE",
        "patriots": "NE",
        "buccs": "TB",
        "bucs": "TB",
        "buccaneers": "TB",
        "vikes": "MIN",
        "vikings": "MIN",
        "hawks": "SEA",  # Seahawks within NFL
        "seahawks": "SEA",
        "boys": "DAL",
        "cowboys": "DAL",
        "america's team": "DAL",
        "commanders": "WSH",
        "washington": "WSH",
        "football team": "WSH",
        "az": "ARI",
        "cards": "ARI",
        "cardinals": "ARI",
        "arizona": "ARI",
        "gb": "GB",
        "pack": "GB",
        "packers": "GB",
        "green bay": "GB",
        "kc": "KC",
        "chiefs": "KC",
        "kansas city": "KC",
        "philly": "PHI",
        "eagles": "PHI",
        "nyg": "NYG",
        "nyj": "NYJ",
        "giants": "NYG",
        "jets": "NYJ",
        "ravens": "BAL",
        "baltimore": "BAL",
        "bengals": "CIN",
        "cincy": "CIN",
        "browns": "CLE",
        "steelers": "PIT",
        "stillers": "PIT",
    },
    "mlb": {
        "a's": "ATH",
        "as": "ATH",
        "athletics": "ATH",
        "oakland": "ATH",
        "dbacks": "ARI",
        "d-backs": "ARI",
        "diamondbacks": "ARI",
        "bosox": "BOS",
        "sox": "BOS",  # ambiguous with White Sox — prefer "red sox" / "white sox"
        "red sox": "BOS",
        "white sox": "CHW",
        "cws": "CHW",
        "chi sox": "CHW",
        "yanks": "NYY",
        "yankees": "NYY",
        "nyy": "NYY",
        "nym": "NYM",
        "mets": "NYM",
        "cubs": "CHC",
        "chi cubs": "CHC",
        "jays": "TOR",
        "blue jays": "TOR",
        "halos": "LAA",
        "angels": "LAA",
        "laa": "LAA",
        "dodgers": "LAD",
        "lad": "LAD",
        "la dodgers": "LAD",
        "sf giants": "SF",
        "giants": "SF",
        "pads": "SD",
        "padres": "SD",
        "friars": "SD",
        "nats": "WSH",
        "nationals": "WSH",
        "os": "BAL",
        "orioles": "BAL",
        "birds": "BAL",
        "stlouis": "STL",
        "st louis": "STL",
        "cards": "STL",
        "cardinals": "STL",
    },
}

_SPLIT_RE = re.compile(
    r"\s*(?:\bvs\.?\b|\bv\.?\b|\bat\b|@|&|/|,|\||—|–|-)\s*",
    re.IGNORECASE,
)
_NON_ALNUM = re.compile(r"[^a-z0-9]+")


def normalize_text(value: str) -> str:
    text = (value or "").lower().replace("’", "'").replace("`", "'")
    text = text.replace("&", " and ")
    text = _NON_ALNUM.sub(" ", text)
    return " ".join(text.split())


def load_teams_seed(path: Path | None = None) -> dict[str, list[dict[str, str]]]:
    seed_path = path or TEAMS_PATH
    with seed_path.open(encoding="utf-8") as fh:
        raw = json.load(fh)
    out: dict[str, list[dict[str, str]]] = {}
    for league in LEAGUES:
        rows = raw.get(league) or []
        out[league] = [
            {
                "id": str(row["id"]),
                "abbreviation": str(row.get("abbreviation") or ""),
                "name": str(row.get("name") or ""),
                "location": str(row.get("location") or ""),
                "displayName": str(row.get("displayName") or ""),
                "shortDisplayName": str(row.get("shortDisplayName") or ""),
                "slug": str(row.get("slug") or ""),
            }
            for row in rows
        ]
    return out


def _add_alias(index: dict[str, set[str]], alias: str, team_id: str) -> None:
    key = normalize_text(alias)
    if not key or len(key) < 2:
        return
    # Single letters are too noisy (except we already require len>=2)
    index.setdefault(key, set()).add(team_id)


def build_alias_index(
    teams_by_league: dict[str, list[dict[str, str]]] | None = None,
) -> dict[str, dict[str, set[str]]]:
    """Return {league: {normalized_alias: {team_id, ...}}}."""
    catalog = teams_by_league or load_teams_seed()
    out: dict[str, dict[str, set[str]]] = {}

    for league, teams in catalog.items():
        by_abbr = {t["abbreviation"].upper(): t for t in teams if t.get("abbreviation")}
        index: dict[str, set[str]] = {}
        for team in teams:
            tid = team["id"]
            for field in (
                "abbreviation",
                "name",
                "location",
                "displayName",
                "shortDisplayName",
            ):
                _add_alias(index, team.get(field) or "", tid)
            slug = (team.get("slug") or "").replace("-", " ")
            _add_alias(index, slug, tid)
            # "Boston Bruins" also yields "Boston" + "Bruins" already via fields

        for alias, target in EXTRA_ALIASES.get(league, {}).items():
            team = by_abbr.get(target.upper())
            if team is None:
                # Allow raw ESPN ids in EXTRA_ALIASES if needed later
                if any(t["id"] == str(target) for t in teams):
                    _add_alias(index, alias, str(target))
                continue
            _add_alias(index, alias, team["id"])

        out[league] = index
    return out


def teams_by_id(
    teams_by_league: dict[str, list[dict[str, str]]] | None = None,
) -> dict[str, dict[str, dict[str, str]]]:
    catalog = teams_by_league or load_teams_seed()
    return {league: {t["id"]: t for t in teams} for league, teams in catalog.items()}


@lru_cache(maxsize=1)
def default_alias_index() -> dict[str, dict[str, set[str]]]:
    return build_alias_index()


@lru_cache(maxsize=1)
def default_teams_by_id() -> dict[str, dict[str, dict[str, str]]]:
    return teams_by_id()


def split_title_sides(title: str) -> list[str]:
    """Split a matchup title into side fragments when separators are present."""
    text = title or ""
    parts = [p.strip() for p in _SPLIT_RE.split(text) if p and p.strip()]
    return parts if len(parts) >= 2 else [text.strip()]


def find_teams_in_title(
    title: str,
    league: str,
    alias_index: dict[str, dict[str, set[str]]] | None = None,
) -> dict[str, Any]:
    """Find team ids mentioned in a title.

    Longer aliases win and consume their span so "New York Rangers" does not
    also count a bare "New York" hit as a second team.
    """
    index = (alias_index or default_alias_index()).get(league) or {}
    norm = normalize_text(title)
    if not norm:
        return {"team_ids": [], "hits": [], "ambiguous": []}

    # Prefer longer aliases so multi-word names beat city-only tokens
    aliases = sorted(index.keys(), key=lambda a: (-len(a), a))
    tokens = norm.split()
    used = [False] * len(tokens)
    hits: list[dict[str, Any]] = []
    ambiguous: list[dict[str, Any]] = []

    for alias in aliases:
        alias_tokens = alias.split()
        n = len(alias_tokens)
        if n == 0:
            continue
        for i in range(0, len(tokens) - n + 1):
            if any(used[i : i + n]):
                continue
            if tokens[i : i + n] != alias_tokens:
                continue
            team_ids = sorted(index[alias])
            span = (i, i + n)
            for j in range(i, i + n):
                used[j] = True
            entry = {"alias": alias, "team_ids": team_ids, "span": span}
            if len(team_ids) == 1:
                hits.append(entry)
            else:
                ambiguous.append(entry)

    # Unique team ids from unambiguous hits, preserving order
    seen: list[str] = []
    for hit in hits:
        tid = hit["team_ids"][0]
        if tid not in seen:
            seen.append(tid)

    return {"team_ids": seen, "hits": hits, "ambiguous": ambiguous}
