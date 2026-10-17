"""Big-four league ids and how sports-feed category labels map onto them."""

from __future__ import annotations

# ESPN Site API v2 paths
LEAGUES: dict[str, dict[str, str]] = {
    "nhl": {"sport": "hockey", "league": "nhl", "label": "NHL"},
    "nba": {"sport": "basketball", "league": "nba", "label": "NBA"},
    "nfl": {"sport": "football", "league": "nfl", "label": "NFL"},
    "mlb": {"sport": "baseball", "league": "mlb", "label": "MLB"},
}

# Sports-feed category / league strings → canonical league key
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
}


def normalize_league(value: str | None) -> str | None:
    if not value:
        return None
    key = " ".join(str(value).strip().lower().replace("_", " ").replace("-", " ").split())
    if key in LEAGUES:
        return key
    return CATEGORY_ALIASES.get(key)
