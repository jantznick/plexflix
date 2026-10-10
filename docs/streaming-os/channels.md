# Channels

Channels are **web apps** packaged for the stick: HTML/CSS/JS plus a manifest. No custom channel language.

The goal is BrightScript-*shaped capability* (full screen, remote, video, home row presence) with normal web development.

## MVP channel rules

- **One sideloaded channel** at a time (replace to install another)
- Install via **developer-mode web UI** on the local network (Roku-like)
- **No auto-update** of sideloaded channels in MVP
- Multi-channel install, browsing, and auto-update wait for a **channel store** (post-prototype)
- Signing / trust model **TBD** before a public store or wide hardware sales

## Package shape (draft)

Exact formats will firm up in the new repo. Expected pieces:

```text
my-channel/
  manifest.json      # id, name, version, icons, start_url, permissions
  icon.png
  www/               # static assets (or start_url pointing at bundled index)
    index.html
    ...
```

`manifest.json` sketch:

```json
{
  "id": "com.example.hello",
  "name": "Hello Channel",
  "version": "0.1.0",
  "start_url": "index.html",
  "icons": { "1080": "icon.png" },
  "permissions": ["network", "media"]
}
```

Zip (or similar) uploaded through the developer web UI.

## Runtime responsibilities

| Concern | Behavior |
| --- | --- |
| Lifecycle | `cold start` → `foreground` → `background` / `kill` when user leaves |
| Input | Map stick remote to browser-facing key events + bridge helpers |
| Video | Prefer **system player** bridge over relying solely on in-page `<video>` for “real” streams |
| Storage | Small keyed local storage per channel id |
| Network | Allowed for MVP; tighten with permissions later |
| Exit | OS Home always returns to shell; Back may be handled by the channel first |

## TV JS bridge (minimum useful set)

Names are illustrative:

- `tv.keys` / key events — Back, Home, OK, arrows, media keys  
- `tv.media.play({ url, type, startPosition })` → system player  
- `tv.media` events — playing, paused, ended, error, timeupdate  
- `tv.storage.get/set` — per-channel  
- `tv.app.exit()` — return to shell  
- `tv.device.info` — model, OS version, resolution (for layout)

Keep the bridge small. Channels should look like ordinary front-end apps with a TV focus library (even a thin one we document).

## Sideload web UI (MVP)

Hosted by the stick when Developer mode is on (e.g. `http://<stick-ip>:8080`):

1. Show device name / OS version  
2. Upload channel package  
3. Show currently installed sideload channel (if any) + Remove  
4. Optional: simple log tail for “channel crashed / player error”

Limitations by design for MVP:

- Single channel slot  
- No store account  
- No background update checks  

## Channel store (later)

After sideload works end-to-end:

- Branding, home visual identity, marketing site  
- Store catalog + install of multiple channels  
- Signed packages and update channels  
- Auto-update policy (shell prompts vs silent patch)  
- First-party apps (possibly a PlexFlix port) published as normal channels  

Sideload can remain as a developer escape hatch (as on Roku), even after the store exists.

## Proof-of-concept success criteria

1. “Hello Channel” web bundle sideloads through the web UI  
2. It appears on the native home row  
3. Remote navigation and OK work inside the channel  
4. Channel can play an HLS URL via the system player  
5. Back / Home return to the shell without rebooting  
6. Uploading a second package replaces the first cleanly  

That is enough to claim a **channel platform concept**, before store work.
