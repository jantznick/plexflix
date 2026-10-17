# Repos & services map

How **plexflix** and **roku-feed** fit together today: what lives where, which ports matter, and what is duplicated on purpose.

This is the living-room stack as deployed at home — not the future stick-OS notes under [`streaming-os/`](./streaming-os/).

---

## Two repos, two jobs

| Repo | Job |
|------|-----|
| **[jantznick/roku-feed](https://github.com/jantznick/roku-feed)** | Get live sports / cable streams onto the LAN: scrape providers → JSON feed (often B2) → **HLS proxy** (`:8787`) so players can open those URLs. Also hosts older / alternate clients (sports Roku app, Expo, web viewer). |
| **[jantznick/plexflix](https://github.com/jantznick/plexflix)** | The living-room product: main **Roku channel** (Plex + Live TV + Sports + Multiview) plus home-server sidecars (**multiview**, **scores**, **grab**). |

They help each other: the sports feed’s stream URLs often point at `http://<LAN>:8787/proxy/…`. The plexflix channel plays those URLs. Multiview vendors a **copy** of the same proxy for in-container use (`:18787`) so the mosaic can resolve embeds without depending on the LAN proxy the same way.

Keeping that vendored copy in sync with roku-feed is **hygiene**, not what makes single-stream play work. Single-stream play needs the **running** roku-feed proxy on `:8787` plus the plexflix channel build.

---

## What lives where

| Thing | Repo | Path / port | Job |
|--------|------|-------------|-----|
| Main Roku channel | plexflix | `roku/` | Plex Netflix-style UI + Live TV + Live Sports + Multiview |
| Old sports-only Roku app | roku-feed | `roku-app/` | Earlier feed-focused channel |
| HLS proxy (live service) | roku-feed | `proxy/` → **`:8787`** | Single-stream passthrough + `/remux/` (HE-AAC → AAC-LC) |
| Vendored proxy copy | plexflix | `multiview/proxy/`, `multiview/src/` → **`:18787`** (in-container only) | Same proxy code inside the multiview container |
| Proxy sync patches | plexflix | `multiview/patches/*.patch` | Apply onto roku-feed when the live proxy needs a fix first |
| Multiview mosaic | plexflix | `multiview/` → **`:8095`** | 2–4 feeds → ffmpeg mosaic → one HLS for the Roku |
| Scores sidecar | plexflix | `scores/` → **`:8096`** | ESPN (etc.) scoreboards for the sports guide |
| Grab sidecar | plexflix | `grab/` → **`:8097`** | NZBFinder → NZBGet → Plex refresh (“Grab Now”) |
| Web sports/cable viewer | roku-feed | `web/` → host **`:8080`** (typical) | Browser player for the feed |
| Expo / React Native app | roku-feed | `react-native-app/` | Phone client for the feed |
| Scrapers / feed build | roku-feed | `src/` | Matchora, TimStreams, Streamed, onhockey, … → feed JSON |
| Account / configurable feeds (WIP) | roku-feed | `backend/`, `frontend/` | Auth, pairing, configurable feeds |
| Older React Plex web UI | plexflix | `app/` (+ root webpack) | Browser Plex shelves — not the Roku channel |
| Stick-OS product notes | plexflix | `docs/streaming-os/` | Future hardware/OS thinking — not this runtime |

External (not in these repos, but wired in):

- **Plex PMS** `:32400` — libraries, hubs, Live TV/DVR, Discover  
- **NZBGet / Sonarr** — used by grab  
- **TMDB** — cast / art enrichment in the channel  
- **B2 (or similar)** — hosted sports feed JSON, cable EPG, splash posters  

---

## How playback paths work

### Single stream (one game / cable channel on the Roku)

```text
roku-feed scraper → feed JSON (URLs often http://LAN:8787/proxy/…)
       → plexflix Roku VideoScreen plays /proxy/…
       → on “Unsupported AAC stream”, channel retries /remux/ on same host
       → proxy ffmpeg: copy video, AAC-LC audio → short live HLS
```

### Multiview (2–4 tiles)

```text
plexflix channel → POST/GET multiview :8095
       → server pulls each feed via vendored proxy :18787
       → ffmpeg mosaic (already AAC-LC) → session HLS on :8095
       → channel plays one master.m3u8 (audio follows focused tile)
```

### Web viewer

```text
roku-feed web/ → same feed → often same :8787 proxy
```

---

## Ports (home deploy)

| Port | Service |
|------|---------|
| **32400** | Plex Media Server |
| **8787** | roku-feed HLS proxy (what Roku single-stream and the web viewer hit) |
| **18787** | Same proxy **inside** the plexflix multiview container only (not for the Roku) |
| **8095** | Multiview API + mosaic HLS |
| **8096** | Scores |
| **8097** | Grab |
| **8080** | roku-feed web viewer (host publish; see that repo’s compose) |

Channel endpoints are wired from `roku/source/PlexConfig.brs` (`baseUrl`, `sportsFeedUrl`, `multiviewUrl`, `scoresUrl`, `grabUrl`, …). The `:8787` host is usually **inside the feed URLs**, not a separate PlexConfig field.

---

## Why the trees drift

The same proxy exists in **two places**:

1. **roku-feed `proxy/`** — the process you rebuild on the server for `:8787`  
2. **plexflix `multiview/proxy/` (+ `src/`)** — vendored for the multiview image  

Fixes often land as a patch under `multiview/patches/`, get applied/merged on roku-feed, then the vendored copy is updated in plexflix so multiview’s internal proxy does not rot.

Same “watch sports” idea also exists as **four clients**: plexflix Roku, roku-feed `roku-app`, Expo, roku-feed web.

---

## Future: Plex content inside multiview

Today multiview tiles are **HTTP(S) HLS URLs** (sports/cable via `:8787` / vendored `:18787`). Plex Live TV and library media are different:

| Source | What ffmpeg needs | Extra work |
|--------|-------------------|------------|
| **Plex Live TV** | HLS from a **tune** (`/livetv/…` or playback decision) with `X-Plex-*` headers / token | Channel (or multiview server) must **tune** before the tile is live; pass URL **plus headers** into the session; keep the Plex playback session alive while the mosaic runs; tear down on pause/promote/delete. Multiview’s stream spec is currently `{url, title}` only — needs optional `headers` (API already mentions them in places; mosaic/relay must forward them on every ffmpeg/proxy fetch). |
| **Plex library (VOD)** | Transcode or direct HLS/file URL for a `ratingKey` | Same header/session story; VOD is not “live” — decide behavior (loop? slate when finished? start at `viewOffset`?). ffmpeg already has `-live_start_index` for live feeds; VOD would use normal `-ss` / playhead or just start at 0. |
| **Mixed mosaic** (2 sports + 1 Plex channel) | Both of the above in one filtergraph | Session create accepts mixed specs; UI pickers on Live TV / library “Add to multiview”; promote-to-fullscreen must route Plex tiles back through **Plex** play (not sports `playDirect`). |

### Rough lift (not a schedule — scope only)

1. **Small / medium — Plex Live TV tiles only**  
   - Extend multiview stream objects: `{ url, title, headers?, kind: "plex-live"|"sports" }`.  
   - Server: on create/update, call Plex tune (or accept a pre-tuned URL from the channel), thread headers into ffmpeg inputs (today `-i url` has no header support — need `-headers` / proxy that injects them).  
   - Channel: Live TV guide “add to multiview” + promote path that uses existing `tuneLiveChannel` / VideoScreen Plex path.  
   - Careful: Plex sessions expire; mosaic pause/promote must stop/release tunes like sports pause frees `:8787`.

2. **Larger — library movies/episodes as tiles**  
   - Everything in (1), plus `buildStreamUrl` / decision API per item, poster/title from metadata, and a clear UX (why put a movie in a 4-tile sports mosaic?).  
   - Probably lower priority unless you want “game + baby monitor cam + security HLS” style dashboards.

3. **Already friendly**  
   - Mosaic ffmpeg already joins live inputs near the tip (`-live_start_index -3`).  
   - Relay can warm non-Plex proxy URLs; Plex would skip roku-feed proxy and hit PMS directly (or a tiny header-injecting proxy).

Bottleneck is **session + headers + UI**, not the compositor math.

---

## Combining later (target shape)

When collapsing into one deployable system, a natural layout is a single repo (or monorepo) with one of each:

```text
channel/          # today’s plexflix/roku
proxy/            # one HLS proxy (today’s roku-feed/proxy)
scraper/          # feed builders (today’s roku-feed/src)
multiview/
scores/
grab/
web/              # feed viewer
mobile/           # Expo, if kept
```

Rule of thumb: **one proxy service**, not a LAN copy and a second forgotten vendored copy.

---

## Day-to-day: what actually matters

| Goal | What to touch |
|------|----------------|
| Single-stream broken / HE-AAC | roku-feed `:8787` (+ channel remux retry in plexflix `roku/`) |
| Multiview mosaic | plexflix `multiview/` (`:8095`); rebuild that image if the **vendored** proxy must match |
| Sports guide scores | plexflix `scores/` (`:8096`) |
| Grab missing titles | plexflix `grab/` (`:8097`) |
| Feed contents / new providers | roku-feed scrapers + feed publish |
| Browser check of a feed URL | roku-feed `web/` |

Vendored-proxy PRs on plexflix without a roku-feed deploy do **not** change what the Roku hits on `:8787`.
