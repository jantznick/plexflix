# Streaming OS exploration

Working notes for a **Roku-like HDMI stick product**: a Linux kiosk device that boots into our home experience and runs sandboxed **web channels**.

This is intentionally a **separate product** from PlexFlix (the Roku channel in this repo). PlexFlix may become one channel later. These docs should be portable — move this folder into its own repository when implementation starts.

## Decisions (locked for now)

| Topic | Decision |
| --- | --- |
| Product identity | **Lean alternative TV OS** + channel store (early-Roku simplicity, not today’s Roku bloat) — see [product-positioning.md](./product-positioning.md) |
| Home media | Support Plex/Jellyfin-class connectors; **not** the brand headline |
| Viewer account | **Not required** to use stick, free store, or server apps |
| Publisher account | **OK to require** to submit channels to our store |
| Big licensed apps | Official partner/cert path only — **no** iframe/unofficial Netflix/Disney wrappers |
| Base OS | **Linux kiosk** (Android/Google TV remains a documented alternative tradeoff) |
| Shell toolkit | **Native from day one**; Flutter vs Qt vs Slint still open — see [shell-toolkit.md](./shell-toolkit.md) |
| Channels | **Web viewer** runtime (HTML/CSS/JS + TV APIs) — no custom BrightScript-like language |
| Sideload (MVP) | Developer-mode **web UI**, Roku-style; **one sideloaded channel** at a time |
| Updates for channels | Auto-update / multi-channel → **channel store** after sideload prototype |
| Channel trust / signing | Required before a public store; details TBD |
| Hardware path | Boards/mules → evaluation sticks → ODM SKU; **hardware is not the moat** |
| Ads on home | **Not** part of the launch identity |

## Doc map

| Doc | Contents |
| --- | --- |
| [product-positioning.md](./product-positioning.md) | Current pitch, moat, accounts, Roku/Netflix lessons, Android tradeoff |
| [business-positioning.md](./business-positioning.md) | Volume vs premium avenues, revenue models, competitor map |
| [architecture.md](./architecture.md) | Layers: hardware → image → media → runtime → native shell |
| [shell-toolkit.md](./shell-toolkit.md) | Native shell shortlist (Flutter / Qt / Slint) in plain language |
| [channels.md](./channels.md) | Web channel model, APIs, packaging, sideload, store later |
| [hardware.md](./hardware.md) | Finding boards/sticks; mule → stick portability |
| [future-readiness.md](./future-readiness.md) | AR/VR, AI content, other long-horizon bets — insurance, not MVP |
| [roadmap.md](./roadmap.md) | Prototype → sideload MVP → branding/store → sellable stick |

## One-sentence vision

> Sell a simple HDMI stick that owns boot, remote, and home; run web channels with no required viewer account; grow a lean channel store — earn big licensed apps later, don’t fake them.

## Non-goals (for this exploration / early MVP)

- Building a television (panel, TCON, OEM TV firmware)
- Shipping unofficial Netflix/Disney/Hulu/etc. clients or iframes
- Requiring a platform account to use the device
- Competing with Onn/Fire on day-one app catalog size
- A custom channel programming language
- Ad-driven home row as the business foundation
- Treating PlexFlix / local media as the company identity
