# Product positioning (current lean)

Working product narrative after the exploration conversations. Companion to [business-positioning.md](./business-positioning.md) (avenues, competitors, revenue models).

Nothing here ships code. It exists so we don’t drift back into “Fire Stick with Netflix on day one” or “premium piracy UI.”

## Digestible pitch

> **A lean living-room OS with a channel store — simple like early Roku, without today’s Roku bloat.**  
> No required platform account. Web channels. Home-server apps (Plex/Jellyfin) supported as *connectors*, not the brand.

Slightly longer:

> Buy a stick, set up Wi‑Fi, use the home row and free channel store. Optional guest checkout for paid channels. Your library servers work here too. Big licensed apps (Netflix/Disney/…) only when we earn real device partnerships — we don’t fake them with webviews.

## Metaphor (keep it handy)

| Analogy | Who | Meaning for us |
| --- | --- | --- |
| **Windows-ish sprawl** | Modern Roku | Platform/ads/bloat; powerful but noisy |
| **Commodity Linux PC energy** | Cheap Android sticks | Capable/messy; catalog comes from Google/Amazon |
| **Apple-simple / Shield lane** | Us (aspiration) | Opinionated, tasteful, fewer things — own the OS chrome |

We are trying to be an **alternative TV OS**, not “the nicest Plex client” as the company identity. Personal media is a **feature**; the **goal** is a licensed-capable channel platform over time.

## What we are / aren’t

| We are | We are not (day one) |
| --- | --- |
| Custom **Linux kiosk** stick OS | A TV manufacturer |
| **Web channel** runtime + sideload → store | BrightScript / custom channel language |
| **No mandatory viewer account** | Google-account-gated living room |
| Lean home, developer-friendly store path | Ad home row / upsell OS |
| Honest about missing Big Apps until certified | iframe/unofficial “Netflix channel” |
| Mid/prosumer hardware path OK | Race-to-bottom $20 junk SKU as the brand |

## Moat (honest)

**Hardware is not the moat.** Amlogic/Rockchip sticks are a commodity (see [hardware.md](./hardware.md)). Random Android sticks already “have Netflix” because they **rent Google’s/Amazon’s app catalog**.

Moat has to be software + trust + ecosystem:

- Taste / simplicity of the shell  
- Web-channel developer experience (“ship a channel in an afternoon”)  
- No-account, low-bloat ethos  
- Signed store + clean brand (required if we ever want Big App partners)  
- Optional later: first-party channels people open nightly  

If the pitch needs “has Netflix” to work, we’re in the wrong frame until partnerships exist.

## Roku’s bootstrap lesson (don’t mythologize)

Roku did **not** start as an empty OS hoping for channels. Early consumer Roku was effectively built around a **Netflix hardware partnership** — an **anchor tenant** that made the box worth buying. The broader channel store grew after users and timing (early streaming) existed.

Implications for us:

- Cold-starting a licensed store without an anchor is **harder than Roku’s opening chapter**.  
- Research **device partner programs** (Netflix, Disney, etc.) early for requirements — don’t assume they’ll onboard a new Linux OS quickly.  
- Until then, grow with **sideload + our store for legitimate third parties**, plus our own channels / server connectors.  
- Big Apps are a **later certification track**, not an MVP feature.

## Licensed apps vs platform account

These are easy to conflate; keep them separate:

| Account | Who | When |
| --- | --- | --- |
| **Platform account** (us) | Viewer | **Not required** to use the stick, free store, sideload, or connect to Plex/Jellyfin |
| **Store publisher account** | Channel developer | **OK to require** to submit to our store |
| **Paid checkout identity** | Viewer | Guest checkout and/or payment token keyed by device (or optional login later) — not a mandatory “create an account” wall |
| **Netflix (or Disney, …) account** | Viewer | Their subscription login **inside that app**, if/when we ship an official app |
| **Device partner relationship** | Us (the company) | Required to **ship** an official Netflix/Disney/etc. app on our OS |

**Do not** ship iframe/wrappers of Netflix/Disney/Hulu/etc. Traction invites blocks, ToS issues, and kills partner goodwill. Official apps only via real programs (DRM/Widevine, player certs, security reviews).

## Home media (Plex / Jellyfin)

- **Ship the ability** to find/display media from Plex, Jellyfin, and similar.  
- **Do not** make “local media box” the headline brand.  
- Public positioning stays on **personal / home-server libraries you control** — never wink at piracy. Grey-market association exists in the culture; we don’t market to it. A clean brand is mandatory if the long-term goal is a licensed store.  
- PlexFlix (this repo) may become a **first-party or featured channel**, not the OS name.

## Channel store abuse (what we mean)

Not “users’ Plex libraries.” We mean **platform risk** once a store exists:

- Spam / junk channels  
- Fake branded channels (phishing)  
- Malicious packages  
- Pirate aggregator channels that create **DMCA/liability for us as the store host**

Mitigations: publisher accounts, signing, review, takedowns, rate limits. Viewer accounts are optional; **publisher accountability** is not.

## Android / Google TV fork (revisited)

Initially preferred **custom Linux** for full control and no Google account. Android remains a known alternative if Big Apps become a hard requirement too early.

| | **Custom Linux (current lean)** | **Certified Google TV / Android TV** |
| --- | --- | --- |
| Look & feel control | High (our shell is the OS) | Medium — OEM skin within Google rules |
| Big streaming apps | Per-service partnerships | Mostly inherited via Play Store |
| User-visible Google signals | None required | **Google account, Play Store, Cast, Google TV home DNA** usually stay |
| Moat | Our OS + store | Taste + hardware + first-party apps on Google’s platform |
| Hardware for snappy UI | Mid SoC fine; **4 GB** comfort for shell + web runtime | Mid SoC fine; 2 GB janky, **4 GB** comfort; Shield-class not required for Netflix UI |

Android path = real customization of brand/launcher/remote, **not** “users forget this is Android.” Linux path = no platform account, harder Big App story.

## Near-term product identity

Optimize for:

1. OS boots to our native shell  
2. Sideload → channel store for **legitimate** web channels  
3. No mandatory viewer account  
4. Plex/Jellyfin (and similar) as supported channels/connectors  
5. One solid hardware target (dev mule → evaluation stick → ODM)  

Defer: ads-funded home, XR, AI platform features, ESPHome remote productization, claiming Netflix compatibility.

## Success metrics (early)

- Daily driver in our own house without feeling like “Android with a theme”  
- Someone else can sideload or install a channel without us on call  
- Pitch works **without** promising Disney/Netflix  
- Brand and store policies look partner-safe if a Big App conversation ever happens  

## Open product questions

- First retail SKU: mid stick vs Pro box? (see avenues in [business-positioning.md](./business-positioning.md))  
- First anchor channel (our own content / sports / other) while Big Apps are absent?  
- Jellyfin + Plex both at launch, or one first?  
- When (if ever) to seriously pursue Google TV instead of Linux?  

Record answers here as they firm up.
