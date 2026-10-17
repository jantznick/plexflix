from scores.aliases import (
    build_alias_index,
    find_teams_in_title,
    load_teams_seed,
    normalize_text,
)


def test_normalize_text_strips_punctuation():
    assert normalize_text("Kraken @ Red-Wings!") == "kraken red wings"


def test_alias_index_includes_abbreviations_and_extras():
    index = build_alias_index(load_teams_seed())
    nhl = index["nhl"]
    # SEA from catalog abbr
    sea_ids = nhl["sea"]
    assert len(sea_ids) == 1
    # hand alias
    assert nhl["kraken"] == sea_ids
    assert nhl["wings"] == nhl["det"]


def test_find_teams_prefers_longer_alias():
    index = build_alias_index(load_teams_seed())
    found = find_teams_in_title("New York Rangers at Boston Bruins", "nhl", alias_index=index)
    assert len(found["team_ids"]) == 2
    # Should not treat bare "New York" as a second NY team
    teams = load_teams_seed()["nhl"]
    by_id = {t["id"]: t for t in teams}
    abbrs = {by_id[tid]["abbreviation"] for tid in found["team_ids"]}
    assert abbrs == {"NYR", "BOS"}


def test_nba_sixers_alias():
    index = build_alias_index(load_teams_seed())
    found = find_teams_in_title("Celtics vs Sixers", "nba", alias_index=index)
    teams = {t["id"]: t for t in load_teams_seed()["nba"]}
    abbrs = {teams[tid]["abbreviation"] for tid in found["team_ids"]}
    assert abbrs == {"BOS", "PHI"}
