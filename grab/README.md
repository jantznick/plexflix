# PlexFlix Grab

Lightweight home-server sidecar that the Roku channel will call to **search NZBFinder,
Force-download via NZBGet, and refresh Plex** — without waiting on Radarr for the
title you want *right now*.

Same spirit as `multiview/`: stdlib Python, tiny HTTP API, env-configured, own
Docker Compose service you can drop into your homelab stack.

## API

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/jobs` | Start a grab |
| `GET` | `/jobs/<id>` | Progress (poll every 2–3s from the detail page) |
| `GET` | `/jobs?guid=&tmdbId=&imdbId=` | Resume an in-flight / ready job |
| `GET` | `/healthz` | Health check |

Optional auth: set `GRAB_TOKEN` and send header `X-Grab-Token: <token>`.

### Start a movie

```bash
curl -s -X POST http://127.0.0.1:8096/jobs \
  -H 'Content-Type: application/json' \
  -d '{"mediaType":"movie","title":"Example","year":"2020","tmdbId":"123","imdbId":"tt0000001","guid":"plex://movie/..."}'
```

### Status shape

```json
{
  "id": "...",
  "status": "searching|downloading|unpacking|scanning|ready|failed",
  "stage": "...",
  "percent": 37,
  "etaSeconds": 120,
  "message": "Downloading (Force priority)",
  "releaseTitle": "Example.2020.1080p.WEB-DL.x264",
  "nzbgetId": 42,
  "ok": true
}
```

### Episode (immediate grab only for now)

```json
{
  "mediaType": "episode",
  "title": "Some Show",
  "tmdbId": "456",
  "season": 1,
  "episode": 1
}
```

Sonarr “queue next N” / Start fresh wiring is intentionally not in v1.

## Behaviour

1. Search NZBFinder (IMDB/TMDB preferred).
2. Keep releases that look like **1080p** and are **≤ 5 GiB** (env-tunable); skip REMUX.
3. Push the NZB to NZBGet with **priority 900 (Force)** and **AddToTop=true** so it
   jumps anything else in the queue and downloads even if NZBGet is paused.
4. Poll NZBGet groups/history for %.
5. On success, refresh the configured Plex library section.

## Configure

Copy the env block from `docker-compose.yml`. The important ones:

| Variable | Meaning |
|----------|---------|
| `NZBFINDER_URL` / `NZBFINDER_API_KEY` | Indexer |
| `NZBGET_URL` / `NZBGET_USERNAME` / `NZBGET_PASSWORD` | As seen **from this container** |
| `NZBGET_PRIORITY` | Default `900` (Force) |
| `NZBGET_CATEGORY_MOVIE` / `_TV` | Categories whose DestDir lands in your Plex libraries |
| `MAX_SIZE_BYTES` | Default `5368709120` (5 GiB) |
| `PLEX_URL` / `PLEX_TOKEN` / `PLEX_MOVIE_SECTION_ID` | Scan trigger |
| `GRAB_TOKEN` | Optional shared secret for the Roku |

**Do not use `localhost` for NZBGet/Plex from inside Docker** unless they share
host networking. Prefer the compose service name (`http://nzbget:6789`) on a
shared network, or the host LAN IP.

## Run on the home server

From the repo root (or merge this service into your existing stack):

```bash
cd grab
# fill env in docker-compose.yml or an .env file
docker compose up -d --build
```

Roku will eventually call the **host LAN IP** on port `8096` (same pattern as
`multiviewUrl`), never `localhost`.

## Dev / tests

```bash
cd grab
python3 -m unittest discover -s tests -v
python3 -m grab.server   # after exporting the env vars
```

## Out of scope (v1)

- Roku UI wiring (`grabUrl` in `PlexConfig.brs`)
- Sonarr queue-next / Start fresh
- Automatic Filebot-style renaming (rely on NZBGet category DestDir + your
  existing post-processing for now)
