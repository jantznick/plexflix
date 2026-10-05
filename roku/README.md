# PlexFlix for Roku (MVP)

Netflix-style browse + play layer over your local Plex Media Server.

This is intentionally a **design/UX shell** on top of existing Plex data. Credentials are hardcoded for local testing.

## What you get

- Dark Netflix-like home: billboard hero + horizontal shelves
- **Collapsible sidebar** (Left to open): Home, your **Libraries**, **Live TV**, Live Sports
- Selecting a library in the sidebar opens that library’s shelves
- **Live TV**: Guide layout always visible (columns + placeholder rows while syncing); program info top-left, preview top-right
- **Libraries**: mosaic hero + **View all** / **Search**; full grid with filter, search and order-by
- **Continue Watching**, **Recently Added**, Plex hubs, library shelves, **genre rows**, and **Discover** trending (Netflix/Disney+/etc.)
- Home shelves require **15–30** items (except Continue Watching) and **loop** horizontally
- Continue Watching episodes open the parent show with that episode focused
- Title detail screen (Cast + More Like This) with larger hero art
- Cast pages: bio, birthday/place, Movies + TV filmography (TMDB when configured)
- Playback via Plex universal transcoder (HLS)
- Live sports from a configurable JSON feed URL (event detail + stream picker)
- Optional **TMDB** enrichment for cast pages (`tmdbApiKey` in config)

## Configure before sideload

Edit `roku/source/PlexConfig.brs`:

```brightscript
baseUrl: "http://192.168.x.x:32400"
token: "YOUR_PLEX_TOKEN"
sportsFeedUrl: "https://roku-hockey.s3.us-west-004.backblazeb2.com/secretfeedfilename.json"
tmdbApiKey: "YOUR_TMDB_API_KEY"
```

Optional keys:
- `tmdbApiKey` — cast bios / photos / known-for (https://www.themoviedb.org/settings/api)
- Leave as `REPLACE_WITH_TMDB_API_KEY` to skip TMDB (Plex people data still used when available)
`sportsFeedUrl` can point at any JSON feed. Category maps like `{ "FOOTBALL": [ { title, thumbnail, content.videos[].url } ] }` are supported.

Notes:

- Use the Plex server IP reachable from your Roku (usually LAN HTTP on `32400`)
- Token guide: https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/
- Roku and Plex must be on the same network (or otherwise routable)

## Package

From the repo root:

```bash
./roku/package.sh
```

Creates `roku/dist/plexflix-roku.zip` (sideloadable channel package).

## Sideload on Roku

1. On the Roku: **Settings → System → Advanced system settings → Developer options**
2. Enable installer / set a password
3. Note the Roku IP
4. Open `http://<roku-ip>` in a browser
5. Upload `roku/dist/plexflix-roku.zip`
6. Launch **PlexFlix** from the home screen

Optional CLI (if `ROKU_IP` / `ROKU_PASSWORD` are set):

```bash
./roku/package.sh --deploy
```

## Library pages

Picking a library in the sidebar opens its **hub**: a mosaic hero with a single
**View all** button, plus Continue Watching / Recently Added / Plex hub shelves
below. Down drops into the shelves, Up comes back to the button.

**View all** opens the full library grid:

- one scrolling 7-wide × 5-row poster grid, Up from the top row reaches the toolbar
- **Filter** — genre, decade, unwatched only, clear all (the `*` key opens it too)
- **Search** — on-screen keyboard, matches titles inside the library
- **Order by** — title A–Z / Z–A, recently added, year, rating, recently watched
- an **A–Z rail** down the right edge (Right from the last column) jumps straight
  to a letter; letters the library has nothing under are dimmed
- the header shows the active filters on the left and `1,234 of 8,900` on the right

The rail only appears for the default title A–Z order with no filters applied,
because its offsets come from Plex's `firstCharacter` counts for that exact order.

Paging is a sliding window: titles load 60 at a time, four rows ahead of the
focus, and rows that fall far behind are released again. At most ~900 titles are
held in memory no matter how big the library is, so memory stays flat on older
sticks. The window is kept much larger than the screen on purpose — re-anchoring
the grid after a trim is the one moment scrolling can jolt, so it should happen
once every hundred-odd rows rather than every few pages.

## Remote / focus

- **Left** opens the sidebar from Home, Libraries, Live Sports (and sports detail via Back first); **Right** or **Back** hides it
- Libraries appear as flat items in the sidebar (no wrapping cycle at the ends)
- Arrow keys move across poster rows
- Every list, grid and shelf uses `vertFocusAnimationStyle="floatingFocus"`: Up and
  Down move the highlight between the rows already on screen and only scroll once
  it would leave them. Omitting the field gives a pinned highlight that scrolls the
  content on every press, which makes the lower rows unreachable as a highlight
  position and is very jarring.
- Focused title updates the hero billboard
- OK opens the detail screen (episodes open the show with that episode selected)
- Play / OK starts playback
- Back returns to the previous screen
- Loading uses a Netflix-style scrolling poster mosaic on home launch (CDN-refreshable)
- Soft loading banner for in-app fetches — the UI stays navigable

## Daily splash posters (home server)

The channel ships with hardcoded TMDB CDN posters for the scrolling splash. To refresh them from *your* Plex library every day, run this on the home server (not this laptop):

```bash
# once
python3 -m venv ~/plexflix-splash-venv
~/plexflix-splash-venv/bin/pip install b2sdk   # only if using --upload to B2

cp roku/scripts/splash.env.example ~/plexflix-splash.env
# edit tokens / CDN base / B2 keys

# daily (cron)
~/plexflix-splash-venv/bin/python /path/to/repo/roku/scripts/update_splash_posters.py \
  --env-file ~/plexflix-splash.env --upload
```

That writes `posters.json` + `images/poster_XXX.jpg` and uploads them to your CDN.
`splashManifestUrl` in `PlexConfig.brs` already points at:

`https://roku-hockey.s3.us-west-004.backblazeb2.com/plexflix/splash/posters.json`

If the JSON isn’t reachable yet, the hardcoded TMDB fallbacks still animate.

## Fonts

Outfit (Google Fonts / OFL) ships under `roku/fonts/`. Swap TTFs there and update `pkg:/fonts/...` references if you prefer another face.

## Out of scope for this MVP

- Account login / PIN pairing UI
- Global (cross-library) search, profiles, downloads
- Direct Play codec negotiation beyond HLS transcode
- Settings screen (edit `PlexConfig.brs` and republish)

## Project layout

```
roku/
  manifest
  source/main.brs
  source/PlexConfig.brs
  source/Fonts.brs
  components/
  fonts/
  images/
  scripts/update_splash_posters.py
  package.sh
```
