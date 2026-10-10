from scores.aliases import load_teams_seed
from scores.matcher import resolve_title


def _event(league, eid, away_id, away_abbr, away_score, home_id, home_abbr, home_score, state="in"):
    return {
        "eventId": eid,
        "league": league,
        "name": f"{away_abbr} at {home_abbr}",
        "shortName": f"{away_abbr} @ {home_abbr}",
        "state": state,
        "statusName": "STATUS_IN_PROGRESS" if state == "in" else "STATUS_FINAL",
        "statusDetail": "Q3 4:12" if state == "in" else "Final",
        "shortDetail": "Q3 4:12" if state == "in" else "Final",
        "completed": state == "post",
        "clock": "4:12" if state == "in" else "0:00",
        "period": 3,
        "home": {
            "id": home_id,
            "abbreviation": home_abbr,
            "name": home_abbr,
            "shortName": home_abbr,
            "score": home_score,
            "homeAway": "home",
        },
        "away": {
            "id": away_id,
            "abbreviation": away_abbr,
            "name": away_abbr,
            "shortName": away_abbr,
            "score": away_score,
            "homeAway": "away",
        },
        "teamIds": {away_id, home_id},
        "broadcasts": ["ESPN"],
        "startTime": "2026-10-10T00:00Z",
    }


def test_resolve_kraken_wings_high_confidence():
    by_abbr = {t["abbreviation"]: t for t in load_teams_seed()["nhl"]}
    events = {
        "nhl": [
            _event(
                "nhl",
                "401",
                by_abbr["SEA"]["id"],
                "SEA",
                "2",
                by_abbr["DET"]["id"],
                "DET",
                "1",
                state="in",
            )
        ]
    }
    result = resolve_title("Seattle Kraken @ Detroit Red Wings", "HOCKEY", events)
    assert result["matched"] is True
    assert result["confidence"] == "high"
    assert result["scoreLine"] == "SEA 2-1 DET"
    assert result["displayStatus"] == "Q3 4:12"
    assert result["eventId"] == "401"


def test_resolve_unsupported_league():
    result = resolve_title("Team A vs Team B", "UFC", {"nhl": []})
    assert result["matched"] is False
    assert result["reason"] == "unsupported_league"


def test_resolve_need_two_teams():
    by_abbr = {t["abbreviation"]: t for t in load_teams_seed()["nhl"]}
    events = {
        "nhl": [
            _event(
                "nhl",
                "401",
                by_abbr["SEA"]["id"],
                "SEA",
                "2",
                by_abbr["DET"]["id"],
                "DET",
                "1",
            )
        ]
    }
    result = resolve_title("Kraken highlights", "nhl", events)
    assert result["matched"] is False
    assert result["reason"] == "need_two_teams"


def test_resolve_teams_not_on_slate():
    by_abbr = {t["abbreviation"]: t for t in load_teams_seed()["nhl"]}
    events = {
        "nhl": [
            _event(
                "nhl",
                "401",
                by_abbr["SEA"]["id"],
                "SEA",
                "2",
                by_abbr["DET"]["id"],
                "DET",
                "1",
            )
        ]
    }
    result = resolve_title("Bruins vs Maple Leafs", "nhl", events)
    assert result["matched"] is False
    assert result["reason"] == "teams_not_playing"


def test_disambiguate_new_york_using_slate():
    by_abbr = {t["abbreviation"]: t for t in load_teams_seed()["nhl"]}
    events = {
        "nhl": [
            _event(
                "nhl",
                "777",
                by_abbr["NYR"]["id"],
                "NYR",
                "3",
                by_abbr["BOS"]["id"],
                "BOS",
                "2",
            )
        ]
    }
    result = resolve_title("New York at Boston", "nhl", events)
    assert result["matched"] is True
    assert result["eventId"] == "777"
