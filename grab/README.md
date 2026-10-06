# PlexFlix Grab

Lightweight home-server sidecar that the Roku channel will call to **search NZBFinder,
Force-download via NZBGet, and refresh Plex** — without waiting on Radarr for the
title you want *right now*.

Same spirit as `multiview/`: stdlib Python, tiny HTTP API, env-configured, own
Docker Compose service you can drop into your homelab stack.

**v1 focus:** get a **movie**, or get a **specific TV episode** (including S01E01).
Sonarr “Start fresh → queue E02–E05” comes later.

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
curl -s -X POST http://192.168.1.50:8096/jobs \
  -H 'Content-Type: application/json' \
  -d '{"mediaType":"movie","title":"Example","year":"2020","tmdbId":"123","imdbId":"tt0000001","guid":"plex://movie/..."}'
```

### Start a specific episode (or S01E01)

```bash
curl -s -X POST http://192.168.1.50:8096/jobs \
  -H 'Content-Type: application/json' \
  -d '{"mediaType":"episode","title":"Some Show","tmdbId":"456","season":1,"episode":1}'
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

## Behaviour

1. Search NZBFinder (IMDB/TMDB preferred).
2. Keep releases that look like **1080p** and are **≤ 5 GiB** (env-tunable); skip REMUX.
3. Push the NZB to NZBGet with **priority 900 (Force)** and **AddToTop=true** so it
   jumps anything else in the queue and downloads even if NZBGet is paused.
4. Poll NZBGet groups/history for %.
5. On success, refresh the configured Plex library section.

## Homelab networking

- Roku is its own IP; **Plex + all Docker containers share one host LAN IP**.
- Configure grab with that LAN IP for NZBGet / Plex / (later) Sonarr — **not**
  `localhost`, **not** docker service DNS names.
- Roku will call `http://<host-lan-ip>:8096` (same idea as `multiviewUrl`).
- Port **8096** is intentional so it stays off the busy 7878/8989/8080/3000 range.

## Configure

1. Copy `.env.example` → `.env` (or edit `docker-compose.yml` env block).
2. Fill the values below.

| Variable | Meaning |
|----------|---------|
| `NZBFINDER_URL` / `NZBFINDER_API_KEY` | `https://nzbfinder.ws` + your API key |
| `NZBGET_URL` | `http://<host-lan-ip>:6789` |
| `NZBGET_USERNAME` / `NZBGET_PASSWORD` | NZBGet **Control** user/pass (web GUI login) |
| `NZBGET_PRIORITY` | Default `900` (Force) |
| `NZBGET_CATEGORY_MOVIE` / `_TV` | See categories below |
| `PLEX_URL` / `PLEX_TOKEN` / section IDs | Scan trigger after download |
| `GRAB_TOKEN` | Optional shared secret for the Roku |

### NZBGet username / password

The JSON-RPC API uses the same **ControlUsername / ControlPassword** as the web UI.

1. Open NZBGet in the browser (`http://<host-lan-ip>:6789`).
2. Log in with the credentials you already use.
3. **Settings → Security** (wording varies slightly by NZBGet version):
   - Note **ControlUsername** and **ControlPassword**
   - Those go into `NZBGET_USERNAME` / `NZBGET_PASSWORD`
4. Smoke-test from any machine on the LAN:

```bash
curl -s -u 'USER:PASS' \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"version","params":[]}' \
  http://192.168.1.50:6789/jsonrpc
```

You should get a JSON result with the NZBGet version. If that works, grab can auth.

### NZBGet categories (recommended)

You already have **Movies** and **Series** for Radarr/Sonarr. For PlexFlix Force
grabs, create two more categories that unpack into the **same DestDir** as those:

| Category | DestDir | Why |
|----------|---------|-----|
| `PlexFlix-Movies` | same as `Movies` | Same Plex path; visible as a Force grab in NZBGet |
| `PlexFlix-Series` | same as `Series` | Same for TV episodes |

In NZBGet: **Settings → Categories → Add**, copy DestDir/unpack settings from
Movies/Series, name them as above.

If you’d rather not add categories yet, set:

```env
NZBGET_CATEGORY_MOVIE=Movies
NZBGET_CATEGORY_TV=Series
```

### Plex section IDs

With your Plex token (same one as the Roku channel is fine):

```bash
curl -s "http://192.168.1.50:32400/library/sections?X-Plex-Token=YOUR_TOKEN" \
  | grep -E 'key=|title='
```

Each `<Directory …>` has a `key` (the section id) and `title` (library name).
Put the movie library’s `key` in `PLEX_MOVIE_SECTION_ID` and the TV library’s in
`PLEX_TV_SECTION_ID`.

## Run on the home server

```bash
cd grab
cp .env.example .env   # then edit
docker compose up -d --build
curl -s http://192.168.1.50:8096/healthz
```

Compose reads `.env` for variable substitution when you reference them; this
compose file currently inlines env under `environment:` — either paste values
there or change entries to `${NZBGET_URL}` style once you prefer `.env`-driven
deploys.

## Dev / tests

```bash
cd grab
PYTHONPATH=. python3 -m unittest discover -s tests -v
python3 -m grab.server   # after exporting the env vars
```

## Out of scope (v1 backend)

- Sonarr Start fresh → queue E02–E05 (and “grab all episodes” signal from Roku)
- Automatic Filebot-style renaming (rely on NZBGet category DestDir + your
  existing post-processing for now)
- Custom episode picker UI (shows currently Grab → S01E01)

## Planned Roku UX

On unavailable Discover titles:

| Button | Role |
|--------|------|
| **Grab Now** | `POST /jobs` → poll progress on softStatus → flip toward Play when `ready` |
| **Add to Watchlist** | Existing Plex Discover watchlist (save for later, no download) |
| **Back** | Unchanged |

### Fail-open (required)

Grab Now must never break the channel:

- Empty `grabUrl` → button hidden; page behaves as before (Watchlist + Back only)
- Unreachable / timed-out / bad server → soft status message only; Watchlist and Back keep working
- Polling stops after a few consecutive failures so a dead server cannot spin forever
- Detail load never waits on grab health

Watchlist stays the slow/passive path; Grab Now is the fast path. For TV,
Grab Now can later open a small choice (this episode / start at S01E01) without
removing watchlist. v1 Grab Now on a show starts at **S01E01**.
