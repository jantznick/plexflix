# Roadmap

Phased so software learning is not blocked on retail hardware, and store/branding wait until sideload is real.

## Phase 0 — Docs & decisions (this folder)

- Vision, architecture, channel model, shell toolkit shortlist, hardware shopping guide, business positioning  
- Locked: Linux kiosk, native shell, web channels, single-slot sideload  
- Open: Flutter vs Qt vs Slint (see [shell-toolkit.md](./shell-toolkit.md)), browser engine, SoC winner, trust/signing, Avenue A vs B vs hybrid go-to-market (see [business-positioning.md](./business-positioning.md))  

## Phase 1 — Dev-mule prototype

**Hardware:** Libre Computer Le Potato (Amlogic) if available, else Pi 5 / Radxa / mini PC (see [hardware.md](./hardware.md)).

**Software goals:**

- Linux image boots to a **native** shell (placeholder home + settings)  
- System player plays a known HLS URL  
- Embedded web runtime launches a local “Hello Channel”  
- Remote keys (even a keyboard) move focus in shell and channel  
- Back / Home return to shell  

**Exit criteria:** daily boot → home → channel → video works on the mule.

## Phase 2 — Sideload MVP (family daily-driver)

- Developer mode + **web UI** installer on LAN  
- **One** channel slot; upload replaces previous  
- Onboarding: network + developer mode explained  
- HDMI-CEC basics; BLE or IR remote  
- Recovery or at least a documented reflash path  
- Channel bridge stable enough for a second sample channel  

**Exit criteria:** non-you household member can use the stick; you can ship them a new channel zip to sideload.

Optional: flash the same stack onto the best AliExpress **reference stick** once Phase 1 is solid.

## Phase 3 — Reference stick dogfood

- Pick SoC family from evaluation matrix  
- Port image to stick (bootloader, Wi‑Fi, decode, thermals)  
- Weeks of living-room use  
- File hardware bugs that only show up on stick-class devices  

**Exit criteria:** stick form factor is the primary device; mule is for development only.

## Phase 4 — Branding & channel store

Only after sideload is boringly reliable:

- Product name, visual identity, packaging story  
- Store catalog, accounts as needed, multi-channel install  
- Auto-update for store channels  
- Revisit **signing / trust**  
- Keep sideload as developer escape hatch  

First-party channels (including a possible PlexFlix port) publish through the same store model.

## Phase 5 — Sellable SKU

- Alibaba/ODM white-label or custom enclosure  
- Frozen BOM + remote in box  
- OTA system updates suitable for strangers  
- Certifications path (FCC/CE/etc.) with ODM  
- Support docs: flash, recover, sideload, report bugs  

**Exit criteria:** someone outside the family can buy/flash/use it without Slack access to you.

## Explicitly later / out of order on purpose

| Idea | When |
| --- | --- |
| App store polish, payments, featured rows | Phase 4+ |
| DRM / licensed streaming apps | After player + trust mature |
| Voice assistant | Optional, post-MVP |
| Custom channel language | Never (web is the bet) |
| Designing an LCD TV | Never (stick product) |

## Porting these docs

When implementation starts:

1. Create a new repository for the OS  
2. Move `docs/streaming-os/` → that repo’s `docs/`  
3. Leave a short pointer in PlexFlix if useful (“OS exploration moved to …”)  
4. Treat PlexFlix as a channel client project, not the OS monorepo  
