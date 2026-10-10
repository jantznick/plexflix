# Shell toolkit shortlist

The **shell** is the stick’s own UI: home row, settings, Wi‑Fi wizard, developer mode, overlays. Channels are separate (web). This doc compares options for building that shell in plain language.

**Already decided:** the shell is **native from day one** — not a fullscreen website pretending to be the OS chrome.

You do **not** need to understand GPUs or window servers to pick among these. Think in terms of: how you write UI, how heavy it is on a cheap stick, and how painful Linux packaging is.

## What “native shell” means here

| Idea | Meaning for us |
| --- | --- |
| Native toolkit | The UI is drawn by a dedicated UI engine (Flutter/Qt/Slint/…), not HTML in Chrome |
| Still runs on Linux | Same family of OS on Pi, Radxa, and a future stick |
| Channels stay web | Only the *system chrome* is native; sideloaded channels use the web viewer |

So “native” ≠ “write C by hand.” It means “use a real app UI framework made for devices,” not “build the home screen as a React website.”

## What we need the toolkit to be good at

For a Roku-like shell, prioritize:

1. **D-pad / remote focus** — move a highlight with arrows; no mouse  
2. **Snappy on weak hardware** — stick SoCs are closer to a budget phone than a laptop  
3. **Fullscreen TV layout** — fixed 1080p/4K-ish surfaces, big type, simple motion  
4. **Talking to the OS** — start the channel webview, call network settings, trigger updates  
5. **Long-term packaging** — one way to build and ship the shell inside our Linux image  

Nice later: fancy animations, multiple languages, complex settings search.

## Shortlist

Three serious candidates. All can work. None are “wrong”; they trade learning curve vs performance vs ecosystem.

### 1. Flutter

**What it is:** UI toolkit from Google. You write **Dart**. It draws every pixel with its own engine (Skia/Impeller). Used for phones, desktops, and increasingly embedded/TV-ish UIs.

**Pros**

- Modern layout model; hot reload; lots of tutorials and widgets  
- Looks consistent across devices because it draws its own UI  
- Strong for product-feeling motion and design systems  
- Embedding a platform view / talking to Linux via platform channels is a known pattern  
- Big community if you get stuck  

**Cons**

- Heavier than the lightest toolkits (engine size, RAM). Fine on Pi 5; must be validated on a cheap stick  
- Dart is another language to learn (readable if you know JS/Java, but not React)  
- Linux/embedded deploy is less “batteries included” than mobile — you’ll do real packaging work  
- TV/remote focus is **not** as automatic as Roku SceneGraph; you design focus deliberately  
- Embedding **Chromium for channels** next to Flutter means two big engines in memory — plan for that  

**Fit for us:** Excellent if you want a polished branded shell and are okay learning Dart. Strong default for “feels like a product.”

### 2. Qt (QML)

**What it is:** Long-standing C++ framework; for UI you usually write **QML** (declarative UI, JavaScript-like expressions) plus optional C++ for system glue. Common in cars, industrial devices, set-top-ish products.

**Pros**

- Battle-tested on embedded Linux; vendors often already know it  
- QML is declarative (closer to “UI markup + logic” than raw C++)  
- Mature story for keys/focus, hardware integration, system services  
- Can be tuned quite lean compared with a full web stack  
- Good documentation for device UIs  

**Cons**

- Licensing: **LGPL** can work for dynamic linking, but **commercial Qt** appears if you need certain modules / static linking / legal comfort — budget time (or money) for this before you sell devices  
- Feels more “embedded industry” than consumer web; hiring/learning path is different from React  
- C++ shows up when you glue to weird hardware or subprocesses  
- Visual fashion defaults can look desktop-industrial unless you invest in design  

**Fit for us:** Excellent if Linux device integration and longevity matter most, and you’re willing to navigate licensing + a less web-like stack.

### 3. Slint

**What it is:** Newer lightweight UI toolkit aimed at **embedded** products. Own `.slint` UI language + bindings for Rust/C++/etc.

**Pros**

- Designed to stay small and fast on constrained devices — aligned with stick hardware  
- Clear separation of UI markup vs logic  
- Growing embedded story; pleasant modern tooling for its niche  
- Less RAM pressure next to a Chromium channel runtime (important on 2 GB sticks)  

**Cons**

- Smaller ecosystem than Flutter or Qt (fewer Stack Overflow answers, fewer TV examples)  
- You may write more custom widgets for a Netflix-like home row  
- Fewer “hire someone who already knows it” options  
- Younger project — more responsibility on us to pioneer patterns  

**Fit for us:** Excellent if stick performance/RAM headroom is the top fear. Slightly more pioneering than Flutter/Qt.

## Explicitly not the shell (for now)

| Option | Why it’s a poor shell choice for this product |
| --- | --- |
| **React / Electron / fullscreen Chrome** | Great for channels; as *OS chrome* it fights memory, focus, and boot-to-home snappiness on sticks |
| **Raw HTML in a kiosk browser** | Same problem; we already rejected web-for-shell |
| **Godot / game engines** | Possible, but odd fit for settings/OTA/system integration |
| **Gnome/desktop widgets** | Wrong product shape (we’re not shipping a desktop) |

Channels remain web. That decision doesn’t require the shell to also be web.

## Side-by-side (honest summary)

| | **Flutter** | **Qt / QML** | **Slint** |
| --- | --- | --- | --- |
| Language feel | Dart (app-like) | QML + some C++ | `.slint` + Rust/C++ |
| Learning if you know web | Medium | Medium–hard | Medium–hard |
| Stick RAM friendliness | Medium (validate early) | Good | Best of the three |
| Polished consumer UI speed | Excellent | Good (with design work) | Good (more DIY widgets) |
| Embedded Linux maturity | Improving | Excellent | Good for age |
| Ecosystem / answers online | Largest | Large | Smallest |
| Licensing gotchas | Generally straightforward | **Must read before selling** | Usually simpler — still verify |
| Risk next to Chromium channels | Two engines; watch RAM | Manageable | Best headroom |

## Practical recommendation (not locked)

For *this* project’s constraints (eventually a cheap stick, Chromium-class channel runtime, small team, consumer polish):

1. **Default lean: Flutter** — fastest path to a product-looking shell if Pi/stick RAM proves fine with shell + webview + player.  
2. **If a 2 GB stick chokes: Slint** — prioritize headroom.  
3. **If an ODM/partner already standardizes on Qt: Qt** — don’t fight the factory; mind licensing.

You can decide with a **weekend spike**, not a manifesto:

- Build a fake home row (10 tiles) + settings list + move focus with arrow keys  
- Run it beside a fullscreen webview playing a page  
- Measure memory and focus latency on the **dev mule**, then repeat on the **cheapest stick** you buy  

Whichever spike feels good on the stick wins. Rewriting a simple shell once is cheaper than guessing.

## Focus / remote: the part Roku spoiled you for

On Roku, SceneGraph list widgets do a lot of focus work. On Flutter/Qt/Slint you will:

- Define which control is focused  
- Handle Left/Right/Up/Down/OK/Back  
- Scroll lists so the highlight stays sensible  

Budget real design time for this. It’s not low-level kernel work; it’s UI state machines. Your PlexFlix Roku experience is useful **product** reference here.

## How this connects to channels

```text
Native shell (Flutter or Qt or Slint)
    │  launches / stops
    ▼
Web channel runtime (Chromium-class)
    │  asks OS to play video
    ▼
System player (mpv / GStreamer)
```

Pick the shell toolkit for **home + settings**. Do not pick it based on how channels are built — channels are web either way.

## Open choice

| Status | Item |
| --- | --- |
| Locked | Native shell (not web) |
| Open | Flutter vs Qt vs Slint — resolve with a spike on mule **and** a stick sample |

When the new OS repo starts, record the winner in that repo’s README and delete “open” from this table.
