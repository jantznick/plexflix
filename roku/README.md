# PlexFlix for Roku (MVP)

Netflix-style browse + play layer over your local Plex Media Server.

This is intentionally a **design/UX shell** on top of existing Plex data. Credentials are hardcoded for local testing.

## What you get

- Dark Netflix-like home: billboard hero + horizontal shelves
- **Collapsible sidebar** (Left to open): Home, your **Libraries**, **Live TV**, Live Sports.
  Collapsed, a 72px icon rail stays on browse screens with the current section
  lit; it is hidden on detail pages, in the player and over the launch splash
- **Home stays loaded**: switching sections parks it instead of discarding it,
  so returning is instant and the hubs refresh in the background (also after
  playback), updating only the rows whose items changed
- Selecting a library in the sidebar opens that library’s shelves
- **Live TV**: Guide layout always visible (columns + placeholder rows while syncing); program info top-left, preview top-right
- **Libraries**: mosaic hero + **View all**; full grid with filter, search, order-by and an A–Z rail
- **Continue Watching**, **Recently Added**, Plex hubs, library shelves, **genre rows**, and **Discover** trending (Netflix/Disney+/etc.)
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
- Live sports from a configurable JSON feed URL (event detail + stream picker)
- **Multiview**: 2–4 live games at once in Grid, Spotlight or Picture in picture,
  tiled on your home server (see [Multiview](#multiview))
- Optional **TMDB** enrichment for cast pages and Discover titles missing from your library (`tmdbApiKey` in config)
- Discover titles not in Plex open a **Not in your library** detail view (no Play) with synopsis + similar local picks

## Configure before sideload

Edit `roku/source/PlexConfig.brs`:

```brightscript
baseUrl: "http://192.168.x.x:32400"
token: "YOUR_PLEX_TOKEN"
sportsFeedUrl: "https://roku-hockey.s3.us-west-004.backblazeb2.com/secretfeedfilename.json"
tmdbApiKey: "YOUR_TMDB_API_KEY"
multiviewUrl: "http://192.168.x.x:8095"   ' optional, see Multiview
```

Optional keys:
- `tmdbApiKey` — cast bios / photos / known-for, plus synopsis art for Discover titles not in your library (https://www.themoviedb.org/settings/api)
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
`multiview/` (repo root) runs ffmpeg to combine 2–4 sports feeds into a
single 1080p HLS stream, and the channel plays that stream. Each game keeps its
own audio track, and the channel draws the focus ring, labels and status on top
using the tile rectangles the server reports.

### Server (home server, Docker Compose)

```bash
cd multiview
# pick ENCODER (libx264 / h264_qsv / h264_vaapi / h264_nvenc) and uncomment
# the matching GPU block in docker-compose.yml first
docker compose up -d --build
docker compose logs -f
```

Then set `multiviewUrl` in `PlexConfig.brs` to `http://<server-ip>:8095` and
republish. Leaving it empty hides multiview entirely.

`libx264` works anywhere but is heavy at 1080p; an Intel iGPU (`h264_qsv` or
`h264_vaapi` with `/dev/dri` passed through) or NVIDIA (`h264_nvenc`) is the
comfortable option. Small tiles pull a lower rendition of each feed when its
master playlist offers one, which keeps decoding cheap too.

Tests run without Docker or network (they need `ffmpeg` on the path):

```bash
cd multiview && python3 -m unittest discover -s tests
```

### Using it

- On the **Live Sports guide**, **\*** adds or removes the highlighted game
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

The server checks every feed separately from ffmpeg (does its playlist load,
and is it still advancing?). When ffmpeg dies or stops producing, the feeds
that fail that check are replaced by a "Reconnecting…" slate and ffmpeg is
restarted with the rest. Feeds that are down keep being checked, and come
back after staying healthy for 20 seconds.

Each restart is written into the same playlists as a discontinuity, so the
Roku rebuffers for a few seconds instead of erroring out. The cost of running
one ffmpeg is that a restart (a feed dropping, recovering, or a layout change)
briefly stalls every tile, not just the one that changed. Layout changes
take around 10 seconds to appear, because they also have to pass through the
player's live buffer; the overlay waits for them.

## Remote / focus

- **Left** opens the sidebar from Home, Libraries, Live Sports (and sports detail via Back first); **Right** hides it
- **Back** on a section's main screen (Home, a library, Live TV, Live Sports) opens the sidebar; from deep in Home's shelves or a library's shelves it returns to the top first
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
  scripts/make_player_assets.py
  package.sh
```

`make_player_assets.py` regenerates `images/watched_check.png` (the watched
tick, also reused for the selected row in the player's track pickers) and
`images/player_scrim.png` (the gradient behind the playback controls). It has no
dependencies; run it from the repo root if you change the accent colour.
