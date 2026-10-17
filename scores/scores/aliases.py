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

from .leagues import COLLEGE_LEAGUES, LEAGUES

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
    "wnba": {
        "aces": "LV",
        "las vegas": "LV",
        "liberty": "NY",
        "new york liberty": "NY",
        "sky": "CHI",
        "dream": "ATL",
        "sun": "CON",
        "connecticut": "CON",
        "mystics": "WSH",
        "sparks": "LA",
        "mercury": "PHX",
        "phoenix": "PHX",
        "storm": "SEA",
        "wings": "DAL",
        "fever": "IND",
        "lynx": "MIN",
    },
    "mls": {
        "atlanta united": "ATL",
        "austin": "ATX",
        "austin fc": "ATX",
        "inter miami": "MIA",
        "miami": "MIA",
        "lafc": "LAFC",
        "la galaxy": "LA",
        "galaxy": "LA",
        "nycfc": "NYC",
        "new york city": "NYC",
        "red bulls": "RBNY",
        "ny red bulls": "RBNY",
        "seattle sounders": "SEA",
        "sounders": "SEA",
        "portland": "POR",
        "timbers": "POR",
        "whitecaps": "VAN",
        "vancouver": "VAN",
        "cf montreal": "MTL",
        "montreal": "MTL",
        "toronto fc": "TOR",
        "crew": "CLB",
        "columbus": "CLB",
        "fc cincinnati": "CIN",
        "cincinnati": "CIN",
        "st louis city": "STL",
        "nashville sc": "NSH",
        "nashville": "NSH",
        "orlando city": "ORL",
        "charlotte fc": "CLT",
        "charlotte": "CLT",
        "real salt lake": "RSL",
        "rsl": "RSL",
        "sporting kc": "SKC",
        "skc": "SKC",
        "minnesota united": "MIN",
        "loons": "MIN",
        "fc dallas": "DAL",
        "houston dynamo": "HOU",
        "dynamo": "HOU",
        "san jose": "SJ",
        "earthquakes": "SJ",
        "quakes": "SJ",
        "colorado rapids": "COL",
        "rapids": "COL",
        "chicago fire": "CHI",
        "dc united": "DC",
        "d c united": "DC",
        "new england": "NE",
        "revolution": "NE",
        "philadelphia union": "PHI",
        "union": "PHI",
    },
    "epl": {
        "man city": "MNC",
        "manchester city": "MNC",
        "man united": "MAN",
        "man utd": "MAN",
        "manchester united": "MAN",
        "spurs": "TOT",
        "tottenham": "TOT",
        "gunners": "ARS",
        "arsenal": "ARS",
        "chelsea": "CHE",
        "liverpool": "LIV",
        "newcastle": "NEW",
        "magpies": "NEW",
        "villa": "AVL",
        "aston villa": "AVL",
        "brighton": "BHA",
        "seagulls": "BHA",
        "crystal palace": "CRY",
        "palace": "CRY",
        "fulham": "FUL",
        "brentford": "BRE",
        "bournemouth": "BOU",
        "nottingham forest": "NFO",
        "forest": "NFO",
        "everton": "EVE",
        "toffees": "EVE",
        "ipswich": "IPS",
        "leeds": "LEE",
        "leeds united": "LEE",
        "sunderland": "SUN",
        "coventry": "COV",
        "hull": "HUL",
        "hull city": "HUL",
    },
    # School-name helpers for college boards (mascots are not indexed alone)
    "ncaaf": {
        "ohio st": "OSU",
        "ohio state": "OSU",
        "penn st": "PSU",
        "penn state": "PSU",
        "florida st": "FSU",
        "florida state": "FSU",
        "michigan st": "MSU",
        "michigan state": "MSU",
        "oklahoma st": "OKST",
        "oklahoma state": "OKST",
        "oregon st": "ORST",
        "oregon state": "ORST",
        "mississippi st": "MSST",
        "mississippi state": "MSST",
        "washington st": "WSU",
        "washington state": "WSU",
        "ole miss": "MISS",
        "lsu": "LSU",
        "usc": "USC",
        "ucla": "UCLA",
        "byu": "BYU",
        "tcu": "TCU",
        "smu": "SMU",
        "ucf": "UCF",
        "usu": "USU",
        "texas a m": "TA&M",
        "texas am": "TA&M",
        "a m": "TA&M",
        "notre dame": "ND",
        "miami fl": "MIA",
        "miami florida": "MIA",
        "boston college": "BC",
    },
    "ncaah": {
        "ohio st": "OSU",
        "ohio state": "OSU",
        "penn st": "PSU",
        "penn state": "PSU",
        "michigan st": "MSU",
        "michigan state": "MSU",
        "minnesota st": "MNST",
        "minnesota state": "MNST",
        "boston university": "BU",
        "boston u": "BU",
        "bu": "BU",
        "bc": "BC",
        "boston college": "BC",
        "umass": "MASS",
        "massachusetts": "MASS",
        "uconn": "CONN",
        "connecticut": "CONN",
        "north dakota": "UND",
        "und": "UND",
        "denver": "DEN",
        "providence": "PROV",
        "quinnipiac": "QUIN",
        "st cloud": "SCSU",
        "st cloud state": "SCSU",
        "minnesota duluth": "UMD",
        "umd": "UMD",
        "wisconsin": "WIS",
        "notre dame": "ND",
        "northeastern": "NE",
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
        # College mascots collide endlessly (Bulldogs/Tigers); school names matter
        if league in COLLEGE_LEAGUES:
            fields = ("abbreviation", "location", "displayName")
        else:
            fields = (
                "abbreviation",
                "name",
                "location",
                "displayName",
                "shortDisplayName",
            )
        for team in teams:
            tid = team["id"]
            for field in fields:
                _add_alias(index, team.get(field) or "", tid)
            slug = (team.get("slug") or "").replace("-", " ")
            _add_alias(index, slug, tid)

        for alias, target in EXTRA_ALIASES.get(league, {}).items():
            team = _resolve_extra_target(teams, target)
            if team is None:
                continue
            _add_alias(index, alias, team["id"])

        out[league] = index
    return out


def _resolve_extra_target(teams: list[dict[str, str]], target: str) -> dict[str, str] | None:
    """Map EXTRA_ALIASES values to a team (abbr, id, or unique location/name)."""
    raw = str(target or "").strip()
    if not raw:
        return None
    for team in teams:
        if team["id"] == raw:
            return team

    key = normalize_text(raw)
    loc_hits = [t for t in teams if normalize_text(t.get("location") or "") == key]
    if len(loc_hits) == 1:
        return loc_hits[0]
    display_hits = [t for t in teams if normalize_text(t.get("displayName") or "") == key]
    if len(display_hits) == 1:
        return display_hits[0]

    abbr = raw.upper()
    abbr_hits = [t for t in teams if (t.get("abbreviation") or "").upper() == abbr]
    if not abbr_hits:
        return None
    if len(abbr_hits) == 1:
        return abbr_hits[0]
    # Duplicate abbrs (OSU Buckeyes vs OSU Newark): prefer the shortest location
    return sorted(abbr_hits, key=lambda t: (len(t.get("location") or ""), t.get("location") or ""))[0]


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
