"""League ids and how sports-feed category labels map onto them."""

from __future__ import annotations

# ESPN Site API v2 paths
LEAGUES: dict[str, dict[str, str]] = {
    "nhl": {"sport": "hockey", "league": "nhl", "label": "NHL"},
    "nba": {"sport": "basketball", "league": "nba", "label": "NBA"},
    "nfl": {"sport": "football", "league": "nfl", "label": "NFL"},
    "mlb": {"sport": "baseball", "league": "mlb", "label": "MLB"},
    "wnba": {"sport": "basketball", "league": "wnba", "label": "WNBA"},
    "mls": {"sport": "soccer", "league": "usa.1", "label": "MLS"},
    "epl": {"sport": "soccer", "league": "eng.1", "label": "Premier League"},
    "ncaaf": {"sport": "football", "league": "college-football", "label": "NCAAF"},
    # NCAA Division I men's hockey (ESPN slug)
    "ncaah": {"sport": "hockey", "league": "mens-college-hockey", "label": "NCAA Hockey"},
}

# Virtual category keys that expand to several real leagues
LEAGUE_GROUPS: dict[str, list[str]] = {
    "soccer": ["mls", "epl"],
}

# When a feed buckets college (etc.) under a pro category, try these next.
# NCAAF/NCAAH share ESPN school ids, so football-labeled hockey (and vice versa)
# must be able to cross over after a teams_not_playing miss.
LEAGUE_FALLBACKS: dict[str, list[str]] = {
    "nhl": ["ncaah"],
    "nfl": ["ncaaf", "ncaah"],
    "ncaaf": ["ncaah"],
    "ncaah": ["ncaaf"],
    "nba": ["wnba"],
    "soccer": ["mls", "epl"],
}

# College catalogs: skip mascot-only aliases (too many Bulldogs/Tigers)
COLLEGE_LEAGUES = frozenset({"ncaaf", "ncaah"})

# Sports-feed category / league strings → canonical league or group key
CATEGORY_ALIASES: dict[str, str] = {
    "nhl": "nhl",
    "hockey": "nhl",
    "ice hockey": "nhl",
    "nba": "nba",
    "basketball": "nba",
    "nfl": "nfl",
    "football": "nfl",
    "american football": "nfl",
    "mlb": "mlb",
    "baseball": "mlb",
    # WNBA
    "wnba": "wnba",
    "womens basketball": "wnba",
    "women's basketball": "wnba",
    "women basketball": "wnba",
    # Soccer
    "mls": "mls",
    "major league soccer": "mls",
    "epl": "epl",
    "premier league": "epl",
    "english premier league": "epl",
    "prem": "epl",
    "soccer": "soccer",
    "football soccer": "soccer",
    # College football
    "ncaaf": "ncaaf",
    "cfb": "ncaaf",
    "college football": "ncaaf",
    "ncaa football": "ncaaf",
    "ncaa fb": "ncaaf",
    "american football ncaa": "ncaaf",
    # NCAA D1 men's hockey (feed labels vary a lot)
    "ncaah": "ncaah",
    "ncaa hockey": "ncaah",
    "college hockey": "ncaah",
    "mens college hockey": "ncaah",
    "men's college hockey": "ncaah",
    "ncaa d1 hockey": "ncaah",
    "ncaa division 1 hockey": "ncaah",
    "ncaa division i hockey": "ncaah",
    "ncaa d1 mens": "ncaah",
    "ncaa d1 men's": "ncaah",
    "ncaa d1 men": "ncaah",
    "ncaa mens": "ncaah",
    "ncaa men's": "ncaah",
    "ncaa men": "ncaah",
    "d1 mens": "ncaah",
    "d1 men's": "ncaah",
    "d1 mens hockey": "ncaah",
    "d1 men's hockey": "ncaah",
    "ncaa d1 mens hockey": "ncaah",
    "ncaa d1 men's hockey": "ncaah",
}


def normalize_league(value: str | None) -> str | None:
    """Return a real league id, a LEAGUE_GROUPS key, or None."""
    if not value:
        return None
    key = " ".join(str(value).strip().lower().replace("_", " ").replace("-", " ").split())
    key = key.replace("'", "").replace("'", "")
    if key in LEAGUES or key in LEAGUE_GROUPS:
        return key
    hit = CATEGORY_ALIASES.get(key)
    if hit:
        return hit
    # Feed shorthand like "NCAA D1 Mens" / "NCAA Mens" without the word hockey
    if "ncaa" in key or key.startswith("d1 "):
        if any(x in key for x in ("football", "ncaaf", "cfb", "basketball", "soccer", "baseball")):
            return None
        if "women" in key or "womens" in key:
            return None
        if "hockey" in key or "mens" in key or key.endswith(" men") or " men " in key:
            return "ncaah"
    return None


def candidate_leagues(canon: str | None) -> list[str]:
    """Ordered league ids to try for a normalized category."""
    if not canon:
        return []
    if canon in LEAGUE_GROUPS:
        return list(LEAGUE_GROUPS[canon])
    out: list[str] = []
    if canon in LEAGUES:
        out.append(canon)
    for alt in LEAGUE_FALLBACKS.get(canon, []):
        if alt not in out and alt in LEAGUES:
            out.append(alt)
    return out
