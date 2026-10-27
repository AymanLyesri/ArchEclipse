# AGENTS.md — ArchEclipse Quickshell Config

> Contributor guide for agentic workers. The AGS → Quickshell migration is
> **complete** and merged (`master`, PR #308): the shell is 100% Quickshell/QtQuick,
> the legacy `.config/ags/` tree is gone, and its scripts/assets were vendored into
> `.config/quickshell/archeclipse/scripts/` + `assets/`.
> Deferred (don't retry): Settings full `_schema` rewire + `fmt` move (`fmt` consumers
> in `Clock.qml`); Caelestia `Blobs/` C++ SDF goo (needs a CMake toolchain this repo has none of).

## 1. Architecture

### 1.1 Entry point — `shell.qml`

`ShellRoot` with per-monitor instantiation via `Variants { model: Quickshell.screens }`:

| Window | Source | Notes |
|---|---|---|
| `Bar` | `widgets/bar/Bar.qml` | Main pill; one instance per monitor |
| `MediaWindow` | `widgets/media/MediaWindow.qml` | Standalone media controls; one instance per monitor, toggled by `SUPER+M` |
| `NotificationPopups` | `widgets/notifications/NotificationPopups.qml` | Toast popups, per monitor |
| `LockScreen` | `widgets/lock/LockScreen.qml` | Single scope; compositor creates one `WlSessionLockSurface` per screen (no `Variants`) |

Startup also `mkdir -p`s every cache dir `FileView` writes to (writes to missing dirs fail silently):
`~/.cache/quickshell/{settings,booru,launcher,script-timer,crypto,chatbot,auth,manga,wallpaper-thumbs,activity}`,
`~/.cache/coloreclipse`, `~/.config/wallpapers/{custom,wallhaven,defaults}`, `~/.config/fastfetch/cache`
— and primes `FastfetchPins` so its pins-watcher attaches at boot.

### 1.2 Bar state machine — `services/BarState.qml` (singleton)

One pill, many states — plus independent side pills. `activate(name, holdMs,
monitorName)` / `deactivate(name, monitorName)` keep islands and transient
pulses per monitor; `activeStates` holds the shared default state.
`resolveState()` picks the highest-priority state for the requested monitor
(debounced 100ms).
Priorities (main pill only):

```
default 0 < pulses 80 (volume/brightness/network/player/weather/system)
  < control 90 < wallpaper 95 < search 100
```
`left`/`right`/`recording` are **side pills, not main-pill states**:
`resolveState()` skips them, so the main pill never hijacks. Side-pill
visibility keys off `BarState.isOpenFor(name, monitorName)`. The recording
indicator is scoped to `ScreenRecorder.targetMonitors` — never off `state`,
which never equals them. It also hover-reveals as an idle circle when the
pointer sits on the empty right side of the bar (per-monitor `recHotZone`
hover handler, `Bar.qml`; suppressed while the right island panel is open),
and click-toggles the recording (`RecordingIsland` MouseArea →
`ScreenRecorder.toggleRecording("now", monitor)`) morphing circle ⇄ pill.
Search has one owner monitor because `Launcher` is a singleton; opening it on
another monitor moves the search session there. Control, wallpaper, and player
have separate state on each monitor; their per-bar buttons, hover/Esc handlers,
and IPC toggles must pass that monitor through.

Rules that bite:
- `left`/`right` open **simultaneously** — no mutual exclusion. The main pill
  stays independent: transient pulses/search/control animate it while side
  pills dock to the screen edges (`leftPanelPill`/`rightPanelPill`, 8px margin,
  outermost, static); the main pill centers in the remaining space with a
  rigid `x` (no `Behavior` — per-frame coupled to width animations) while
  open/close pushes animate through `leftPush`/`rightPush` with the same
  easing as the width, so all motion stays one unit. Two transparent,
  background-less side pills chain off it — `leftSidePill` (WeatherButton)
  left of the main pill, `rightSidePill` (MediaPill, then the RecordingIsland
  fill, 8px apart, each keeping its own surface) right of it. All the
  island-bearing pills unfold on open and fold before hiding on close
  (exit-driver pattern: `setShown` + close timer) through a pill-level
  `IslandExpandClip` wipe — the same clip + fade + 0.96-scale recipe as
  main-stack islands, `openT` set discretely and animated inside the clip;
  the islands' own `expand` stays dormant at 1 so exactly one unfold plays.
- Closing a side pill does not change the main pill's resolved state —
  close-guards must listen to `onPanelStatesByMonitorChanged` and check
  `isOpenFor()` (see `BooruViewer` dialog) instead of `onStateChanged`.
- `default` is the permanent base and cannot be deactivated. `expanded`/`compact` are
  legacy aliases for `default`.
- Omit `holdMs` (or `0`) = persistent until explicitly deactivated. `holdMs > 0` = auto-deactivate timer.
- **Close-to-`default` animates (exit driver, `Bar.qml` stack):** when the
  target family is `default` and the outgoing island is exit-capable (`expand` prop),
  `displayed` holds while the island folds `1→0`, then `exitTimer` (`Theme.anim.normal`)
  swaps. `exitingFrom` keeps cached `Loader`s visible through the fold. Reopen mid-exit
  (`s === displayed`) cancels the timer and restores `expand = 1`; any *other* new state
  supersedes the exit (timer stopped, `exitingFrom` cleared). Island→island switches and
  same-family pulses swap instantly.

### 1.3 Islands — `widgets/bar/islands/`

Transient islands live **inside the bar pill** as `BarState` pages; the
left/right islands live in **side pills** flanking it
(`leftPanelPill`/`rightPanelPill` in `Bar.qml`; the chained status pills are
`leftSidePill`/`rightSidePill`), not separate windows:

| Island | State | Body |
|---|---|---|
| `LeftIsland.qml` | monitor-scoped side pill (`isOpenFor("left", monitorName)`) | Former left panel via `StackLayout` of lazy `Loader`s (see 1.4); cached `Loader` owned by `leftPanelPill` |
| `RightIsland.qml` | monitor-scoped side pill (`isOpenFor("right", monitorName)`) | Enabled `Settings.rightPanelWidgets`, outer `SmoothFlickable` + per-widget inner scroll; cached `Loader` owned by `rightPanelPill` |
| `SearchIsland.qml` + `widgets/launcher/LauncherPanel.qml` | monitor-scoped `search` | Launcher results (input lives in the island, results in the panel) |
| `ControlCard` (`widgets/controlPanel/ControlPanelBody.qml`) | monitor-scoped `control`, **inside** `DefaultBar`'s center pill | Quick settings; clicking the gear swaps the band row for the panel and the bar becomes it: the **center pill box itself** grows to the panel size (no iris/clip trick — `ControlCard.openT` drives `centerPill.width/height`, `Bar.qml`'s `stack.rigidDirect` drops the width/height `Behavior`s so the bar tracks rigidly, and the bump `PillBackground` hands off to the bar fill at `openT == 1`), zones hidden, workspace strip pushed below the panel; display brightness reads/writes the bar's monitor |
| `PlayerIsland` (`widgets/media/MediaWidget.qml`) | monitor-scoped `player` pulse | Track-change reveals target the focused monitor; hover/click reveals target the bar under the pointer |
| `OverviewIsland` (`widgets/overview/OverviewBody.qml` + `OverviewPreview.qml`) | "overview" (pri 85, `Ipc.toggleOverview`, `SUPER+SHIFT+TAB`); hover-leave close | 3×2 live `ScreencopyView` pager over `hyprctl clients -j` geometry (see §2.13); drag windows between `DropArea` cards → `movetoworkspace`, click focus / middle-click close (tile clicks stay open); all-10 5×2 grid with derived heights (arithmetic-from-metrics: leaves report implicitHeight 0); actions via `hl.dsp.*` (see §2.12); drop target resolved geometrically at release |
| `WeatherIsland` (`widgets/weather/WeatherCard.qml`) / `SystemMonitorIsland` | pulses | Transient/utility pages — **all** islands carry an `expand` 0→1 driver + `IslandExpandClip` unfold |
| `WallpaperIsland` (`widgets/wallpaperPanel/WallpaperPanelBody.qml`) | monitor-scoped `wallpaper` (cached) | Heavy switcher: `wallpaperPrimed` latch + `wallpaperCacheLoader` in the `Bar.qml` stack (created once, visibility-toggled) so image decodes, aspect caches and scroll survive closes; no refetch on reopen |

Shared island helpers (`widgets/bar/islands/`, module `qs.widgets.bar.islands`):

| Component | Job |
|---|---|
| `IslandExpandClip` | Emphasized-unfold body clip (`expand` 0→1 drives clip + opacity + scale; `Behavior on expand { Anim { type: Anim.Emphasized } }`) |
| `IslandHoverPin` | Hover-pin: hover stops the 1s leave timer + pins the state persistent; leave restarts it. 1s open-grace on creation so keybind-opened islands survive cursor travel (250ms pressure would close them before arrival); `armOnCreation: false` opts out (overview sets it), optional `leaveDelay`. Root is the `HoverHandler` itself — see §2.7 |
| `IslandEscClose` | 1×1 focused `Esc` grabber deactivating the listed states |
| `IslandWindowActions` | Bottom icon-button cluster (expand/shrink/lock/close); `side` switches the `Settings` keys, labels kept verbatim |
| `IslandSideRail` | 48px tab rail with 40px cells (`model`/`currentIndex`/`selected`; delegate declares `required property int index` — Qt6 withholds it otherwise); Left rail only — RightIsland keeps its custom drag rail (see §2.7) |
| Island registry | Islands `register(key, …)` in `onCompleted`, unregister bare alias + keyed entry in `onDestruction` (no helper — `destroyed` is not connectable in this engine) |

Shared right-panel helpers (`widgets/shared/` + `widgets/rightPanel/`, modules `qs.widgets.shared` + `qs.widgets.rightPanel`):

| Component | Job |
|---|---|
| `Card` | Surface/radius/border shell (`contentMargins`/`contentSpacing`, default 12/8); delegates override `color`/`border.color`/`radius` at use sites |
| `RightPanelCard` | Header (`title`, `+`/`close`) + add-form `Loader` + guarded `SmoothFlickable` list; owns shared `formatNextRun` (hosted delegates walk up via `objectName`) |
| `FormShell` | Add/edit form shell (surface/cardRadius, min 300/pref 350, margins 16/spacing 12) |
| `JsonListStore` | `FileView` create/read/destroy load/save parameterized by `filePath` only (`startsWith("[")` + `JSON.parse` semantics kept) |

Open/close: `SUPER+L` / `SUPER+R`, bar-end `HotZone` hover strips (5px, **400ms dwell** —
zero-dwell cross-fired the rival island), close button, `Esc`,
1s cursor-leave timer (skipped when `Settings.leftPanelLock/rightPanelLock`).
`Bar.qml` maps main-pill states to pages; side pills own their island `Loader`s
directly (no exclusivity anywhere — the window is always a full-width overlay).

### 1.4 Left island lazy tabs — `widgets/bar/islands/LeftIsland.qml`

`StackLayout` of 8 `Loader`s in `tabOrder` (`UserProfile, BooruViewer, ChatBot,
MangaViewer, SettingsWidget, CustomScripts, KeyBinds, Donations`). Each activates on first select
(`tabPrimed`) and **stays alive** to preserve scroll/page/chat state. `activeWidget`
exposes the live tab; `hostPanel` back-reference lets popups (e.g. booru dialog) veto
auto-hide via `popupHovered`. Island height is explicit (`bodyHeight`, full monitor
height); each widget scrolls internally. Tab bodies live in `widgets/leftPanel/`
(`BooruViewer/` is a subdir; `GeneralTab.qml` is a Settings sub-tab, not an island tab).

### 1.5 Services — `services/` (module `qs.services`, see `services/qmldir`)

All stateful logic is a QML singleton (`pragma Singleton`), UI files stay dumb
(exception: `Ipc` is a plain `IpcHandler` instantiated once in `shell.qml`):

| Singleton | Job |
|---|---|
| `BarState` | Pill state machine (1.2) |
| `Registry` | Island/window handle map (`left-island-<mon>`, `lock-screen`); `selectLeftTab()` |
| `Ipc` (non-singleton) | `qs ipc call …` targets: `toggleSearch/Control/Wallpaper/Bar/LeftPanel/RightPanel/Panel`, `showWidget`, `screenrecord <mode> <monitor>`, `lock …`, `clipboard event`, `toggleOverview`, `pulseNetwork`; brightness `incrementFor/decrementFor <monitor>` plus focused-monitor `increment/decrement/adjust/set/get` |
| `Launcher` | Query pipeline (`cb/note/apps/emoji/translate/units/arithmetic/URL/>palette/fuzzy`), `results`, `selectedIndex`, `quickAppOrder` + history files under `~/.cache/quickshell/launcher/` (`cb` binds `ClipboardService.history` live — never file-watch it, rename-replace freezes the watch) |
| `ScreenRecorder` | `wf-recorder` via `~/.config/hypr/scripts/screenrecord.sh`; `isRecording` is **polled** (`pgrep`, 1s) + 1.2s settle — lags reality ~2s, never use it for rapid toggle decisions |
| `Screenshot` | Owns `~/.config/hypr/scripts/screenshot.sh` spawns (`--now`/`--area`). Lives in a singleton on purpose: the bar's screenshot island is created/destroyed by the hover reveal, and destroying a Quickshell `Process` kills its child — an area selection outlives the island, so `grim` would never run |
| `Notifications` | Daemon mirror: ephemeral `popupToasts` vs retained `history`; `Recorder` toasts get red-dot treatment |
| `Settings` | Persisted config (`theme/Settings.qml`): bar/panel geometry, hotzones, `revealIn/OutPressure`, theme tokens (`uiRadius/uiPad/uiSpacing`), widgets, booru, apiKeys, waifu, hyprland mirror; `updateSetting/persist/schedulePersist/reload` |
| `Brightness` | Focused-monitor brightness for keybinds; `screenFor/setScreen` also target a named monitor for quick settings. Internal backlight via `brightnessctl` (inotify), external monitors via DDC/CI `ddcutil` (detected at boot + on screen hotplug). Optimistic `screen`, **coalesced** ddcutil writes (one process at a time, latest value wins) so held keys never pile up; `adjusted(monitorName)` signal (not `screenChanged`) drives that monitor's OSD pulse |
| `Weather, KeyboardLayout, SysInfo, VolumeWatcher` | Device/API polling singletons (`Weather` owns `fmt/fmtRaw/formatTime/formatDate` for `WeatherCard`; `SysInfo.bandwidth` is the single `bandwidth-loop` owner bound by `Bandwidth`) |
| `FastfetchPins, AutoWorkspaceSwitching, GlobalTheme, UserProfileState` | Boot/prefs singletons: pins self-heal + watcher, workspace auto-switch, global theme bridge, profile cache |
| `BooruActions, Supabase, WorkspaceIcons` | Domain helpers: booru download/fav actions, Supabase client config, workspace glyph map |
| `ClipboardService` | Clipboard history owner: spawns `wl-paste --watch qs … ipc call clipboard event` at boot (culls stale watchers first), per-event FIFO capture with 400ms offer-settle (image/png→jpeg→webp→uri-list→text/plain) into `~/.cache/quickshell/launcher/` history JSON + `clipboard-images/`; exposes live `history` for `cb` |

There is no `utils/` module (its logic was inlined; `JsonUtils, MonitorUtils,
SettingsUtils, TimeUtils, WindowManager` are gone).
`scripts/` holds `booru.py`, `chatbot.py`, `crypto.py`, `manga.py`,
`get-wallpapers.sh` (`--current` branch only; default listing + `translate.sh`,
`get-keybinds.sh`, `gen-video-thumbs.sh` went QML-native), `wallhaven.py`,
`cava/`, `auth-server-callback.py`, plus `sysmonitor.rs` (single-file Rust
bandwidth + system-resources daemon, rustc-gated into
`~/.cache/quickshell/binaries/`). Hyprland-side scripts live
**outside** this repo (`~/.config/hypr/scripts/screenrecord.sh`, `filemanager.sh`,
`screenshot.sh`); keybinds in `~/.config/hypr/config/bind.lua` shell out via `qsIpc`
(e.g. `SUPER+SHIFT+R` → `screenrecord now`).

### 1.6 Theme + motion — `theme/` (module `qs.theme`)

`Theme.qml` + `Settings.qml` singletons (see `theme/qmldir`). All widgets consume
`Theme.fg/bg/surface/accent/radius/fontSize/…` — never hardcode colors. Extra tokens:
`cardRadius` 8, `chipRadius` 6, `accentFg` white, `spacing` 8, `barContentHeight` 18.
Shared controls in `widgets/shared/` (module `qs.widgets.shared`, see its `qmldir`):
`AppButton`, `AppSlider`, `AppTextField`, `AppTextArea`, `AppCheckBox`, `AppComboBox`,
`AppSpinBox`, `AppKeybind`, `AppSegmentedControl`, `AppImage`, `AppVideo`, `AppBadge`,
`AppTooltip`, `AppProgress`, `AppMasonry`, `AppMasonryRow`, `SystemResourcesContent`,
`SmoothFlickable`, `SmoothListView`, `SmoothWheelHandler`.

Motion system (Caelestia-expressive port, pure QML — no C++ plugin):

- `Theme.anim`: durations (`small` 200, `normal` 400, `large` 600, `extraLarge` 1000,
  `fastSpatial` 350, `defaultSpatial` 500, `slowSpatial` 650, `fastEffects` 150,
  `defaultEffects` 200, `slowEffects` 300; all × `anim.scale`) + `Easing.BezierSpline`
  curves (`standard`, `standardAccel/Decel`, `emphasized` 2-segment,
  `emphasizedAccel/Decel`, `expressive{Fast,Default,Slow}{Spatial,Effects}`).
  Spatial = movement (slide/resize), Effects = fade/color.
- Shared primitives (`widgets/shared/`): `Anim` (`NumberAnimation` dispatcher, `enum Type`
  mirroring Caelestia, default `DefaultSpatial`), `AnchorAnim` (anchor twin, no effects
  types — use inside `Transition`), `CAnim` (fixed slow-effects `ColorAnimation` for
  `Behavior on color`), `AnimLoader` (crossfade `Loader`: FastEffects-out → swap →
  DefaultEffects-in).
- Rules: new `Behavior`s use `Anim`/`CAnim`, never hardcoded `NumberAnimation`
  durations; `Anim { duration: X }` keeps a custom duration with expressive easing.
  Deliberately bespoke (do not "unify"): toast `ViewTransition`s (`OutExpo` 380ms slide +
  stagger, `NotificationPopups.qml:80-141`) and the lock-card `SpringAnimation`
  (`LockSurface.qml:61-67`).
- Launcher highlight: `SmoothListView` with `highlightFollowsCurrentItem: false` +
  explicit `highlight` rect tracking `currentItem.y/height` (`Behavior on y { Anim {} }`);
  delegates stay transparent (see `LauncherPanel.qml`).

Widget dirs: `bar/` (pill + `Bandwidth/Battery/Brightness/Clock/Network/ResourceMonitor/Tray/Volume/Workspaces`
+ `islands/`), `controlPanel/ControlPanelBody.qml`, `launcher/` (`LauncherPanel`, `AppEntry`),
`lock/` (`LockScreen/LockSurface/LockContext`, WlSessionLock+PAM), `media/` (`MediaWidget/MediaWindow/MediaVideo/WaveVisualizer`),
`notifications/NotificationPopups.qml`, `rightPanel/` (Calendar/Crypto/CryptoItem/FormShell/JsonListStore/NotificationHistory/NotificationItem/ScriptTimer/SystemResources/TaskItem/Waifu),
`wallpaperPanel/WallpaperPanelBody.qml` (per-workspace picker + SDDM bg + QML-native video thumbs via WallpaperService),
`weather/` (`WeatherCard.qml` single UI, `WeatherWidget.qml` thin wrapper, `WeatherButton.qml`).

### 1.7 Scrolling — single tuning point

`SmoothWheelHandler.qml` owns **all** wheel physics (wheel deltas → `flick()`; native
deceleration/bounds do the gliding). `SmoothFlickable` and `SmoothListView` are thin
wrappers. Rules:

- Tune **only** `wheelScale` (default **28**; dense pages like Settings/KeyBinds use 24).
  `flickDeceleration: 1500`, `maximumFlickVelocity: 2500` stay fixed.
- NEVER wrap a `ListView` in a `SmoothFlickable`; never swap `ListView`→`Flickable+Repeater`.
- The handler already bubbles wheel events to the outer scroller when the inner target
  is at its edge — nested island scrollers (e.g. NotificationHistory inside RightIsland)
  depend on this; do not `accept` wheel events a target can't consume.

## 2. QML pitfalls seen in this repo (do not repeat)

1. **Missing `import qs.services` → silent no-op.** `services/Launcher.qml` called
   `Registry.selectLeftTab()` behind a `typeof Registry !== "undefined"` guard without
   importing the module — island-tab quickapps reordered history but never opened.
   Every file must import each module it touches; `typeof` guards hide the breakage.
2. **Flickable polish loops.** Inner widths must come from the Flickable's **explicit**
   width, never `parent.width` of the viewport (see `RightIsland.qml` comments) —
   content↔viewport negotiation wedges the scene at 0-width. Guard negative heights
   (a negative `Flickable.height` spins a silent polish loop).
3. **`Column.implicitHeight` vs `height`.** Plain `Column` positions children by explicit
   `height`; an `implicitHeight`-only delegate binding leaves `height == 0` (see
   `ChatBotWidget` message bubbles: `height: msgContent.implicitHeight + 16`).
4. **Delegate `MouseArea`s eat scroll.** A full-row `MouseArea` with hover-select
   (`LauncherPanel` results) fires selection storms mid-glide and competes with drag.
   Keep them wheel-transparent (`acceptedButtons: Qt.LeftButton`, `preventStealing: false`,
   `propagateComposedEvents: true`).
5. **Poll-derived state lags.** `ScreenRecorder.isRecording` trails reality by ~2s.
   Never branch rapid toggles on it without an optimistic/in-flight guard.
6. **HotZone dwell.** Hover strips must keep the 400ms dwell — instant `onEntered`
   swaps islands when the cursor crosses the bar leaving an open island.
7. **Shared island components: know their fidelity fixes.**
   `IslandHoverPin`'s root is the `HoverHandler` itself — a handler monitors its
   *parent*, so an `Item`-wrapped pin would deaden hover and close the island 1s
   after opening even while hovered. RightIsland's selector rail stays custom
   (release-time geometric reorder + `isDragging` auto-hide hold + drag-guard
   against toggle-on-release; live `onEntered` reorder is banned — reassigning
   the model mid-drag rebuilds the delegate under the cursor, kills the gesture,
   and can strand `isDragging` — same class as overview `onDropped` never firing
   for internal drags); its
   `WindowActions` did migrate to shared. `IslandWindowActions` keeps the existing
   icon buttons verbatim — `Settings.*Lock` is a bool, so the
   shared cluster copies the inline bool-toggle logic, not string labels.
   WallpaperIsland registers its *body* (not the island root) — `Ipc.wallpaperDiag`
   reads body probes off the handle.
8. **Swap model (`Bar.qml` stack).** Opens swap immediately and track the
   unfolding content rigidly — no grow-first pin, no stack crossfade;
   the width glides under it while `clip: true` on the pill cuts spill at
   the animating edge. Closes glide down via a shrink-only `Behavior on
   height` (growing tracks rigidly so it can't chase-and-lag the unfold).
   Cached `Loader`s (wallpaper, side pills) hide with `expand` untouched and reset silently
   while hidden, so reopens unfold with a single assignment — a 0-then-1
   replay in the same tick self-cancels the `Behavior` (retargets before
   anything renders) and must never be used. NEVER guard swaps behind
   `Connections onStateChanged` comparing against a bound `displayed`:
   the binding updates before signal handlers run, so the guard exits
   early forever and the logic silently never executes.
9. **`qmllint` 255 = env baseline, not a failure.** Files importing `qs.*` modules
   exit 255 with no output even on HEAD —
   quickshell types aren't visible to standalone lint. Real gate is a `bar.lua`
   restart + clean `/tmp/qs-bar-$USER.log`. Files without `qs.*` imports must
   still exit 0.
10. **Headless state checks via IPC.** No keypress needed:
   `qs -p ~/.config/quickshell/archeclipse ipc call bar toggleSearch <mon>`
   (also `toggleLeftPanel <mon>` / `toggleRightPanel <mon>` and
   `togglePanel wallpaper-switcher <mon>`, `togglePanel media-panel <mon>`,
   and `togglePanel user-panel <mon>`) take a monitor name. The latter opens
   the left panel on the `UserProfile` tab. Direct
   `toggleControl` and `toggleWallpaper` IPC calls use the focused monitor;
   `toggleOverview` and `pulseNetwork` remain shared. Then query `barDiag
   state` and grep the boot log for `typeerror|referenceerror`.
   Control auto-closes ~1s after open (HoverPin grace, never hovered) — a second
   `toggleControl` printing "open" again is the pin timer, not a stuck state.

11. **Never derive a parent's `visible` from a child's `visible` — Qt Quick
    propagates it.** Setting an item's `visible` to false writes false into
    **every descendant's** `visible` property; children only get their own values
    back when the parent shows again. So a container whose own visibility reads
    `child.visible` latches itself off for good: parent hidden -> child forced
    false -> the binding never sees true again. `rightSidePill` shipped that way
    (`visible: barVisible && (sideMedia.visible || recordingPiece.shown)`) and
    the mini media fill stayed invisible with a live player; forcing
    `sideMedia.visible = true` was undone within a frame.
    Bind the container to the contents' **inputs** instead
    (`sideMedia.hasPlayable`, `recordingPiece.shown`). Positioners still lay out
    on each child's *own* visibility, so `Row.implicitWidth` is unaffected.
12. **QML→Hyprland actions: only `hl.dsp.*` Lua dispatchers work.** `hyprctl dispatch`
    verbs and `Hyprland.dispatch` raw strings both evaluate as Lua and fail.
13. **Hyprland data keys/staleness.** `HyprlandToplevel.address` is bare hex;
    `hyprctl clients -j` emits `0x…` — normalize before matching keys.
    `lastIpcObject` is stale — poll `hyprctl clients -j` for live window geometry
    (overview does this).
14. **`on`+Capital property names parse as signal handlers** (`Theme.onAccent` had
    to become `accentFg` — the shell wouldn't load). Handlers have no default
    property: an inline `Timer { }` must live as a property value instead
    (`IslandHoverPin`).

## 3. Discord issue workflow

- Guild `ArchEclipse` (`1351531377467592828`). Live issues: **`#issues` forum**
  (`1370070459516846151`); **`#issues` text** (`1351531627846828047`) is discontinued
  — history only. `#suggestions` forum
  (`1370070987638313000`) is out of scope unless asked.
- **✅ semantics (owner: @lilayman): a check mark influences priority / likelihood-resolved,
  it does NOT strictly mean resolved.** Sort with ✅ as a discount, never as a filter.
  Always verify the reactor is lilayman (`475803658148380675`) before trusting it.
- The scout bot (`ArchEclipse Issue Scout`) **can** add ✅ via
  `PUT /channels/{thread}/messages/{msg}/reactions/✅/@me` — but only mark messages
  after the reporter/owner confirms the fix.
- **Discord API gotcha: never send a browser `User-Agent` with a Bot token.**
  `Mozilla/5.0` → Cloudflare `40333 internal network error` on all guild/channel
  endpoints. Use `DiscordBot (<url>, 1.0)`. (`/users/@me` works either way, which makes
  this misleading to debug.) The bundled `discord-mcp` plugin sets the bad UA —
  callers must override it.
- Read-only agent: `~/.config/opencode/agents/issue-scout.md` (Discord read tools only,
  repo `read/glob/grep/list` only, never send/edit). Plans/specs live **outside** the repo:
  `~/.config/opencode/superpowers/plans|specs/`. Global opencode config:
  `~/.config/opencode/opencode.jsonc` (discord MCP + `discord_*: deny`).
- Per-bug workflow: report (author, timestamp, message id, full content, thread) →
  implicate files with `path:line` → hypotheses with evidence → plan (files, exact
  edits, `qmllint` + SUPER+B + thread-repro verification, risks) → if incomplete,
  state what's missing instead of guessing.

## 4. Verification & repo hygiene

- `qmllint <touched files>` must pass (exit 0) before claiming anything —
  except files importing `qs.*` modules, where 255 with no output matches the
  HEAD baseline (see §2.9); those are gated by live reload instead.
- Reload with **SUPER+B** (= `~/.config/hypr/config/scripts/bar.lua`: SIGTERM→restart,
  singleton-guarded, logs to `/tmp/qs-bar-$USER.log`) and repro the exact thread
  steps; check off Discord message ids. For transition work, run the IPC matrix
  (§2.10) and confirm zero `typeerror|referenceerror` in the log.
- This checkout is a **dotfiles repo rooted at `$HOME`** — `git status` shows paths like
  `../../hypr/scripts/…`. Stage **only** the files you touched; never `git add .`.
- **Never capture or read screenshots.** No `grim`, no `hyprctl screenshot`, no
  `capture-readme.py`, no PNG crops — and never read image files back into context
  (bandwidth). Visual confirmation is the human's job: reload, look, and report.
  Verify behaviour from the log, `qmllint`, IPC responses, and numeric probes
  (`console.log` of geometry, `hyprctl layers`, IPC matrix), not from pixels.
- Instrument with temporary `console.log` probes when a visual bug needs a
  non-visual diagnosis; strip every probe before finishing (`grep -rn
  "console.log\|TEMP-PROBE\|\[probe\]" <touched files>` must come back empty).
- Do not commit unless explicitly asked.
- Commit style: `fix(scope): …` / `feat(scope): …` (see `git log --oneline`).
