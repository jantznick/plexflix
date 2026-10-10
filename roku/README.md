# PlexFlix for Roku (MVP)

Netflix-style browse + play layer over your local Plex Media Server.

This is intentionally a **design/UX shell** on top of existing Plex data. Credentials are hardcoded for local testing.

**New to Roku / coming from React or Node?** Start with [LEARNING.md](./LEARNING.md) — a guided tour of SceneGraph vs BrightScript and a file-by-file learning path through this channel.

## What you get

- Dark Netflix-like home: billboard hero + horizontal shelves
- **Profiles splash** at launch: pick **Kids** or **Adults**. Kids unlocks
  with no passcode and only sees matching libraries (title contains kid /
  family / disney / nick / …), cartoon + basic broadcast Cable nets (no Plex
  Live TV / DVR, no Live Sports, no Discover). Adults use passcode `1990` for
  the full channel. Sidebar includes **Switch Profile** to return to the picker
- **Collapsible sidebar** (Left to open): Home, **Search**, your **Libraries**,
  **TV** (Plex Live TV + Cable nets), Live Sports (Adults).
  Collapsed, a 72px icon rail stays on browse screens with the current section
  lit; it is hidden on detail pages, in the player and over the launch splash
- **Search**: Plex Discover catalog search for any movie/show (not just what’s
  already in your libraries), with Movies / TV filters; open a result and
  **Add to Watchlist** / **Remove** from the detail page
- **Home stays loaded**: switching sections parks it instead of discarding it,
  so returning is instant and the hubs refresh in the background (also after
  playback), updating only the rows whose items changed
- Selecting a library in the sidebar opens that library’s shelves
- **TV**: one guide like a cable box — Plex Live TV plus Entertainment/Cartoons, sorted by channel number
  (locals first via Plex VCNs, then basic cable ~70–300, kids, sports, premiums 500+ from `cable_lineup.json`).
  Cable rows are tagged **CABLE**. Record / Upcoming / Rules stay Plex-only; on Cable, `*` shows
  **Recording not available** plus **Refresh guide**. OK watches (Plex DVR tune vs Cable direct stream).
- **DVR**: Upcoming lists scheduled recordings (OK cancels one). Rules lists each show with a rule; OK opens an editor for
  its Plex recording settings (quality, replace lower quality, padding, commercial detection, episodes to keep, …;
  OK on a setting opens its choices to pick from), plus Save and Delete. "Edit series rule" is also on the guide and Upcoming menus.
  Programs that will record are tagged **REC** (or **SERIES**) in the grid. Finished recordings land in the Plex
  library the rule targets, like any other episode or movie
- **Libraries**: mosaic hero + **View all**; full grid with filter, search, order-by and an A–Z rail
- **Continue Watching**, **Recently Added**, Plex hubs, library shelves, **genre rows**, and **Discover** trending (Netflix/Disney+/etc.)
- Home **infinite-scrolls** like the web app: as you move down, it appends more random Discover shelves (popular genres per service + trending / exclusives / recently released / popular / watchlist)
- Home shelves require **15–30** items (except Continue Watching) and **loop** horizontally
- Continue Watching episodes open the parent show with that episode focused
- Title detail screen (Cast + More Like This) with larger hero art
- **Random** on TV show detail picks a random episode (hidden for movies)
- Cast pages: bio, birthday/place, Movies + TV filmography (TMDB when configured)
- **Watched state from Plex**: a tick on finished titles, a remaining-episode count
  on part-watched shows, and a resume bar on anything started
- Playback via Plex universal transcoder (HLS) with a **custom player overlay**
  (scrubber, elapsed / remaining, finish time, audio + subtitle + version pickers)
- **Skip intro / credits** from Plex's own markers, **BIF scrubbing previews**,
  and an **inline cast panel** that pauses rather than leaving playback
- **Progress is written back to Plex**, so resume points and Continue Watching
  stay in sync with every other Plex client
- Live sports from a configurable JSON feed URL. OK on a game with **one** feed plays
  it immediately; **multiple** feeds open the stream picker. `*` opens options: **Refresh feed**,
  Multiview add/remove (when enabled), and Watch Multiview
- **TV player**: Live TV programs can enrich from **TMDB** while tuning when `tmdbApiKey` is set; Cable rows use
  sidecar cast when present (TMDB fallback otherwise)
- **Multiview**: 2–4 live games at once in Grid, Spotlight or Picture in picture,
  tiled on your home server (see [Multiview](#multiview))
- Optional **TMDB** enrichment for cast pages and Discover titles missing from your library (`tmdbApiKey` in config)
- Discover titles not in Plex open a **Not in your library** detail view (no Play) with synopsis, similar local picks, and Watchlist actions

## Configure before sideload

Edit `roku/source/PlexConfig.brs`:

```brightscript
baseUrl: "http://192.168.x.x:32400"
token: "YOUR_PLEX_TOKEN"
sportsFeedUrl: "https://roku-hockey.s3.us-west-004.backblazeb2.com/secretfeedfilename.json"
cableEpgUrl: "https://roku-hockey.s3.us-west-004.backblazeb2.com/plexflix/cable-epg.json"
tmdbApiKey: "YOUR_TMDB_API_KEY"
multiviewUrl: "http://192.168.x.x:8095"   ' optional, see Multiview
```

Optional keys:
- `tmdbApiKey` — cast bios / photos / known-for, plus synopsis art for Discover titles not in your library (https://www.themoviedb.org/settings/api)
- Leave as `REPLACE_WITH_TMDB_API_KEY` to skip TMDB (Plex people data still used when available)
`sportsFeedUrl` can point at any JSON feed. Category maps like `{ "FOOTBALL": [ { title, thumbnail, content.videos[].url } ] }` are supported.

### Cable listings in the TV guide (EPG)

Entertainment / Cartoons appear in the unified **TV** guide with cable-style channel numbers (`roku/source/cable_lineup.json`). Listings live in a **sidecar** JSON (`cable-epg.json`) so your 5-minute sports feed publish never wipes them. Full setup is under [Cable TV EPG sidecar](#cable-tv-epg-sidecar-home-server) below.

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

## Discover Search & Watchlist

Sidebar **Search** hits Plex Discover (`discover.provider.plex.tv/library/search`),
so results include titles that are not in your local libraries. Pick a result to
open the detail page.

On any Discover title that is not in your library, the detail page offers
**Add to Watchlist** / **Remove Watchlist** (`/actions/addToWatchlist` and
`removeFromWatchlist`) — the same personal Watchlist as the official Plex apps.
If the same `plex://` GUID is already on your server, detail promotes to a
normal Play page instead.

Uses the same `token` from `PlexConfig.brs` as the rest of Discover.

## Library pages

Picking a library in the sidebar opens its **hub**: a mosaic hero with a single
**View all** button, plus Continue Watching / Recently Added / Plex hub shelves
below. Down drops into the shelves, Up comes back to the button.

**View all** opens the full library grid:

- one scrolling 7-wide × 4-row poster grid, Up from the top row reaches the toolbar
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

## Watched state

Everything comes from fields Plex already returns on the metadata the app
fetches, so there are no extra requests:

- `viewOffset` draws the resume bar across the bottom of a tile
- `viewCount` on a movie or episode draws the corner tick
- `viewedLeafCount` vs `leafCount` on a show or season gives the amber
  remaining-episode count, and the `7 of 10 watched` line on the detail header
- **Play** reads **Resume** whenever there is something to pick up

A movie that is both watched and part-way through a rewatch counts as in
progress, not watched, which matches what Plex's own clients show.

Which episode you land on comes from the server, via
`/library/metadata/{key}?includeOnDeck=1`. That is the only reliable answer:
scanning for a part-watched episode replays episode 1 once you have finished a
run of them cleanly. Opening a show you have started focuses that episode in
the season row; a show you have never touched still opens on Play.

## Playing content

The Video node runs with `enableUI="false"` and `focusable="false"`, so the whole
playback surface is ours, Roku's trick-play bar never appears, and remote keys
stay on the player screen (Video otherwise steals focus once a stream starts and
swallows the remote).

- **Down**, **OK** or **Pause** raises the panel; it stays up while paused and
  auto-hides after five seconds of silence while playing
- the panel shows elapsed, remaining, and **the clock time the title ends at**,
  formatted against the TV's own 12h/24h setting (`roDeviceInfo.GetClockFormat`)
- **Down** again moves to the button row: Pause, Restart, and Audio / Subtitles /
  Version whenever the file offers more than one
- **Left / Right** on the scrubber seeks 10s, the transport keys seek 30s; a run
  of presses commits a single seek once it settles
- **Up** from the scrubber reaches the **cast strip** above the title
- while buffering, the player shows the buffer fill as **Buffering 42%** with a
  bar, read from `Video.bufferingStatus` (the number Roku's stock UI shows)

A live sports stream that errors, ends before playing, or makes no buffer
progress for 30 seconds closes the player and returns to the game page. The
stream you tried stays highlighted, and the page says why it failed so you can
pick another.

Switching audio, subtitles or version writes the choice to Plex
(`PUT /library/parts/{id}`) and restarts the transcode at the current position,
which costs a short buffer. The player stays open and keeps your place. The
buttons only appear when there is a choice to make, so a file with one audio
track and no subtitles shows just Pause and Restart.

### Skip intro / credits

`?includeMarkers=1` returns the `intro`, `credits` and `commercial` ranges Plex
generates. Inside one of those ranges a pill appears bottom-right and **OK**
takes it, with no need to raise the panel first; the same action leads the button
row when the panel is up. The offer is withdrawn in the last second of a range,
where the skip would be a no-op.

### Scrubbing previews

When the server has built a BIF index for a file (`Part` reports
`indexes="sd"`), frames come from
`/library/parts/{partId}/indexes/sd/{offsetMs}` and a thumbnail follows the
playhead while seeking. Requests are bucketed to five seconds so holding a
direction key does not fire one per press. The title and the cast strip hide
while it is up, because it covers both.

### Cast without leaving playback

**OK** on a cast member pauses the video and opens an inline panel with the
actor's photo, role, bio and known-for credits — the same `personDetail` lookup
the cast page uses, Plex's `/library/people` plus optional TMDB enrichment.
Closing it resumes playback, but only if the pause was ours: a video the viewer
had already paused stays paused. Going to the full cast page instead would mean
tearing down the transcode, so it stays inline.

Progress goes back to the server on every state change and every ten seconds via
`/:/timeline`, and `/:/scrobble` marks a title played when it finishes. Those
calls are issued from `MainScene`, not the player: the last of them fire while
`VideoScreen` is being removed from the tree, and a Task owned by a node that is
going away can be collected before it finishes.

Each playback names its own transcode session so the server side is torn down on
exit instead of being left running.

## Multiview

A Roku decodes one video at a time, so the tiling happens on the home server:
`multiview/` (repo root) combines 2–4 sports feeds into a single 1080p HLS
stream, and the channel plays that stream. Each game keeps its own audio
track, and the channel draws the focus ring, labels and status on top using
the tile rectangles the server reports.

On the server, every feed is decoded by its own ffmpeg into raw 720p frames,
and a GStreamer pipeline tiles whatever frames it has, encodes, and writes
the HLS output. The feeds are fetched the way roku-feed's proxy fetches them
(same referer, cookies and headers, straight from the CDN, PNG-wrapped GOAT
segments unwrapped), not through it: the proxy is only asked for manifests
that need its Chromium session (`d=0` payloads) and for anything a direct
fetch fails on. `GET /healthz` counts how fetches went, so you can see how
much still lands on the proxy.

### Server (home server, Docker Compose)

```bash
cd multiview
# pick ENCODER (x264 / va / qsv / nvenc) and uncomment the matching GPU block
# in docker-compose.yml first
docker compose up -d --build
docker compose logs -f
curl http://localhost:8095/healthz
```

Then set `multiviewUrl` in `PlexConfig.brs` to `http://<server-ip>:8095` and
republish. Leaving it empty hides multiview entirely.

`x264` works anywhere but costs about a core at 1080p30; with an Intel or AMD
GPU (`va`, or `qsv` on Intel, with `/dev/dri` passed through) or NVIDIA
(`nvenc`) encoding is nearly free. A hardware encoder that isn't usable falls
back to x264, and the log says so at startup. Each feed pulls the rendition
closest to 720p from its master playlist (`VARIANT_HEIGHT`), and nothing else.

To try it on a Mac first, without Docker:

```bash
brew install ffmpeg gstreamer pygobject3
cd multiview
ENCODER=vt "$(brew --prefix)/bin/python3" -m multiview.server
```

`vt` is the Mac's built-in hardware encoder (VideoToolbox). Use Homebrew's
`python3`, since that's the one `pygobject3` is installed for. Segments go to
the system temp directory. Point `multiviewUrl` at the Mac's IP
(`ipconfig getifaddr en0`), or play
`http://localhost:8095/sessions/<id>/master.m3u8` in Safari.

Tests run without Docker or network (they need `ffmpeg`, GStreamer and
`python3-gi`; on Ubuntu `apt install ffmpeg python3-gi gir1.2-gstreamer-1.0
gstreamer1.0-plugins-{base,good,bad,ugly}`):

```bash
cd multiview && python3 -m unittest discover -s tests
```

### Using it

- On the **Live Sports guide**, **\*** opens options (**Refresh feed**, add/remove Multiview, Watch Multiview).
  Choosing add/remove toggles the highlighted game
  (its first stream); the panel top right lists the picks, and a picked row
  says **Multiview** in its streams column
- On a **game page**, **\*** adds the highlighted stream, for when an alternate
  is the one that works
- **Play** (guide or game page) starts multiview once 2–4 games are picked
- In multiview: **arrows** move between games and **the sound follows the
  highlight** (red bar under the tile); **OK** opens that game full screen in
  the normal player, and Back returns to the mosaic; **\*** cycles
  Grid → Spotlight → Picture in picture; **Fast forward** (or Rewind) moves
  the highlighted game into the main spot; **Back** exits

### When a feed hiccups

Only that game's tile notices. Its last frame stays up for 3 seconds, then it
shows a "Reconnecting…" slate; after 6 seconds without a picture its ffmpeg
is replaced, retrying after 1, 2, 4, 8 and then every 15 seconds, and the
picture comes back as soon as frames do. The other tiles, the audio and the
output stream carry on throughout.

Layout and order changes are applied to the running mosaic on its next frame.
They still take around 6–8 seconds to show on the TV, since they pass
through the player's live buffer; the overlay waits for them. The pipeline
itself is only restarted if it fails, and that restart is written into the
same playlists as a discontinuity, so the Roku rebuffers briefly instead of
erroring out.

## Remote / focus

- **Left** opens the sidebar from Home, Libraries, Live Sports (and sports detail via Back first); **Right** hides it
- **Back** on TV / Live Sports: first press returns to the top tabs/pills; second press opens the sidebar. On Home or a library, Back opens the sidebar (from deep in shelves it returns to the top first)
- **Back** with the sidebar open exits the channel
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

## Cable TV EPG sidecar (home server)

Streams stay in `sportsFeedUrl` (updates as often as every 5 minutes). What’s-on listings are a **separate** object the Roku merges by channel id.

Run this on the **home server** (not this laptop). Every **6–12 hours** is enough — not after every feed publish.

### 1. One-time setup

```bash
# venv (reuse the splash one if you already have b2sdk there)
python3 -m venv ~/plexflix-epg-venv
~/plexflix-epg-venv/bin/pip install b2sdk

# env file
cp /path/to/repo/roku/scripts/cable_epg.env.example ~/plexflix-cable-epg.env
chmod 600 ~/plexflix-cable-epg.env
```

Edit `~/plexflix-cable-epg.env`:

```bash
# XMLTV source (default is fine for US cable nets)
EPG_XMLTV_URL=https://epgshare01.online/epgshare01/epg_ripper_US2.xml.gz

# Optional — synopsis / backdrop / cast for the guide + player (same key as PlexConfig tmdbApiKey)
# Use the v3 API Key. Put comments on their own lines — not after the value.
TMDB_API_KEY=your_tmdb_v3_key

# Backblaze B2 — same bucket/keys you already use for the sports feed / splash
# (no region setting; b2sdk talks to the native B2 API)
B2_BUCKET=roku-hockey
B2_KEY_ID=your_key_id
B2_APPLICATION_KEY=your_application_key

# MUST be the sidecar key — do not point this at secretfeedfilename.json
B2_REMOTE_KEY=plexflix/cable-epg.json
```

With `TMDB_API_KEY` set, the enricher looks up each unique programme title (cached under
`~/.cache/plexflix-cable-tmdb.json`) and attaches overview, backdrop/poster, year, rating,
and up to 8 cast members. The unified TV guide uses that art/summary on Cable rows; OK → player shows the
cast strip like library titles (stream stays live — no scrubber).

Channel id map (usually leave as-is): `roku/scripts/cable_epg_map.json`  
(`timst-cartoon-network` → `Cartoon.Network.HD.us2`, etc.)

### 2. Dry run (no upload)

```bash
~/plexflix-epg-venv/bin/python /path/to/repo/roku/scripts/enrich_cable_epg.py \
  --env-file ~/plexflix-cable-epg.env \
  --out /tmp/cable-epg.json
```

You should see something like `sidecar mapped=55 withEpg=55 programmes=…` and a ~0.8–1.5 MB JSON file.

Optional: `--days 2` keeps two days ahead (default is **6 hours back + 1 day ahead**).

### 3. Upload to B2

```bash
~/plexflix-epg-venv/bin/python /path/to/repo/roku/scripts/enrich_cable_epg.py \
  --env-file ~/plexflix-cable-epg.env \
  --upload
```

That writes:

`https://roku-hockey.s3.us-west-004.backblazeb2.com/plexflix/cable-epg.json`

`cableEpgUrl` in `PlexConfig.brs` already points there. If the object isn’t public yet, make that B2 file (or prefix) readable the same way as `secretfeedfilename.json` / splash posters.

### 4. Cron

```cron
# every 6 hours
20 */6 * * * ~/plexflix-epg-venv/bin/python /path/to/repo/roku/scripts/enrich_cable_epg.py --env-file ~/plexflix-cable-epg.env --upload >>/var/log/plexflix-cable-epg.log 2>&1
```

### What the Roku does

1. Load sports feed → Entertainment / Cartoons channels + stream URLs  
2. Load `cableEpgUrl` → `programs[]` keyed by feed channel `id`  
3. Merge into the unified TV guide (Cable rows)

Missing sidecar or unmapped channels (Fox, CBeebies, WAPA Deportes today) show a single 24/7 cell; playback still works.

### Without B2 upload

Build locally and copy however you like:

```bash
~/plexflix-epg-venv/bin/python /path/to/repo/roku/scripts/enrich_cable_epg.py \
  --env-file ~/plexflix-cable-epg.env \
  --out /tmp/cable-epg.json
# then rclone/aws/cp to your CDN, and set cableEpgUrl to that public URL
```

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
- Profiles, downloads
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
  scripts/enrich_cable_epg.py
  scripts/cable_epg_map.json
  scripts/cable_epg.env.example
  scripts/make_player_assets.py
  package.sh
```

`make_player_assets.py` regenerates `images/watched_check.png` (the watched
tick, also reused for the selected row in the player's track pickers) and
`images/player_scrim.png` (the gradient behind the playback controls). It has no
dependencies; run it from the repo root if you change the accent colour.
