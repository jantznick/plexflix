# Architecture

Target stack for the stick OS. Keep the system chrome native and fast; keep channels as web content.

```text
┌──────────────────────────────────────────┐
│  Native home shell                       │  launcher, settings, onboarding, OTA UI
├──────────────────────────────────────────┤
│  Channel runtime (web viewer)            │  one fullscreen web channel (MVP)
├──────────────────────────────────────────┤
│  System media engine                     │  mpv or GStreamer; HLS first
├──────────────────────────────────────────┤
│  Linux kiosk image                       │  network, CEC, remote, update, recovery
├──────────────────────────────────────────┤
│  Stick / board hardware                  │  SoC, Wi‑Fi/BT, HDMI, eMMC, remote
└──────────────────────────────────────────┘
```

## Layer responsibilities

### 1. Hardware

HDMI out, Wi‑Fi, Bluetooth (remote), enough decode for target resolution, storage for the image + one channel bundle. See [hardware.md](./hardware.md).

### 2. Linux kiosk image

- Boots to the shell only (no desktop, no app menu of a general-purpose OS)
- Network bring-up and captive onboarding
- HDMI-CEC (TV power / input / volume where possible)
- IR or BLE remote input mapped to a small key vocabulary (Back, Home, OK, arrows, play/pause, …)
- A/B or recovery-friendly **system** updates
- Developer mode toggle that exposes the sideload web UI

### 3. System media engine

Channels should not each ship their own fragile player stack for serious video. The runtime hands playback to a **system player**:

- MVP: HTTP(S) HLS (and progressive MP4 if cheap)
- Later: DRM, passthrough audio, HDR capability queries

The shell and runtime need a clear session API: play, pause, seek, stop, error, audio/subtitle tracks when available.

### 4. Channel runtime (web viewer)

Embedded browser engine (Chromium-class or similarly capable) hosting the active channel:

- Loads the sideloaded (or store-installed) bundle / start URL
- Injects a small **TV JS bridge** (keys, lifecycle, storage, “play with system player”)
- Fullscreen 10-foot UI; no mouse requirement
- Back / Home policy owned by the OS (channel can handle Back until it yields)

Details: [channels.md](./channels.md).

### 5. Native home shell

Chosen toolkit should be **native from the start** (candidates to evaluate at implementation time: Flutter, Qt, Slint, or similar — pick one when the repo spins up).

Shell owns:

- First-run wizard (language, network, remote pairing if needed)
- Home row: system tiles + the single sideloaded channel (MVP)
- Settings (network, display, developer mode, about, system update)
- Launching / suspending / killing the channel runtime
- Global overlays (volume toast, update available, “no network”)

## Why native shell + web channels

| Surface | Why |
| --- | --- |
| Shell | Focus movement, settings, and overlays must feel instant on stick-class SoCs |
| Channels | Web talent and tooling beat inventing a BrightScript-like language; matches “what Roku channels feel like” without the closed language |

## Developer mode (MVP)

Modeled loosely on Roku’s installer:

1. Enable Developer mode in Settings (may require a PIN / acknowledgment)
2. Stick shows an IP and opens a local **web UI**
3. Upload one channel package
4. Channel appears on the home row and can be launched
5. Replacing the upload replaces that single slot

No multi-channel sideload library in MVP unless it falls out naturally; the product lesson is the pipeline, not a store.

## Relationship to this monorepo

PlexFlix (`roku/`, `multiview/`) is a **future first-party channel candidate** and a source of UX lessons (focus, guide, player chrome). It is not the OS. When work begins, copy these docs into a new repo and keep implementation there.
