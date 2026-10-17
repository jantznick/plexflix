# Learning Roku SceneGraph from this channel

A guided tour of the **PlexFlix Roku channel** for people who already know
Node and React. This doc covers only `roku/` — not the React web app or the
multiview server.

Read the files in order. Each step says **what to open**, **what you learn**,
and **how it maps** to concepts you already have.

---

## The two pieces (and how they fit together)

| Piece | Role | Closest web analogy |
| --- | --- | --- |
| **BrightScript** (`.brs`) | Language: logic, HTTP, focus, state | JavaScript |
| **SceneGraph** (`.xml` + `.brs`) | UI framework: node tree, fields, focus, rendering | React + the DOM |

They are **not alternatives**. Modern Roku channels use SceneGraph for UI and
BrightScript for behavior. This channel is fully SceneGraph (`rsg_version=1.2`
in `manifest`). There is no classic `roScreen` / `roImageCanvas` UI here.

A useful mental model:

```
React component file          ≈  ComponentName.xml  +  ComponentName.brs
JSX / template                ≈  the <children> tree in the .xml
props / state / events        ≈  <interface> fields + observeField
useEffect / event handlers    ≈  init(), onChange handlers, onKeyEvent
fetch / API layer             ≈  Task components (PlexTask) running off-UI
React Router / app shell      ≈  MainScene creating and swapping screens
index.js / createRoot         ≈  source/main.brs + roSGScreen
package.json + index.html     ≈  manifest
```

Coordinates are **1920×1080** (FHD). There is no CSS, no flexbox, no DOM
inspector in the browser sense — layout is absolute (`translation`, `width`,
`height`) plus SceneGraph list widgets (`RowList`, `MarkupGrid`, etc.).

---

## Channel map (keep this open while reading)

```
roku/
  manifest                 Channel identity, splash, RSG version
  source/
    main.brs               Process entry (tiny)
    PlexConfig.brs         Env-style config (Plex URL, token, feeds)
    Fonts.brs              Shared font helpers
    Spinner.brs            Shared spinner helper
  components/              Every UI screen and widget (XML + BRS pairs)
  images/                  Posters, focus rings, nav icons, splash
  fonts/                   Outfit TTFs
  package.sh               Zip → sideloadable channel package
  README.md                Product / feature docs + sideload steps
  LEARNING.md              This guide
```

**Sideload loop** (from a full-stack perspective): edit → `./roku/package.sh` →
upload zip to `http://<roku-ip>` (developer mode). Details in `README.md`.

---

## Learning path

### 1. `manifest` + `source/main.brs` — how a channel boots

**Open:** `roku/manifest`, `roku/source/main.brs`

**What you learn**

- A Roku package is a zip with `manifest` at the archive root (see `package.sh`).
- `main_program=main.brs` is the entry file, like `"main"` in `package.json`.
- Bootstrapping SceneGraph: create `roSGScreen`, create the root scene by name
  (`"MainScene"`), show it, then sit in a message loop until the screen closes.
- The channel quits when `MainScene` sets `exitApp` and `Main()` closes the screen.

**React / Node mapping**

| Here | Web |
| --- | --- |
| `Main()` | `index.js` / Express `listen()` bootstrap |
| `CreateObject("roSGScreen")` | Creating a browser window / root canvas |
| `CreateScene("MainScene")` | `createRoot(...).render(<App />)` |
| `while true` + `wait(port)` | The process staying alive for events |

**Why start here:** the file is ~20 lines. You see that almost all real work
lives in SceneGraph components, not in `main.brs`.

---

### 2. `MainScene` — the app shell and router

**Open:** `components/MainScene.xml`, then skim `MainScene.brs`
(`init`, `showHome`, `clearScreens`, `showDetail`, `showVideo`, `onNavSelected`)

**What you learn**

- Root component: `extends="Scene"`.
- XML declares the chrome: background, `screens` host group, nav scrim,
  `SideNav`, loading banner.
- BrightScript in `init()` grabs node refs (`findNode`), loads config, wires
  observers, and calls `showHome()`.
- Navigation is **imperative**: `createObject("roSGNode", "HomeScreen")`,
  set fields (`config = ...`), `observeField(...)`, `appendChild` into
  `m.screens`, `setFocus(true)`.
- Home is **parked** (hidden + `suspended`) when you leave it, so returning is
  cheap. Other sections are torn down in `clearScreens`.
- Child screens talk upward by setting interface fields
  (`selectedItem`, `openMenu`, `playRequested`, `closed`). Parent observes those
  fields — this is the channel’s event bus.

**React / Node mapping**

| Here | Web |
| --- | --- |
| `MainScene` | Layout route + React Router outlet |
| `m.screens` Group | `{children}` / `<Outlet />` |
| `createObject("roSGNode", "X")` + `appendChild` | Conditional render / portal mount |
| `observeField("selectedItem", "onBrowseSelected")` | `onSelect` prop / custom event |
| Interface fields on children | Props out + callbacks up |
| `m.config` from `GetPlexConfig()` | Context / env injected into the tree |
| Parking Home vs destroying others | Keep-alive route vs unmount |

**Exercise while reading:** follow one path in code —

1. Sidebar picks Search → `onNavSelected` → `showSearch`
2. Home poster OK → `selectedItem` → `onBrowseSelected` → `showDetail`
3. Detail Play → `playRequested` → `showVideo`

That triangle (`MainScene` ↔ screen ↔ Task) is the whole architecture.

---

### 3. `HomeScreen` + `PosterItem` + `ShelfRowList` — a real screen

**Open in this order:**

1. `HomeScreen.xml` (layout + public fields)
2. `HomeScreen.brs` — `init`, `onConfigReady`, `loadHome`, `onHomeLoaded`
3. `PosterItem.xml` / `.brs` (one cell in a row)
4. `ShelfRowList.xml` / `.brs` (RowList subclass for Left/Back “escape”)

**What you learn**

**Component contract (`<interface>`)**  
Fields like `config`, `selectedItem`, `splashActive`, `suspended`, `refresh`
are the public API. Parents set them; the screen sets them to signal out.
`onChange="..."` in XML is like a controlled prop effect.

**Layout in XML**  
Hero billboard (`Poster` + wash `Rectangle`s + `Label`s), then a
`ShelfRowList` (custom `RowList`) for Netflix-style shelves. No CSS — size and
`translation` are explicit. Custom fonts point at `pkg:/fonts/...`.

**Data load pattern**

```brightscript
m.task = createObject("roSGNode", "PlexTask")
m.task.config = m.top.config
m.task.action = "home"
m.task.observeField("response", "onHomeLoaded")
m.task.control = "RUN"
```

That is “fire a worker, subscribe to its result.” The UI thread must not block
on HTTP; Tasks exist for that.

**Lists**  
`RowList` wants a `ContentNode` tree (rows → items). Each visible cell is an
instance of `itemComponentName="PosterItem"`. The list passes `itemContent`
into the item — like a virtualized list rendering `<PosterItem data={row} />`.

**Focus and the remote**  
TV UIs are focus-driven, not pointer-driven. `setFocus(true)`,
`rowItemFocused`, `rowItemSelected`, and `onKeyEvent` replace click handlers.
`ShelfRowList` intercepts Left on column 0 / Back / Up on row 0 and fires
`escapeLeft` / `escapeBack` / `escapeUp` so `HomeScreen` / `MainScene` can open
the sidebar or collapse the hero.

**React mapping**

| Here | Web |
| --- | --- |
| `HomeScreen.xml` children | JSX structure |
| `init()` + `findNode` | `useRef` after mount |
| `observeField("config", ...)` | `useEffect` on a prop |
| `PlexTask` + `response` | `react-query` / `useEffect` + `fetch` |
| `RowList` + `PosterItem` | Virtualized list + row component |
| `onKeyEvent` | Keyboard handler (but it’s the primary input) |
| `ContentNode` tree | Immutable list model the widget understands |

**Why this step matters:** after Home, every other screen is the same pattern —
XML tree, `init`, Task, list/focus, signal parent via fields.

---

### 4. `SideNav` — chrome, focus, and cross-screen state

**Open:** `SideNav.xml`, then `SideNav.brs` (expanded vs mini rail, selection)

**What you learn**

- A reusable chrome component living **beside** the content host, not inside
  each screen.
- Two visual modes: collapsed 72px icon rail (`mini`) and full drawer (`full`).
- Public fields: `expanded`, `railVisible`, `suppressed`, `selected`,
  `selectedLibrary`, `active`.
- `MainScene` owns when the rail shows (browse yes; detail/player/splash no)
  via `updateNavRail()`.
- Libraries are loaded asynchronously (pinned sources) and selection bubbles up
  as `selectedLibrary` for `MainScene.onLibrarySelected`.

**React mapping**

| Here | Web |
| --- | --- |
| `SideNav` | Persistent layout nav |
| `expanded` / scrim on `MainScene` | Drawer open state in the shell |
| `selected` field | `navigate("/search")` callback |
| `railVisible` / `suppressed` | Layout props from the parent route |

**Focus takeaway:** on Roku, “who has focus” is as important as React state.
Opening the menu is `setNavExpanded(true)` + `m.sideNav.setFocus(true)`.
Closing restores focus to the active section (`restoreSectionFocus`). If focus
is lost, the remote feels dead — a common bug class when learning.

---

### 5. `DetailScreen` → `VideoScreen` — stack navigation and playback

**Open:**

1. `MainScene.brs` — `showDetail`, `openDetailScreen`, `onPlayRequested`, `showVideo`
2. `DetailScreen.xml` (hero + actions interface)
3. Skim `DetailScreen.brs` — `onContentSet`, Play / seasons / related, `onKeyEvent`
4. `VideoScreen.xml` (custom player; stock Video UI disabled)
5. Skim `VideoScreen.brs` for content → `Video` node, overlays, progress reports

**What you learn**

**Overlay stack**  
Detail and video are appended onto `m.screens` on top of (or instead of)
browse surfaces. Closing removes the node and restores focus. Episodes often
resolve to the parent show first (`openShowForEpisode` /
`resolveEpisodeThenShow`) so Continue Watching lands on a series page.

**Upward events again**

- Detail sets `playRequested` → MainScene `showVideo`
- Detail sets `openDetails` → another detail (cast, similar title)
- Detail / Video set `closed` → pop the overlay

**Player design**  
`Video` runs with `enableUI="false"` and `focusable="false"` so this channel
owns the control chrome and keeps remote keys on the parent Group. Progress is
reported upward (`playbackReport`) so Tasks outlive the dying player node —
an important lifecycle lesson (don’t fire work on a node you’re about to
remove).

**React mapping**

| Here | Web |
| --- | --- |
| Push detail/video nodes | Nested routes or modal stack |
| `closed` / Back | `navigate(-1)` |
| `playRequested` payload | Router state / “play this id” |
| Custom overlay on `Video` | Custom player controls over `<video>` |
| Progress Task owned by MainScene | Upload beacon that must outlive unmount |

**Product behavior** (skip intro, BIF scrubbing, audio/subtitle picks) is
documented in `README.md`; use that as the feature checklist while reading
`VideoScreen.brs`.

---

### 6. `PlexTask` — the async data / API layer

**Open:** `PlexTask.xml`, then `PlexTask.brs` — `init`, `exec`, and one action
path such as `buildHome` (search for `function buildHome`). Skim `plexGet` /
`imageUrl` when you’re ready for HTTP details.

**What you learn**

- `extends="Task"`: runs `functionName` (`exec`) on a background thread.
- Single worker, many **actions** (`home`, `discoverSearch`, `liveTvGrid`,
  `reportProgress`, …) selected by `m.top.action` — like one API client with
  named methods, or a small RPC switch.
- Input: `config`, `action`, optional `item`. Output: `response` assoc array
  (usually `{ ok, ... }`).
- UI observes `response`; never call blocking HTTP directly from a screen’s
  `init` / key handler for anything slow.
- This file is large on purpose: metadata shaping, Discover, DVR, live tune,
  watchlist, image URL rewriting, etc. Treat it as a **service module**, not as
  something to read top-to-bottom on day one.

**React / Node mapping**

| Here | Web |
| --- | --- |
| `PlexTask` | Backend route handlers **or** a frontend API module run in a worker |
| `action` switch in `exec` | Express router / tRPC procedure map |
| `plexGet` / `plexPost` | `fetch` / axios wrappers |
| `response` field | Promise resolve → React Query cache |
| `metadataToItem` | DTO / mapper from API JSON to view-model |
| `control = "RUN"` | Kicking off the async job |

**Pattern to copy when you add features**

1. Add a branch in `exec` for a new `action`.
2. Implement `function fetchThing(cfg, item)`.
3. From a screen: create `PlexTask`, set `action` / `item`, observe `response`.
4. Update UI nodes / `ContentNode`s in the callback.

---

## BrightScript cheat sheet (from a JS perspective)

| BrightScript | JavaScript |
| --- | --- |
| `sub name()` / `function name() as Type` | `function` (sub = no return value) |
| `m` inside a component | Per-instance fields (`this` / component state) |
| `m.top` | The component’s own SG node (props + root) |
| `invalid` | `null` / `undefined` |
| `assoc array` `{ key: value }` | Plain object |
| `CreateObject("roArray")` / `[ ]` | Array |
| `if` / `else if` / `end if` | `if` / `else if` (blocks end with `end if`) |
| `for i = 0 to n` / `for each x in list` | `for` / `for...of` |
| `=` comparison and assignment | Same token for both (context-dependent) |
| `<>` | `!==` / inequality |
| `type(x)` | Rough runtime type string |
| `pkg:/images/...` | URL into the installed channel package |

There is no `npm` inside the channel. Shared helpers are other `.brs` files
pulled in with `<script uri="pkg:/source/..." />` on the component.

---

## Focus model (the biggest mental shift from React web)

1. Exactly one node has focus; the remote talks to that node.
2. Lists move focus between items; OK is “click.”
3. `onKeyEvent(key, press) as Boolean` — return `true` if you handled it,
   `false` to let the parent/default handle it.
4. Opening overlays must `setFocus` on the new screen; closing must restore
   focus (`MainScene.restoreSectionFocus` is the safety net).
5. Some nodes steal focus if you let them (`Video` is the classic trap — this
   channel forces `focusable="false"` on it).

If a change “breaks the remote,” check focus before checking data.

---

## Suggested hands-on exercises (still only reading/editing `roku/`)

Do these after steps 1–3. Keep diffs small.

1. **Config** — Put your Plex LAN URL and token in `source/PlexConfig.brs`,
   package, sideload, confirm Home loads.
2. **Trace a poster** — Log or temporarily change `loadingMessage` text in
   `HomeScreen.loadHome` / `onHomeLoaded` so you see the Task round-trip.
3. **Interface field** — Add a harmless Label on `HomeScreen` bound from a new
   field you set in `onHomeLoaded` (title count, etc.).
4. **Nav** — Follow `SideNav` → `MainScene.showSearch` and note which fields
   fire; then open Search on the device with Left + OK.
5. **Detail → Play** — From a movie detail, follow `playRequested` into
   `showVideo` without reading all of `VideoScreen.brs` first.
6. **New Task action (advanced)** — Add a no-op `action` in `PlexTask.exec`
   that returns `{ ok: true, ping: true }` and call it from Home once to prove
   the wiring.

---

## Where to look next (same patterns, more surface area)

Once the path above feels familiar, these screens reuse it:

| Screen | Extra things you’ll see |
| --- | --- |
| `SearchScreen` | Keyboard + Discover search action |
| `LibraryBrowseScreen` / `LibraryAllScreen` | Hub vs paged grid, A–Z rail, filters |
| `LiveTvScreen` | Custom guide grid, tune + DVR actions |
| `SportsScreen` / `SportsDetailScreen` | External JSON feed, multiview handoff |
| `CastDetailScreen` | TMDB enrichment via Task |
| `SplashMosaic` + `SplashManifestTask` | Launch experience + remote poster pack |

Feature-level behavior (DVR, watchlist, multiview URL, player keys) stays in
`README.md`. Use that as the product spec; use this file as the code-schooling
path.

---

## Official docs (when you want the platform reference)

- [SceneGraph overview](https://developer.roku.com/docs/develop/core-concepts/core-concepts-overview.md)
- [BrightScript language reference](https://developer.roku.com/docs/references/brightscript/language/brightscript-language-reference.md)
- [SceneGraph components API](https://developer.roku.com/docs/references/scenegraph/component-reference.md)
- [Channel packaging / sideload](https://developer.roku.com/docs/developer-program/getting-started/developer-setup.md)

Read this channel’s code first; dip into official docs when you hit a node type
(`RowList`, `Task`, `Video`, `Animation`) you want fully specified.
