# PlexFlix for Roku (MVP)

Netflix-style browse + play layer over your local Plex Media Server.

This is intentionally a **design/UX shell** on top of existing Plex data. Credentials are hardcoded for local testing.

## What you get

- Dark Netflix-like home: billboard hero + horizontal shelves
- **Collapsible sidebar** (Left to open): Home, your **Libraries** listed inline, Live Sports
- Selecting a library in the sidebar opens that library’s shelves
- **Continue Watching**, **Recently Added**, Plex home hubs, and library shelves
- Continue Watching episodes open the parent show with that episode focused
- Title detail screen (Cast + More Like This)
- Playback via Plex universal transcoder (HLS)
- Live sports from a configurable JSON feed URL (event detail + stream picker)
- Custom **Outfit** font, poster shadows, shimmer loading skeletons

## Configure before sideload

Edit `roku/source/PlexConfig.brs`:

```brightscript
baseUrl: "http://192.168.x.x:32400"
token: "YOUR_PLEX_TOKEN"
sportsFeedUrl: "https://roku-hockey.s3.us-west-004.backblazeb2.com/secretfeedfilename.json"
```

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

## Remote / focus

- **Left** opens the sidebar from Home, Libraries, Live Sports (and sports detail via Back first); **Right** or **Back** hides it
- Libraries appear as flat items in the sidebar (no wrapping cycle at the ends)
- Arrow keys move across poster rows
- Focused title updates the hero billboard
- OK opens the detail screen (episodes open the show with that episode selected)
- Play / OK starts playback
- Back returns to the previous screen
- Loading uses a bottom banner + shimmer skeletons — the UI stays navigable

## Fonts

Outfit (Google Fonts / OFL) ships under `roku/fonts/`. Swap TTFs there and update `pkg:/fonts/...` references if you prefer another face.

## Out of scope for this MVP

- Account login / PIN pairing UI
- Search, profiles, downloads
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
  package.sh
```
