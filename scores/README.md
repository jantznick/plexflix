# PlexFlix Scores API

Home-server sidecar that turns Live Sports feed titles into live/final scores for
the **big four** leagues (NHL, NBA, NFL, MLB).

Roku calls this API; this service calls ESPN’s public Site API v2 scoreboards.
Matching is dictionary-based (team cities / nicknames / abbreviations → ESPN
team ids → today’s game), not open-ended fuzzy string similarity.

> Run this on the **home server**, not the laptop. Same idea as Multiview /
> cable EPG enrichment.

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/healthz` | Liveness + cached event counts (no auth) |
| `GET` | `/v1/leagues` | Supported league ids |
| `GET` | `/v1/scoreboard?league=nhl` | Cached normalized slate |
| `GET` | `/v1/match?title=…&league=hockey` | Single title resolve |
| `POST` | `/v1/resolve` | Batch resolve (what Roku should use) |
| `POST` | `/v1/refresh` | Force ESPN pull (`{"league":"nhl"}` optional) |

### Batch resolve (Roku)

```http
POST /v1/resolve
Content-Type: application/json

{
  "items": [
    { "id": "feed-1", "title": "Kraken @ Wings", "league": "HOCKEY" },
    { "id": "feed-2", "title": "Lakers vs Celtics", "league": "NBA" }
  ]
}
```

```json
{
  "ok": true,
  "updated": "2026-10-10T04:00:00Z",
  "matched": 1,
  "total": 2,
  "results": [
    {
      "id": "feed-1",
      "title": "Kraken @ Wings",
      "matched": true,
      "confidence": "high",
      "league": "nhl",
      "eventId": "401…",
      "scoreLine": "SEA 2-1 DET",
      "status": "in",
      "displayStatus": "1st 12:00",
      "home": { "abbreviation": "DET", "score": "1", … },
      "away": { "abbreviation": "SEA", "score": "2", … }
    }
  ]
}
```

Unmatched rows keep `matched: false` and a `reason`
(`unsupported_league`, `need_two_teams`, `teams_not_playing`, …). Roku should
leave those guide cells blank.

Optional auth: set `SCORES_TOKEN` and send `Authorization: Bearer …`,
`X-Scores-Token`, or `?token=`.

## Local venv (dev / unit tests)

```bash
cd scores
python3 -m venv .venv
source .venv/bin/activate
pip install pytest
PYTHONPATH=. pytest -q
PYTHONPATH=. python -m scores   # listens on :8096
```

Smoke against a running process:

```bash
curl -s localhost:8096/healthz | jq .
curl -s 'localhost:8096/v1/match?title=Kraken%20@%20Wings&league=hockey' | jq .
curl -s localhost:8096/v1/resolve \
  -H 'Content-Type: application/json' \
  -d '{"items":[{"id":"1","title":"Kraken @ Wings","league":"HOCKEY"}]}' | jq .
```

## Home server (Docker Compose)

```bash
cd /path/to/repo/scores
docker compose up -d --build
```

Defaults:

| Env | Default | Meaning |
|-----|---------|---------|
| `PORT` | `8096` | Listen port |
| `REFRESH_SECONDS` | `30` | Poll while any big-four game is `in` |
| `IDLE_REFRESH_SECONDS` | `300` | Poll when slate is all pre/post |
| `SCORES_TOKEN` | empty | Optional shared secret |

Point the Roku at `http://<home-server-ip>:8096` (config wiring comes next).

## How matching works

1. Map feed category (`HOCKEY` / `NBA` / …) → `nhl` / `nba` / `nfl` / `mlb`
2. Tokenize the title; look up aliases from `data/teams.json` + hand list in
   `scores/aliases.py` (`EXTRA_ALIASES`)
3. Longer aliases win and consume their span (`New York Rangers` ≠ bare New York)
4. Require two team ids; look up today’s scoreboard pair
5. Ambiguous city-only tokens (`New York`) can resolve if exactly one of those
   teams is on tonight’s slate against an already-known opponent

Add nicknames to `EXTRA_ALIASES` when real feed titles miss.

## Layout

```
scores/
  data/teams.json          # ESPN team seed (abbr/city/name/id)
  scores/
    aliases.py             # dictionary + title scanner
    espn.py                # Site API client + event normalize
    matcher.py             # title → event
    service.py             # cache + background refresh
    server.py              # HTTP API
  tests/
  Dockerfile
  docker-compose.yml
```
