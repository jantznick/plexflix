import json
import threading
import urllib.request

from scores.aliases import load_teams_seed
from scores.espn import EspnClient
from scores.server import make_server
from scores.service import ScoreService


class FakeEspn(EspnClient):
    def __init__(self, boards):
        super().__init__(fetch=lambda url: {})
        self.boards = boards

    def fetch_scoreboard(self, league, dates=None):
        return list(self.boards.get(league) or [])


def _free_port():
    import socket

    sock = socket.socket()
    sock.bind(("127.0.0.1", 0))
    port = sock.getsockname()[1]
    sock.close()
    return port


def test_resolve_endpoint_batch():
    by_abbr = {t["abbreviation"]: t for t in load_teams_seed()["nhl"]}
    event = {
        "eventId": "99",
        "league": "nhl",
        "name": "Seattle Kraken at Detroit Red Wings",
        "shortName": "SEA @ DET",
        "state": "in",
        "statusName": "STATUS_IN_PROGRESS",
        "statusDetail": "1st 12:00",
        "shortDetail": "1st 12:00",
        "completed": False,
        "clock": "12:00",
        "period": 1,
        "home": {
            "id": by_abbr["DET"]["id"],
            "abbreviation": "DET",
            "name": "Detroit Red Wings",
            "shortName": "Red Wings",
            "score": "0",
            "homeAway": "home",
        },
        "away": {
            "id": by_abbr["SEA"]["id"],
            "abbreviation": "SEA",
            "name": "Seattle Kraken",
            "shortName": "Kraken",
            "score": "1",
            "homeAway": "away",
        },
        "teamIds": {by_abbr["SEA"]["id"], by_abbr["DET"]["id"]},
        "broadcasts": [],
        "startTime": "2026-10-10T00:00Z",
    }
    service = ScoreService(
        client=FakeEspn({"nhl": [event], "nba": [], "nfl": [], "mlb": []}),
        autostart=False,
    )
    service.refresh_all(force=True)

    port = _free_port()
    server = make_server(
        {
            "host": "127.0.0.1",
            "port": port,
            "token": "",
            "refresh_seconds": 30,
            "idle_refresh_seconds": 300,
        },
        service=service,
    )
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        req = urllib.request.Request(
            f"http://127.0.0.1:{port}/v1/resolve",
            data=json.dumps(
                {
                    "items": [
                        {"id": "a", "title": "Kraken @ Wings", "league": "HOCKEY"},
                        {"id": "b", "title": "Random Racing", "league": "F1"},
                    ]
                }
            ).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            body = json.load(resp)
        assert body["ok"] is True
        assert body["matched"] == 1
        assert body["results"][0]["matched"] is True
        assert body["results"][0]["scoreLine"] == "SEA 1-0 DET"
        assert body["results"][1]["matched"] is False

        with urllib.request.urlopen(f"http://127.0.0.1:{port}/healthz", timeout=5) as resp:
            health = json.load(resp)
        assert health["ok"] is True
        assert health["leagues"]["nhl"]["events"] == 1
    finally:
        server.shutdown()
        service.stop()
