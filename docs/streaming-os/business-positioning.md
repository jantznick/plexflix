# Business positioning & competitors

Working notes on **how this stick OS could make money and who it sits next to**. Product/tech decisions stay in the other docs; this one is market shape.

Nothing here is a commitment. It exists so hardware and roadmap choices (cheap stick vs premium box) stay honest about *which business* you’re building.

## The two avenues you named

Both are real. They are **different companies** in practice — shared software DNA, different BOM, support, marketing, and success metrics.

### Avenue A — Volume stick (early-Roku shape)

| | |
| --- | --- |
| **Offer** | Cheap HDMI stick, simple remote, good-enough 1080p/4K, your home + web channels |
| **Buyer** | Mass market, gifts, secondary TVs, “just want it to work” |
| **Price band (rough mental model)** | Fire Stick / Roku Express class — low hardware margin |
| **SKU count** | Few sticks, maybe one “+” with more RAM |
| **How money usually works** | Thin hardware profit; real upside later from **store take-rate**, partnerships, optional ads/home promotions, or licensing the OS to TV brands |
| **What must be true** | Dead-simple setup, reliable Wi‑Fi, boring stability, channel story that’s easy for normals |
| **Risk** | Competing with Amazon/Google/Roku on price and shelf space; they can lose money on hardware |

**Fits our docs today:** AliExpress → ODM stick, Linux kiosk, sideload then store. This is the default Path B story.

### Avenue B — Premium / prosumer box (Shield-like)

| | |
| --- | --- |
| **Offer** | Fewer, nicer units: better SoC, fan or serious thermals, Gigabit Ethernet, stronger codecs/AI upscaling story, local media power-user features |
| **Buyer** | Enthusiasts, Plex/Jellyfin homes, HTPC refugees, people who already own a “main” cheap stick and hate it |
| **Price band** | Apple TV / Shield class — hardware can actually margin |
| **SKU count** | One hero device (maybe tube + box later) |
| **How money usually works** | **Hardware margin** + loyalty; store is nice-to-have, not required for survival |
| **What must be true** | Playback quality, silence/thermals, Ethernet, format support, long software support — *reputation* |
| **Risk** | Tiny market; Nvidia/Apple already own the “just buy the good one” slot; you need a clear reason not to buy Shield |

**Fits our docs with a twist:** same OS, heavier reference hardware (mini PC / RK3588-class / Shield-class BOM), less obsession with $30 sticks.

### Can you do both?

**Same OS family, yes. Same launch SKU, no.**

Sensible sequence for a small team:

1. Prove OS + sideload + one living-room daily driver (either a solid mid stick *or* a prosumer box).  
2. Freeze software contracts (channels, updates).  
3. Then either **cost-engineer down** (Avenue A) or **margin-engineer up** (Avenue B) — not both in the first retail year.

If forced to pick a *first retail* identity: Avenue A matches “what Roku once was”; Avenue B matches “home media people who already care about PlexFlix.” Your existing PlexFlix work biases **B as beachhead, A as scale** — or A as product and B as a later “Pro” SKU.

## Other avenues (easy to miss)

These aren’t instead of A/B; they’re **business models** layered on top of the same software.

### 3. OS licensing to OEMs (mature Roku / webOS path)

You don’t sell sticks; TCL/Hisense-like partners ship TVs or sticks running **your** OS. You take per-device license + store/ads economics.

- **Pro:** Hardware inventory isn’t your problem  
- **Con:** You need a finished OS + bizdev; partners want Netflix-class certifications you won’t have early  
- **When:** Years after a credible consumer product, not MVP  

### 4. Enthusiast / “open stick” community (CoreELEC-adjacent)

Sell (or give) images + a blessed hardware list; revenue from optional Pro SKU, donations, or a small store.

- **Pro:** Matches Linux kiosk reality; cheap customer acquisition in forums  
- **Con:** Hard to turn into a big company; support burden; not mass retail  
- **When:** Natural byproduct of Phase 1–3 dogfood; weak as sole endgame if you want volume  

### 5. Vertical / B2B embeds

Hotels, clinics, signage, IPTV resellers, “box for this one content service.”

- **Pro:** Higher willingness to pay; fewer SKUs; less App Store politics  
- **Con:** Sales-led, custom work, can distract from consumer OS quality  
- **When:** Opportunistic if a partner appears — don’t design the whole OS only for this  

### 6. Attach revenue without ads

Channel store cut (classic 15–30% mental model), paid first-party channels, home-row promotion for partners, optional cloud (EPG, multiscreen) subscription.

- **Pro:** Aligns with Avenue A (cheap hardware)  
- **Con:** Needs developers + users; chicken-and-egg until sideload/store exists  

### 7. Ads-funded hardware (current Roku gravity)

Home screen ads, screensaver ads, streaming ad tier partnerships.

- **Pro:** Subsidizes cheap sticks  
- **Con:** Conflicts with “premium/simple” brand; trust tax; heavy ops  
- **When:** Only if Avenue A volume is real and you’re okay with that identity  

### 8. Bundle with *your* content/app

Stick is a distribution vehicle for PlexFlix-like experience (or a partner’s live sports). Hardware breaks even; content/app is the business.

- **Pro:** Clear story for your existing work  
- **Con:** Looks like a single-app box unless the channel platform is real  

---

**Hidden third product identity worth naming:**  
**“Open channel stick for power users”** — between A and B. Price mid ($50–100 class), no ads, great local media + sideload, store optional. That’s often where indie Linux TV projects land emotionally, even if they dream of A.

## Competitor map (plain language)

Grouped by *what job they do*, not by who has the best press release.

### Mass-market streaming sticks / cheap boxes

| Player | Role | Notes for us |
| --- | --- | --- |
| **Roku** (Express, Streaming Stick, Roku OS on TVs) | Category definer for Avenue A | Simple remote, channel store, ads/platform economics now; OS licensed onto many TVs |
| **Amazon Fire TV Stick** | Volume king in many US living rooms | Cheap; Alexa; Amazon content gravity; closed side-loading culture vs Roku’s classic feel |
| **Google TV / Chromecast** (and **Walmart Onn**, etc.) | Android-based mass devices | Huge app catalog; Google account gravity; commodity ODMs already build these |
| **Xiaomi / generic Android sticks** | Race-to-bottom hardware | Prove that cheap HDMI sticks are abundant; software is where brands die |

**Implication:** Avenue A is a **distribution and simplicity** fight against giants who can subsidize hardware. Your wedge is unlikely to be “more apps than Google.” Wedge ideas: cleaner UX, no ads, open sideload/web channels, local-media honesty, privacy, or a beloved store niche.

### Premium / living-room computers

| Player | Role | Notes for us |
| --- | --- | --- |
| **Apple TV 4K** | Premium simplicity + ecosystem | Best “it just works” for Apple homes; not a sideload playground |
| **Nvidia Shield TV** | Avenue B archetype | Local media, AI upscale, Android apps, enthusiast love; aging hardware cycles, still the name to beat for Plex people |
| **High-end Fire Cube / occasional “Pro” sticks** | Soft premium | Amazon ecosystem first |

**Implication:** Avenue B needs a **clear Shield-shaped promise** (local media, Ethernet, codecs, silence, long updates) *or* a different niche (e.g. best web-channel developer device). “Slightly cheaper Shield” rarely wins.

### TV-makers’ own OS (not sticks, still competitors for attention)

| Player | Role |
| --- | --- |
| **webOS (LG)**, **Tizen (Samsung)**, **VIDAA / Google TV on Hisense/TCL**, **Roku TV** | The TV *is* the platform; sticks become optional |

**Implication:** Many households won’t buy *any* stick if the built-in OS is good enough. Sticks win on upgrade cycles, bad smart-TV UX, and secondary TVs.

### Open / enthusiast software platforms

| Player | Role | Notes for us |
| --- | --- | --- |
| **Kodi + LibreELEC / CoreELEC** | “Turn a box into a media player” | Strong decode/community on Amlogic; not a modern channel store UX |
| **Jellyfin / Plex clients on anything** | App layer, not OS | Your PlexFlix work lives here as a *channel*, not as the OS competitor |
| **webOS OSE / miscellaneous FOSS TV shells** | Ideals more than products | Talent and ideas; little retail presence |

**Implication:** These are **allies or substrates** (especially Amlogic Linux knowledge) more than shelf competitors — unless you only ship images and never hardware.

### IPTV / specialty boxes

Formuler, Mag-style STBs, operator boxes: closed verticals. Relevant only if Avenue 5 (B2B) appears.

## Positioning matrix

```text
                 Low hardware price          High hardware price
              ┌──────────────────────────┬──────────────────────────┐
 Mass reach   │ Avenue A — volume stick  │ Google/Apple rare here   │
              │ Roku / Fire / Onn fight  │ (usually ecosystem tax)  │
              ├──────────────────────────┼──────────────────────────┤
 Niche reach  │ Mid “open stick” indie   │ Avenue B — Shield-like   │
              │ community / no-ads mid   │ Prosumer / local media   │
              └──────────────────────────┴──────────────────────────┘
```

## Choosing with questions (not vibes)

Ask these before freezing a first retail SKU:

1. **Who is the first 1,000 users?** Family+friends, Reddit power users, or Big-box shoppers?  
2. **What do they hate today?** Ads on Roku home, Fire upsells, Shield age/price, smart-TV bloat?  
3. **Where does margin come from in year two?** Hardware, store, license, content, ads?  
4. **Can we support it?** Volume sticks generate “Wi‑Fi doesn’t work” tickets at scale.  
5. **Does PlexFlix matter to the brand?** If yes, Avenue B / open-mid beachhead is more natural. If no, Avenue A purity is fine.

## Strawman strategies (pick one to stress-test)

### Strategy S1 — “New Roku (honest)”

- Ship Avenue A stick, no home ads at launch  
- Web channels + sideload, store next  
- Win on simplicity and developer friendliness  
- Accept hardware as loss-leader only when store/partners exist  

### Strategy S2 — “Spiritual Shield”

- One premium SKU, hardware margin  
- Best-in-class local playback + your OS polish  
- Channels/store secondary; power users are the marketing engine  
- Optional later: cheaper stick with same OS  

### Strategy S3 — “Beachhead B, scale A” (often right for *this* repo’s history)

- Dogfood on a mid/high device (quality bar from day one)  
- Publish channel/sideload story to developers and media nerds  
- Cost-reduce to a volume stick once the image and store ops exist  
- Keep a “Pro” SKU alive for reputation  

### Strategy S4 — “Software only until forced”

- Support a short hardware allowlist (Radxa + one ODM stick)  
- Sell nothing at first; build brand + channels  
- Productize the winning board with an ODM when pull is obvious  

## Relationship to the technical roadmap

| Business lean | Hardware doc emphasis | Roadmap emphasis |
| --- | --- | --- |
| Avenue A | ODM stick cost, Wi‑Fi certs, thermals in tiny plastic | Sideload → store → certs → retail |
| Avenue B | Ethernet, decode quality, quieter box, longer support | Polish player + shell; store can wait |
| S3 hybrid | Mule + one good reference stick/box, defer SKU freeze | Phase 2–3 dogfood before branding spend |

Tech stack (Linux kiosk, native shell, web channels) **supports all of the above**. It does not choose for you — BOM, ads policy, and go-to-market do.

## Open business questions

- First retail identity: **A, B, or S3 hybrid?**  
- Ads: never / later / only on free tier?  
- Is the brand “OS company,” “device company,” or “channel store + reference hardware”?  
- How central is PlexFlix (or local media) to the marketing wedge?  

Record answers here when you have them; they beat rewriting the architecture every quarter.
