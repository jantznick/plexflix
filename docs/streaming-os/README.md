# Streaming OS exploration

Working notes for a **Roku-like HDMI stick product**: a Linux kiosk device that boots into our home experience and runs sandboxed **web channels**.

This is intentionally a **separate product** from PlexFlix (the Roku channel in this repo). PlexFlix may become one channel later. These docs should be portable — move this folder into its own repository when implementation starts.

## Decisions (locked for now)

| Topic | Decision |
| --- | --- |
| Product shape | Early-Roku style **stick** we eventually sell — not a TV manufacturer, not ads/platform sprawl |
| Base OS | **Linux kiosk** image (boots straight to our UI) |
| Shell toolkit | **Native from day one** (not a web kiosk shell); Flutter vs Qt vs Slint still open — see [shell-toolkit.md](./shell-toolkit.md) |
| Channels | **Web viewer** runtime (HTML/CSS/JS + TV APIs) — no custom BrightScript-like language |
| Sideload (MVP) | Developer-mode **web UI**, Roku-style; **one sideloaded channel** at a time |
| Updates for channels | Auto-update / multi-channel distribution → **channel store** (after sideload prototype) |
| Channel trust / signing | **Deferred** — revisit before public store or selling widely |
| Hardware path | Prototype on accessible boards → evaluate stick SoCs → ODM white-label / custom SKU |

## Doc map

| Doc | Contents |
| --- | --- |
| [architecture.md](./architecture.md) | Layers: hardware → image → media → runtime → native shell |
| [shell-toolkit.md](./shell-toolkit.md) | Native shell shortlist (Flutter / Qt / Slint) in plain language |
| [channels.md](./channels.md) | Web channel model, APIs, packaging, sideload, store later |
| [hardware.md](./hardware.md) | Finding boards/sticks; will a Pi/Radxa prototype translate? |
| [roadmap.md](./roadmap.md) | Prototype → sideload MVP → branding/store → sellable stick |

## One-sentence vision

> Sell a simple HDMI stick that owns boot, remote, home, and video; let developers (and us) ship channels as normal web apps; prove that with sideload before building a store.

## Non-goals (for this exploration / early MVP)

- Building a television (panel, TCON, OEM TV firmware)
- Competing with Google/Amazon on licensed streaming apps on day one
- A custom channel programming language
- Perfect HDR/Atmos/DRM matrix before the shell and sideload path work
- Treating PlexFlix as a requirement for OS success
