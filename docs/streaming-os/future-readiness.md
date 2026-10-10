# Future readiness (AR/VR, AI content, and other bets)

Ideas that should **not** drive the MVP — but *should* shape a few architecture habits so we aren’t painted into a corner when they matter.

Rule of thumb: **ship a great 10-foot stick OS first.** Treat everything below as “extension points + principles,” not roadmap commitments.

## 1. AR / VR / spatial computing

### What’s actually going on

AR/VR (Vision Pro–class headsets, Quest, affordable XR) still struggles for everyday traction as a *TV replacement*. Living-room TV is not disappearing. XR is more likely to show up as:

- A **second surface** (watch / browse while someone else has the TV)
- A **spatial window** that plays the same streams/channels
- Niche homes / demos / aviation / pro use — not Walmart volume next year

So: important to *not block*, low urgency to *build native XR*.

### How our platform can be ready without building XR now

| Habit now | Why it helps later |
| --- | --- |
| **Channels as portable web (or web-like) packages** | A headset browser or XR web runtime can host many channels with less rewrite than BrightScript-on-Roku ever could |
| **Clear split: shell vs channel vs player** | XR may replace *shell chrome* and *input*, not your whole stack |
| **Media session protocol** (URL, position, audio route, pause) owned by the OS | Phone, tablet, headset, or another stick can be a remote surface controlling the same playback |
| **Don’t assume one screen rectangle forever** | Keep layout metadata (safe margins, density) in the channel API so “window in space” isn’t a rewrite |
| **Input as a vocabulary, not “the HDMI remote”** | Abstract Back/OK/arrows/pointer/gaze early in the bridge — map XR controllers later |

### What we probably should *not* do early

- Build a Quest/Vision OS port before sideload + store work on TV  
- Put 3D engine requirements on every channel  
- Design the home row only for stereoscopic UI  

### If XR ever becomes real for us

Likely path: **companion / cast / “place this channel in space”** long before “our stick is a headset.” The stick remains the household tuner and DRM/player box; XR is another *display client* of the same account and channel catalog.

**Bottom line:** Web channels + clean media/input APIs are already the main XR hedge. Avenue A/B hardware choices barely matter here; software contracts do.

---

## 2. AI-generated content

### Two different futures (don’t mix them up)

**Future A — AI content arrives as another Netflix-like channel**  
Generated movies/shorts/live avatars, but still: app icon → browse → play stream.

- **Impact on us:** Low. Our job stays host the channel + play media.  
- **Prep:** None beyond a normal channel store and a good player.

**Future B — AI becomes part of the *platform* experience**  
Guide that explains what’s on, remix clips, voice “make a recap,” personalized interstitial channels, on-the-fly localization, AI hosts for live sports, user-prompted mini-channels.

- **Impact on us:** Medium–high. Needs APIs, privacy rules, and maybe local compute.  
- **Prep:** Design for **helpers beside playback**, not only “rows of posters.”

### Where AI might touch *our* stack

| Layer | Possible AI role | On-device vs cloud |
| --- | --- | --- |
| **Shell** | Natural-language search, “what should we watch,” parental summaries | Cloud fine early; tiny on-device models later for privacy |
| **Guide / live** | Metadata cleanup, highlight detection, auto chaptering | Usually cloud; device runs results |
| **Player** | Upscale, denoising, silence skip, voice translate / dub | **On-device is plausible** on Avenue B hardware; weak on cheap sticks |
| **Channels** | Generative channels that call vendor APIs | Channel’s problem; we provide network, media, permissions |
| **Creation** | “Sideload a channel that was mostly generated” | Store trust/signing + review policy matter more than GPUs |

### On-device offload — sober take

Your instinct (“probably not for most things”) is right for **Avenue A cheap sticks**:

- Generating video/images on a $30 stick is a non-goal  
- Running a big LLM for chat-on-TV is usually **cloud** (or a PC on the LAN)  
- What *can* move on-device over time on mid/high SKUs: **upscaling, frame tools, speech-to-text for search, small recommendation models, NSFW/safety classifiers, audio ducking**

So: don’t promise “AI stick.” Do leave headroom in **Avenue B / Pro** for media enhancement NPUs/GPUs if the SoC has them, and keep the shell able to call a **local inference helper** (HTTP to a home server or optional on-device runtime) without hard-coding one cloud vendor into the OS.

### Platform readiness checklist (AI)

1. **Permissions** — channels declare mic, network, “personalization,” local model access  
2. **Trust** — AI-heavy sideload channels are why signing/review eventually matters  
3. **Metadata flexibility** — titles/rows that aren’t only static JSON (generated rails, ephemeral channels)  
4. **Player hooks** — optional post-process chain (upscale/translate) without each channel bundling ffmpeg  
5. **Privacy story** — “cloud AI optional” is a brand wedge against ad-tech platforms  
6. **Home-server friendliness** — same instinct as Plex/multiview: heavy jobs can live on NAS/PC; stick displays results  

**Bottom line:** AI-as-channel is free. AI-as-platform is permissions + player hooks + optional local/cloud inference. Cheap SKUs consume; Pro SKUs (or home servers) compute.

---

## 3. Other feasible vectors worth parking

### Short-form / vertical / “micro-drama” on TV

Fast-growing content shape (TikTok-like, serialized verticals). Still rectangles and streams — but **focus UX, preview autoplay, and feed APIs** differ from movie shelves.

- **Prep:** Don’t hardcode “3×N poster grid” as the only shelf primitive; allow channel-defined layouts.

### Interactive & cloud-gaming style channels

Channels that are input-heavy (games, choose-your-own, live shopping). Latency and input fidelity matter more than HLS elegance.

- **Prep:** Input bridge supports high-rate keys; optional low-latency video path later; don’t assume every channel is VOD.

### Companion devices (phone as remote / second screen)

Often more near-term than XR. QR pair, control playback, push a title to the stick.

- **Prep:** Same media session + account pairing APIs XR would want.

### Smart home as *control*, not content

Matter/Home Assistant: “Scene: Movie mode” dims lights and launches a channel.

- **Prep:** Shell deep links (`channel://…`, `play?…`); don’t bury launch only inside the D-pad home row.

### Universal smart-home remote (ESPHome-centered)

A **separate but related product idea**: sell a programmable remote that talks to the home theater *and* the rest of the house (AVR, TV, lights, scenes) — with **ESPHome** (and Home Assistant) as the customization center, open enough for power users out of the box.

This is **not** the same thing as “the BLE remote in the stick box,” and it should not gate the OS MVP. It *does* fit the ecosystem if sequenced honestly.

#### Is there space?

| Signal | Reality |
| --- | --- |
| Harmony is gone | Real gap for “one remote for AVR + TV + streamer + lights” |
| SofaBaton / similar | Prove people still pay for universal remotes; often cloudier / less HA-native |
| ESPHome + HA community | Strong niche that already wants local, YAML-custom, no subscription |
| Our stick OS | Needs *a* remote anyway; a smart remote can be the **Pro companion** later |

So: **yes, there is space** — mostly as an **enthusiast / local-home beachhead product**, not as a Walmart impulse buy on day one. Stretch risk is real if it becomes a second full company (plastics, battery, IR learning, support) while the OS is unfinished.

#### How it relates to the stick OS

```text
ESPHome remote ──BLE HID / Wi‑Fi──► Stick shell (nav, play, Home)
       │
       ├── IR / IP ──► TV, AVR, projector, discrete power
       │
       └── HA / ESPHome ──► lights, scenes, “Movie mode”
```

- **MVP stick:** ship or recommend a simple BLE/IR remote (see [hardware.md](./hardware.md)).  
- **Down the road:** bless an ESPHome remote as the “works great with our stick + HA” accessory.  
- **OS prep (cheap):** input abstraction, deep links for scenes, optional network API so a button can `launch channel` / `play` without pretending to be only a HID keyboard.

#### Why ESPHome is a good center of gravity

- Local-first, fits privacy / anti-cloud wedge  
- Custom button maps out of the box for the audience who will buy this  
- Same home-server mental model as Plex/multiview  
- You can prototype hardware without waiting for the stick OS to exist  

#### Honest sequencing

| Phase | Remote story |
| --- | --- |
| OS Phase 1–2 | Any working remote; don’t build a universal product yet |
| Parallel hobby (optional) | Personal ESPHome remote prototype — learn IR/BLE/HA, zero OS dependency |
| After stick dogfood | Decide if the remote is SKU #2 under the same brand |
| Retail stick | Cheap remote in-box; link “Pro remote” as upsell for HA homes |

**Verdict:** Down-the-road / parallel-hobby idea, **not** stretching if kept as a companion. Stretching if it steals the first year from sideload + shell. Architect the stick to welcome it; productize the remote only when the OS is daily-drivable *or* when you explicitly choose “remote-first business, stick later.”

#### Competitors / analogs (remote-specific)

- **Logitech Harmony** (discontinued) — category ghost; expectations still exist  
- **SofaBaton, SwitchBot Universal Remote, etc.** — consumer universal remotes  
- **Phone apps / HA dashboards** — free substitute; lose the “grab one puck” feel  
- **Folding DIY ESP32 remotes** — your early buyers; also your open-source competition  

Wedge if you proceed: **HA/ESPHome-native, theater + lights, first-class pairing with our stick**, repairable/custom — not “another Harmony clone with a cloud app.”

### Accessibility as a platform feature

System-wide captions, audio description, high-contrast shell, dyslexia-friendly type, switch control — especially differentiating vs cluttered Android TV skins.

- **Prep:** Caption pipeline in the **system player**; shell text scaling; channel API guidelines.

### Privacy / local-first OS wedge

No ad home row, minimal account requirement, LAN media first. Aligns with enthusiast beachhead and anti-Roku-ads sentiment.

- **Prep:** Product policy more than tech — but avoid mandatory cloud login for MVP playback.

### Multi-view / multi-session natively

You already prototype multiview server-side for sports. OS-level “two channels composited” is a premium differentiator (hard on cheap sticks).

- **Prep:** Keep player architecture able to consume a mosaic stream *or* (later) multiple decode sessions on Pro hardware.

### Creator / publisher tools

Not just “watch channels” — “publish a web channel from a template” (sports bar, church, indie streamer).

- **Prep:** Channel packager CLI + clear manifest; storefront later. This is how a web-channel bet becomes a business.

### Automotive / hotel / embedded reuse

Same kiosk image, different shell skin and input. Only matters if B2B appears.

- **Prep:** Skinning + input abstraction (already useful for TV remotes).

### Live sports & real-time data overlays

Platform-level timed metadata (scores, bets, polls) beside the player.

- **Prep:** Player “overlay surface” owned by OS or standardized channel API — avoid every sports channel reinventing focus fights with video.

---

## What to bake into architecture *now* (cheap insurance)

These are small compared to building XR/AI products:

1. **Stable channel package + JS bridge** versioned carefully  
2. **System media session** API (play/pause/seek/now-playing) usable by shell, companions, future surfaces  
3. **Input abstraction** (commands, not raw `/dev/input` in channel code)  
4. **Permission manifest** fields even if MVP ignores most of them  
5. **Layout / capability queries** (`screen`, `hdr`, `mic`, `localInference`, `maxDecodeSessions`)  
6. **No hard dependency on a single cloud AI or account vendor in the OS core**  
7. **Document “heavy work runs on home server”** as a first-class pattern (you already live here with multiview)

## What to explicitly defer

| Defer | Until |
| --- | --- |
| Native VisionOS / Quest shells | External demand + TV OS is boringly stable |
| On-stick video generation | Hardware exists *and* users ask |
| Platform-wide AI assistant with wake word | Privacy model + cloud budget exist |
| Mandatory AR home | Never, unless the category flips |

## How this relates to Avenue A vs B

| Vector | Cheap volume stick (A) | Premium / Pro (B) |
| --- | --- | --- |
| XR companion client | Cloud/account linked phone/headset | Same |
| On-device AI enhance | Rare | Plausible (upscale, STT) |
| Multi-decode / local multiview | Prefer server mosaic | Device might help |
| Short-form / AI channels | Store + player only | Same + performance headroom |
| Privacy / no-ads brand | Strong marketing fit | Strong marketing fit |

Avenue A **consumes** future content formats. Avenue B is where you **accelerate** them (enhance, multi-session, local assist). The channel model stays the same.

## Open questions

- Do we want a public stance: **“AI welcome as channels; OS stays user-controlled / low-cloud”**?  
- Is a **home inference box** (optional) part of the story, or stick-only forever?  
- Any XR interest beyond “don’t block,” or park indefinitely?  

Record answers when you have them; until then, use the insurance list above and keep shipping the TV stick OS.
