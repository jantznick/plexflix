# Hardware: finding a base for the stick

Goal: learn on forgiving hardware, then pick a **stick-class SoC** you can actually buy as a blank/white-label unit and eventually ship with your image.

You will use **AliExpress for samples** and **Alibaba / ODMs for productization**. They are not the same step.

## Two different marketplaces

| Where | Use it for | What you get |
| --- | --- | --- |
| **AliExpress** | 1–5 units, learning, comparing SoCs | Retail “Android TV stick” / development boards; fast shipping options; little/no customization |
| **Alibaba** | Finding the **factory** behind a stick | MOQs (often 100–1000+), custom enclosure/logo, your eMMC image preloaded, paperwork help |
| **Named board makers** (Radxa, Pine64, Libre Computer, Raspberry Pi, …) | Early OS bring-up with better docs | Not always stick-shaped; often healthier Linux support |

**Practical sequence:** AliExpress samples → prove Linux + UI + player on one SoC family → Alibaba message the seller/ODM → negotiate a reference stick with your branding later.

## What you are shopping for

Not “a Roku.” You’re shopping for:

1. **HDMI stick or tiny SBC** with a known SoC  
2. **Wi‑Fi + Bluetooth** (Bluetooth for a remote; Wi‑Fi for everything else)  
3. **Hardware video decode** (H.264 + H.265 at 1080p minimum; 4K if you want a sellable story)  
4. Enough **RAM/storage** (think 2–4 GB RAM class for web runtime + native shell; 16 GB+ eMMC nicer than SD-only)  
5. A path to run **your Linux image** (not locked forever to a random Android TV build)

Android preinstalled is normal and fine for purchasing — you will replace the software. What matters is whether the vendor (or community) has **kernel/u-boot/device-tree** support you can build on.

## SoC families worth shortlisting

These show up constantly in sticks and cheap TV boxes. Prefer a chip with **someone else’s Linux story** (CoreELEC, Armbian, vendor Yocto, mainline):

| Family | Typical devices | Notes |
| --- | --- | --- |
| **Amlogic** (S905X3 / S905X4 / S905Y4 / newer X5-class) | Many HDMI sticks & “TV boxes” | Huge Android-stick ecosystem; Linux often via community (e.g. CoreELEC) or vendor BSP; watch for weak documentation |
| **Rockchip** (RK3566 / RK3568 / RK3588S) | Sticks, boards, mini PCs | Often slightly saner for builders; Radxa/similar boards good for bring-up |
| **Allwinner** | Budget sticks | Hit-or-miss Linux; only if docs/BSP are clear |
| **Raspberry Pi / CM4 / CM5** | Dev kits, custom carriers | Best docs; great **prototype**. Weak as a long-term retail stick (cost, thermals, supply, “not an ODM stick line”) |

For “we sell a stick,” plan on **Amlogic or Rockchip ODM stick**. For “we boot our shell this quarter,” a **Pi 5, Radxa, or Libre Computer Amlogic board** is a legitimate development mule.

### Already own a Libre Computer Le Potato?

**[AML-S905X-CC (“Le Potato”)](https://libre.computer/products/aml-s905x-cc/)** is **Amlogic S905X**, not Rockchip. The `AML-` prefix and `S905X` name are the giveaway — same silicon vendor as a huge fraction of cheap TV sticks/boxes.

| | Le Potato (AML-S905X-CC) |
| --- | --- |
| SoC | Amlogic S905X (GXL), 4× Cortex-A53 |
| RAM | 1 GB or 2 GB variants (prefer **2 GB** for shell + web runtime) |
| Video | Hardware decode path for H.264/H.265/VP9; HDMI 2.0 / 4K-class claims |
| Why it’s useful | **Mainline-friendly Amlogic** board from a real vendor (images, docs, long support story) — rarer than random sticks |
| Bonus | Onboard IR receiver, Pi-like form factor/GPIO, CoreELEC/LibreELEC/Armbian-class options exist |
| Limits vs a 2024 stick | Older than S905X4/Y4-class sticks; 100 Mbit Ethernet; 1 GB models will feel tight next to Chromium |

**For our project:** this is an excellent **Amlogic mule** if you already have one — closer to Avenue A stick silicon than a Pi 5. Start OS/shell/player experiments here before buying more boards. Still re-test on a modern stick later (decode/Wi‑Fi/thermals differ), but you’re not starting from the wrong vendor family.

## Will a Pi 5 / Radxa prototype translate to a stick?

**Short answer:** Yes for *your app and product logic*. No for *the disk image and drivers*. Both being Linux is why the mule is worth it — it is not a magic “compile once, run on any stick” machine.

Think of two layers:

| Layer | Examples | Ports Pi → stick? |
| --- | --- | --- |
| **Product software** | Native shell UI, focus behavior, sideload web UI, channel packages, “play this HLS URL,” settings screens | **Mostly yes** — this is why we prototype here |
| **Board enablement** | Bootloader, kernel, Wi‑Fi driver, video decode plugins, HDMI hotplug, CEC quirks, thermal limits | **Mostly no** — redo / re-test per SoC family |

### What you get to keep

- Shell screens, navigation model, and toolkit choice (Flutter/Qt/Slint)  
- Channel manifest format, developer sideload flow, JS bridge shape  
- How the shell launches the web runtime and asks the system player to play  
- A huge amount of “what should this product feel like?” learning  

Same Linux userspace ideas (systemd, Wayland/X, files on disk, network manager concepts) show up on Pi and on sticks. Your mental model transfers.

### What you do *not* get for free

- A Pi SD card image will not boot an Amlogic stick  
- Wi‑Fi/BT chips differ → pairing a remote may need another pass  
- Hardware video decode APIs differ by vendor → the **player** often needs stick-specific glue even if the UI stays identical  
- Sticks are slower and hotter → UI jank and 4K decode limits appear only on the real device  
- CEC/remote edge cases are per TV + per board  

So: prototyping on Pi/Radxa is still the right move. You are not wasting work — you are building the **portable middle**, then paying a known “porting tax” to put that middle on stick silicon.

### How to make translation easier

1. **Keep board-specific junk in one place** — player backend, key input device paths, Wi‑Fi setup hooks. Shell UI should not import Pi-only APIs.  
2. **Match mule vendor to likely stick vendor when you can** — Le Potato / other Amlogic boards if you lean Amlogic sticks; Radxa if you lean Rockchip; Pi if you prioritize docs over SoC similarity.  
3. **Buy the AliExpress stick early, even if software starts on the mule** — run the *same* shell + webview + HLS test on both as soon as a minimal image exists.  
4. **Treat “works on mule” as Phase 1 exit, not product exit** — Phase 3 in [roadmap.md](./roadmap.md) is specifically stick dogfood.

### Mule board comparison

| | **Raspberry Pi 5** | **Radxa (RK3566/RK3588 class)** | **Libre Computer Le Potato (S905X)** |
| --- | --- | --- | --- |
| Vendor family | Broadcom | Rockchip | **Amlogic** |
| Docs / beginner path | Best | Good | Good (Libre Computer + community images) |
| Closeness to cheap TV sticks | Low | Higher if you pick Rockchip sticks | **Higher if you pick Amlogic sticks** (common) |
| Risk of “works on mule, dies on stick” | Higher for decode/GPU assumptions | Lower within Rockchip | Lower within Amlogic; still re-test on newer S905X4/Y4 |
| As a product you sell | Poor stick story | Board, not retail stick | Board, not retail stick — great learning platform |

**Rule of thumb:** Use the Le Potato if you already own it (especially 2 GB). Pi 5 for gentlest Linux learning. Radxa if you deliberately bet Rockchip. Any of these beats developing *only* on a locked Android stick.

## How to search AliExpress

Try queries like:

- `Amlogic S905X4 TV stick`
- `S905Y4 HDMI stick eMMC`
- `RK3566 compute stick HDMI`
- `Android TV stick S905X4 4K`
- `TV box S905X4 4GB` (boxes are uglier than sticks but often same SoC — OK for software bring-up)

Filter/sellers:

- Orders + recent reviews with **photos**  
- Listings that name the **exact SoC** (not just “4K TV Stick Ultra”)  
- Prefer **eMMC** over SD-only  
- Note Wi‑Fi module claims (`WiFi 5`, `WiFi 6`, `BT 5.0`) — often exaggerated; verify later  

Buy **two units** of a promising model if budget allows (bricking during bootloader experiments is common).

## What to ask / verify before you care about a model

Create a checklist per candidate:

### Must-know

- Exact **SoC** model  
- **RAM** and **eMMC** size  
- HDMI version / claimed max resolution + refresh  
- Wi‑Fi / BT chipset if listed (or tear-down photos)  
- Whether the seller can provide **board schematics**, **GPIO/UART pads**, or **burning/firmware tools**  
- Can you enter **recovery / burn mode** (Amlogic USB Burning Tool class flows are common)?  

### Linux viability (deal-makers)

Ask the seller (many won’t know — also search the model name + `Armbian` / `CoreELEC` / `Ubuntu` / `mainline`):

- Is there a public **device tree** / GitHub BSP?  
- What **kernel version** do community builds use?  
- Does **Wi‑Fi/BT** work under Linux or only under Android?  
- Does **hardware decode** work under Linux (V4L2 / vendor plugins)?  
- Any known **CEC** support?  

If the only software story is “use our Android firmware,” treat it as a **hardware shell** you might still buy for mechanical/HDMI validation — but do not bet the company on it until Linux networking + decode work.

### Nice-to-have

- Included **BLE or IR remote** (IR needs a receiver on the stick)  
- UART pins broken out (early console saves weeks)  
- Ethernet adapter support (stick + USB NIC is fine for dev)  
- Same PCB available as **bare board** and **in enclosure**

## AliExpress vs “productizable”

| Stage | Hardware choice | Success looks like |
| --- | --- | --- |
| **Dev mule** | Pi 5, Radxa, mini PC, or a TV box with known Linux | Native shell boots; web channel plays HLS |
| **Reference stick** | AliExpress stick whose SoC has a Linux path | Same image boots on stick form factor; remote + Wi‑Fi OK |
| **Sellable SKU** | Alibaba ODM builds your enclosure + loads your image | Stable BOM, test fixtures, certifications path |

Do not order 500 custom units until the reference stick runs your image for weeks in a real living room.

## Moving from AliExpress sample → Alibaba ODM

1. Open the AliExpress listing → often the same company has an Alibaba store (search the SoC + `OEM TV stick` + `ODM`).  
2. Message several ODMs with a short RFQ:

   - Target SoC family  
   - RAM/eMMC  
   - Want **unlocked bootloader / ability to flash custom Linux**  
   - Custom logo silk / box art later  
   - MOQ and sample price  
   - Existing **FCC/CE** module certifications?  

3. Ask for **sample units with serial console access** and any Linux BSP they already ship to other customers.  
4. Prefer ODMs who already support **non-Android** customers (digital signage / kiosk), even if rare.

## Certifications (when you sell)

You do not need this for a family prototype. Before selling in the US/EU:

- **FCC** (US), **CE/Red** (EU), often **safety** (charger related)  
- Wireless is the hard part — using a **pre-certified Wi‑Fi/BT module** the ODM already ships lowers pain  
- HDMI/logo compliance is a separate brand-licensing topic if you want the official logos  

Plan certifications as an ODM conversation, not an AliExpress cart checkbox.

## Remotes

MVP options:

- **BLE remote** paired to the stick (best user story)  
- **IR remote** + stick with IR receiver (cheap; line-of-sight)  
- HDMI-CEC TV remote (limited keys; good complement, bad sole input)

For development, a spare Bluetooth keyboard or a Flirc-style dongle is fine. For a product, budget a simple 10–20 button BLE remote in the BOM.

A **smart-home universal remote** (ESPHome / Home Assistant, AVR + lights + scenes) is a possible later companion product — not the MVP in-box remote. Positioning and sequencing: [future-readiness.md](./future-readiness.md#universal-smart-home-remote-esphome-centered).

## Suggested buying plan (concrete)

1. **Now:** one comfortable Linux board for shell + runtime bring-up — **Le Potato if you have it**, else Pi 5 / Radxa.  
2. **In parallel:** 1–2 AliExpress **Amlogic** sticks (natural next step after Le Potato) and optionally 1 **Rockchip** stick/box — evaluation vehicles.  
3. **Score them** on: serial boot, Wi‑Fi under Linux, 1080p HLS decode, CEC, thermals under load, remote options.  
4. **Winner:** chase that SoC’s ODM on Alibaba for a white-label reference.  
5. **Family MVP:** flash your image onto that reference stick; dogfood daily.  
6. **Sellable:** freeze BOM, enclosure, remote, and image update story; then branding + store software.

## Red flags

- Listing never names a real SoC (“powerful new chip”)  
- “4K” stick with 1 GB RAM  
- Seller cannot explain how to **reflash** firmware  
- Only ancient Android 7/9 images and no community Linux thread  
- Wi‑Fi works in Android demo video but every Linux forum post says “no driver”  
- Price far below market for the claimed SoC (wrong chip or fake listing)  
- Encrypted boot with no unlock path (you may never run your OS)

## What “good enough” looks like for this project

You do **not** need a custom PCB to validate the product idea.

You need one device that can:

- Boot **your** Linux kiosk image  
- Run the **native shell** at a solid frame rate  
- Run the **web channel runtime**  
- Play **HLS** through the system player  
- Accept a **remote** and basic **CEC**  

When that exists on a stick-shaped Amlogic/Rockchip unit, hardware risk is low enough to invest in branding and the channel store.
