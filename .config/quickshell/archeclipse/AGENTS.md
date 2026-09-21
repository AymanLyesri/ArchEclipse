# AGENTS.md — ArchEclipse Quickshell Config

> Contributor guide for agentic workers. The AGS → Quickshell migration is
> **complete (2026-09-12)** and **merged into `master`** (PR #308): the shell
> is 100% Quickshell/QtQuick, the legacy AGS tree (`.config/ags/`) has been
> removed, and its scripts/assets were vendored into
> `.config/quickshell/archeclipse/scripts/` + `assets/`.

## 1. Architecture

### 1.1 Entry point — `shell.qml`

`ShellRoot` with per-monitor instantiation via `Variants { model: Quickshell.screens }`:

| Window | Source | Notes |
|---|---|---|
| `Bar` | `widgets/bar/Bar.qml` | Main pill; one instance per monitor |
| `BarHoverWindow` | `widgets/bar/BarHoverWindow.qml` | Edge strip that dwell-reveals an auto-hidden bar |
| `NotificationPopups` | `widgets/notifications/NotificationPopups.qml` | Toast popups, per monitor |
| `LockScreen` | `widgets/lock/LockScreen.qml` | Single scope; compositor creates one `WlSessionLockSurface` per screen (no `Variants`) |

Startup also `mkdir -p`s every cache dir `FileView` writes to (writes to missing dirs fail silently):
`~/.cache/quickshell/{settings,booru,launcher,script-timer,crypto,chatbot,auth,manga,wallpaper-thumbs}`,
`~/.cache/cwal`, `~/.config/wallpapers/{custom,wallhaven,defaults}`, `~/.config/fastfetch/cache`
— and primes `FastfetchPins` so its pins-watcher attaches at boot.

### 1.2 Bar state machine — `services/BarState.qml` (singleton)

One pill, many states. `activate(name, holdMs)` / `deactivate(name)` manipulate `activeStates`;
`resolveState()` picks the highest-priority entry (debounced 100ms). Priorities:

```
default 0 < recording 40 < pulses 80 (volume/brightness/network/player/weather/system)
  < control 90 < left/right 93 < wallpaper 95 < search 100
```

Rules that bite:
- `left`/`right` are **mutually exclusive** — activating one deactivates the other.
- `left`/`right` (93) sit **above** `default` (0): while any island is open the "top bar"
  never resolves. Users must close/ESC **all** open islands to get the bar back.
- `default` is the permanent base and cannot be deactivated. `expanded`/`compact` are
  legacy aliases for `default`.
- Omit `holdMs` (or `0`) = persistent until explicitly deactivated. `holdMs > 0` = auto-deactivate timer.
- **Close-to-`default` animates (2026-09-21 exit driver, `Bar.qml` stack):** when the
  target family is `default` and the outgoing island is exit-capable (`expand` prop),
  `displayed` holds while the island folds `1→0`, then `exitTimer` (`Theme.anim.normal`)
  swaps. `exitingFrom` keeps cached `Loader`s visible through the fold. Reopen mid-exit
  (`s === displayed`) cancels the timer and restores `expand = 1`; any *other* new state
  supersedes the exit (timer stopped, `exitingFrom` cleared). Island→island switches and
  same-family pulses swap instantly, as before.

### 1.3 Islands (bar pill pages) — `widgets/bar/islands/`

All former side panels now live **inside the bar pill** as `BarState` pages, not separate windows:

| Island | State | Body |
|---|---|---|
| `LeftIsland.qml` | `left` | Former left panel via `StackLayout` of lazy `Loader`s (see 1.4) |
| `RightIsland.qml` | `right` | Enabled `Settings.rightPanelWidgets`, outer `SmoothFlickable` + per-widget inner scroll |
| `SearchIsland.qml` + `widgets/launcher/LauncherPanel.qml` | `search` | Launcher results (input lives in the island, results in the panel) |
| `ControlIsland` (`widgets/controlPanel/ControlPanelBody.qml`) / `PlayerIsland` (`widgets/media/MediaWidget.qml`) / `WeatherIsland` (`widgets/weather/WeatherCard.qml`) / `WallpaperIsland` (`widgets/wallpaperPanel/WallpaperPanelBody.qml`) / `RecordingIsland` / `SystemMonitorIsland` | pulses | Transient/utility pages — **all** islands now carry an `expand` 0→1 driver + `IslandExpandClip` unfold (Player/Weather/System/Overview/Recording gained it 2026-09-21; previously static snap + hover timer only) |

Shared island helpers (`widgets/bar/islands/`, module `qs.widgets.bar.islands`):

| Component | Job |
|---|---|
| `IslandExpandClip` | Emphasized-unfold body clip (`expand` 0→1 drives clip + opacity + scale; `Behavior on expand { Anim { type: Anim.Emphasized } }`) |
| `IslandHoverPin` | Hover-pin: hover stops the 1s leave timer + pins the state persistent; leave restarts it (root is the `HoverHandler` itself — see §2.7) |
| `IslandEscClose` | 1×1 focused `Esc` grabber deactivating the listed states |
| `IslandWindowActions` | Bottom icon-button cluster (expand/shrink/exclusivity/lock/close); `side` switches the `Settings` keys, labels kept verbatim |
| `IslandSideRail` | 48px tab rail with 40px cells (`model`/`currentIndex`/`selected`; delegate declares `required property int index` — Qt6 withholds it otherwise); Left rail only — RightIsland keeps its custom drag rail (see §2.7) |
| Island registry | Islands `register(key, …)` in `onCompleted`, unregister bare alias + keyed entry in `onDestruction` (no helper — `destroyed` is not connectable in this engine, verified 2026-09-13) |

Shared right-panel helpers (`widgets/shared/` + `widgets/rightPanel/`, modules `qs.widgets.shared` + `qs.widgets.rightPanel`):

| Component | Job |
|---|---|
| `Card` | Surface/radius/border shell (`contentMargins`/`contentSpacing`, default 12/8); delegates override `color`/`border.color`/`radius` at use sites |
| `RightPanelCard` | Header (`title`, `+`/`close`) + add-form `Loader` + guarded `SmoothFlickable` list; owns shared `formatNextRun` (hosted delegates walk up via `objectName`) |
| `FormShell` | Add/edit form shell (surface/cardRadius, min 300/pref 350, margins 16/spacing 12) |
| `JsonListStore` | `FileView` create/read/destroy load/save parameterized by `filePath` only (`startsWith("[")` + `JSON.parse` semantics kept) |

Open/close: `SUPER+L` / `SUPER+R`, bar-end `HotZone` hover strips (5px, **400ms dwell** —
zero-dwell cross-fired the rival island, fixed 2026-09-12), close button, `Esc`,
1s cursor-leave timer (skipped when `Settings.leftPanelLock/rightPanelLock`).
`Bar.qml` maps states to pages (`recordingPage`, etc.).

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
| `Ipc` (non-singleton) | `qs ipc call …` targets: `toggleSearch/Control/Wallpaper/Bar/LeftPanel/RightPanel/Panel`, `showWidget`, `screenrecord <mode>`, `lock …` |
| `Launcher` | Query pipeline (`cb/note/apps/emoji/translate/units/arithmetic/URL/>palette/fuzzy`), `results`, `selectedIndex`, `quickAppOrder` + history files under `~/.cache/quickshell/launcher/` |
| `ScreenRecorder` | `wf-recorder` via `~/.config/hypr/scripts/screenrecord.sh`; `isRecording` is **polled** (`pgrep`, 1s) + 1.2s settle — lags reality ~2s, never use it for rapid toggle decisions |
| `Notifications` | Daemon mirror: ephemeral `popupToasts` vs retained `history`; `Recorder` toasts get red-dot treatment |
| `Settings` | Persisted config (`theme/Settings.qml`, ~1270 lines): bar/panel geometry, hotzones, `revealPressure`, widgets, booru, apiKeys, waifu, hyprland mirror; `updateSetting/persist/schedulePersist/reload` |
| `Weather, Brightness, KeyboardLayout, SysInfo, VolumeWatcher` | Device/API polling singletons (`Weather` owns `fmt/fmtRaw/formatTime/formatDate` for `WeatherCard`; `SysInfo.bandwidth` is the single `bandwidth-loop` owner bound by `Bandwidth`) |
| `FastfetchPins, AutoWorkspaceSwitching, GlobalTheme, UserProfileState` | Boot/prefs singletons: pins self-heal + watcher, workspace auto-switch, global theme bridge, profile cache |
| `BooruActions, Supabase, WorkspaceIcons` | Domain helpers: booru download/fav actions, Supabase client config, workspace glyph map |

There is no `utils/` module (deleted 2026-09-13 — `JsonUtils, MonitorUtils,
SettingsUtils, TimeUtils, WindowManager` are gone; logic was inlined).
`scripts/` holds `booru.py`, `chatbot.py`, `crypto.py`, `manga.py`, `translate.sh`,
`get-keybinds.sh`, `get-wallpapers.sh`, `wallhaven.py`, `gen-video-thumbs.sh`,
`cava/`, `auth-server-callback.py`, plus C loops (`bandwidth-loop.c`,
`system-resources-loop.c`). Hyprland-side scripts live
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

Motion system (Caelestia-expressive port, pure QML, 2026-09-21 — no C++ plugin):

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
`lock/` (`LockScreen/LockSurface/LockContext`, WlSessionLock+PAM), `media/` (`MediaWidget/MediaWindow/MediaVideo/WaveVisualizer`
— `PlayerWidget.qml` deleted), `notifications/NotificationPopups.qml`, `rightPanel/` (Calendar/Crypto/CryptoItem/FormShell/JsonListStore/NotificationHistory/NotificationItem/ScriptTimer/SystemResources/TaskItem/Waifu — `StackItem.qml` deleted),
`wallpaperPanel/WallpaperPanelBody.qml` (per-workspace picker + SDDM bg + video thumbs via `gen-video-thumbs.sh`),
`weather/` (`WeatherCard.qml` single UI, `WeatherWidget.qml` thin wrapper, `WeatherButton.qml`).

### 1.7 Scrolling — single tuning point

`SmoothWheelHandler.qml` owns **all** wheel physics (wheel deltas → `flick()`; native
deceleration/bounds do the gliding). `SmoothFlickable` and `SmoothListView` are thin
wrappers. Rules:

- Tune **only** `wheelScale` (default **28**; dense pages like Settings/KeyBinds use 24).
  `flickDeceleration: 1500`, `maximumFlickVelocity: 2500` stay fixed.
  (History: default was 60 → one notch fired ~3600 velocity, a page-jump per tick.)
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
7. **Shared island components: know their fidelity fixes (2026-09-13).**
   `IslandHoverPin`'s root is the `HoverHandler` itself — a handler monitors its
   *parent*, so an `Item`-wrapped pin would deaden hover and close the island 1s
   after opening even while hovered. RightIsland's selector rail stays custom
   (release-time geometric reorder + `isDragging` auto-hide hold + drag-guard
   against toggle-on-release; live `onEntered` reorder is banned — reassigning
   the model mid-drag rebuilds the delegate under the cursor, kills the gesture,
   and can strand `isDragging`, same class as overview `onDropped` never firing
   for internal drags, seen 2026-09-15); its
   `WindowActions` did migrate to shared. `IslandWindowActions` keeps the existing
   icon buttons verbatim — `Settings.*Exclusivity`/`*Lock` are bools, so the
   shared cluster copies the inline bool-toggle logic, not string labels.
   WallpaperIsland registers its *body* (not the island root) — `Ipc.wallpaperDiag`
   reads body probes off the handle.
8. **Exit-driver invariants (`Bar.qml` stack, 2026-09-21).** `exitItemFor()` only
   resolves transient items while `displayed` still names them — call `driveExit`
   *before* swapping. Any new state stops `exitTimer` and clears `exitingFrom`
   (supersede); the `s === displayed` guard instead restores `expand = 1`.
   Cached `Loader`s need `|| exitingFrom === "<state>"` on `visible` or the fold
   plays on a hidden subtree. Exit fires only for family-`default` targets —
   do not extend it to island→island without re-checking the grow-first
   `widthOverride` sequencing.
9. **`qmllint` 255 = env baseline, not a failure.** Files importing `qs.*` modules
   exit 255 with no output even on HEAD (verified via `git show HEAD:…` copies) —
   quickshell types aren't visible to standalone lint. Real gate is a `bar.sh`
   restart + clean `/tmp/qs-bar-$USER.log`. Files without `qs.*` imports must
   still exit 0.
10. **Headless transition tests via IPC.** No keypress needed:
   `qs -p ~/.config/quickshell/archeclipse ipc call bar toggleSearch|toggleControl|toggleOverview|toggleWallpaper|toggleLeftPanel|toggleRightPanel <mon>|pulseNetwork`
   + `barDiag state`; then grep the boot log for `typeerror|referenceerror`.
   Control auto-closes ~1s after open (HoverPin grace, never hovered) — a second
   `toggleControl` printing "open" again is the pin timer, not a stuck state.

## 3. Discord issue workflow

- Guild `ArchEclipse` (`1351531377467592828`). Live issues: **`#issues` forum**
  (`1370070459516846151`); **`#issues` text** (`1351531627846828047`) is discontinued
  (pinned notice 2025-05-08) — history only. `#suggestions` forum
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
- Reload with **SUPER+B** (= `~/.config/hypr/scripts/bar.sh`: SIGTERM→restart,
  singleton-guarded, logs to `/tmp/qs-bar-$USER.log`) and repro the exact thread
  steps; check off Discord message ids. For transition work, run the IPC matrix
  (§2.10) and confirm zero `typeerror|referenceerror` in the log.
- This checkout is a **dotfiles repo rooted at `$HOME`** — `git status` shows paths like
  `../../hypr/scripts/…`. Stage **only** the files you touched; never `git add .`.
- Do not commit unless explicitly asked.
- Commit style: `fix(scope): …` / `feat(scope): …` (see `git log --oneline`).

## 5. Session history (recurring workstreams)

- `quickshell-migration` branch: AGS→Quickshell port, widget-by-widget (BooruViewer,
  lockscreen, RightIsland, notifications daemon, launcher pipeline, bar states).
  Completed 2026-09-12: legacy `.config/ags/` tree removed; needed scripts
  (`chatbot/manga/crypto/translate/get-keybinds/get-wallpapers`, C loops) +
  assets (`emojis.json`, default avatar) vendored into quickshell `scripts/` +
  `assets/`; runtime paths moved to `~/.cache/quickshell/` + `/tmp/quickshell-$USER`.
- 2026-09-11 lockscreen: `UserPanel` overlay → real `WlSessionLock`+PAM
  (`widgets/lock/`, spec + plan under `~/.config/opencode/superpowers/`).
- 2026-09-12 scrolling + islands + launcher: `wheelScale` 60→28, HotZone 400ms dwell,
  `import qs.services` in `Launcher.qml`; ✅ applied to 10 migration-thread messages.
- Chronic hotspots: scroll physics, island hover/ESC interaction, launcher result
  actions, notification history viewports, icon assets, recorder script races.
- 2026-09-13 refactor P0: deleted dead `utils/` (5 files), `StackItem.qml`, `PlayerWidget.qml`, trivial imports/`className`/`widgetWidth`/`timestamp`/debug logs; added `Theme.cardRadius/chipRadius/accentFg`. (`qmllint` per-file verified — 4 files share pre-existing env-255; SUPER+B reload pending.)
- 2026-09-13 refactor P1: shared island components (IslandExpandClip/HoverPin/EscClose/WindowActions/SideRail, Registry.trackIsland); 8 islands migrated, dwell/leave/ESC semantics preserved. (qmllint per-file verified; SUPER+B reload pending.)
- 2026-09-13 reload fixes: `Theme.onAccent` → `accentFg` (`on`+Capital parses as signal handler — shell wouldn't load); `IslandHoverPin` Timer is a property value (handlers have no default property); dropped `trackIsland` (`destroyed` not connectable — keyed unregister moved into islands' `onDestruction`); rail delegate declares `required property int index`.
- 2026-09-13 refactor P2: WeatherCard single UI + Weather formatters; Bandwidth binds SysInfo.bandwidth (one bandwidth-loop process). (qmllint per-file verified; SUPER+B reload pending.)
- 2026-09-13 refactor P3 (partial): Settings `_defaults` + `_hyprlandLeafSchema` extraction, apiKeys init dedup, hyprland persist/reload loops (node-verified byte-identical round-trip on live settings.json), Connections 47→41. Full `_schema` rewire + `fmt` move deferred (need live SUPER+B; `fmt` consumers in Clock.qml out of scope). 1055 → 970 lines. (qmllint 255 matches HEAD baseline; SUPER+B round-trip pending.) Kept handlers: 41 direct-writer on*Changed; deleted only onNotifDnd/AutoWorkspaceSwitching/ProfilePicturePath/WallpaperCategory/WeatherCity/ChatBotImageGenerationChanged (updateSetting-path only; enumeration in task-5 report).
- 2026-09-13 refactor P4: shared Card/RightPanelCard/FormShell/JsonListStore + shared formatNextRun; Crypto/ScriptTimer keep only delegates + fields. (qmllint per-file verified; SUPER+B reload pending.)
- 2026-09-14/15 master: merged `quickshell-migration` (#308); wallpaper panel rewrite (per-workspace picker + SDDM bg + `wallhaven.py`/`gen-video-thumbs.sh` video thumbs, flicker fix, phased progress); `revealPressure` rollout across `BarHoverWindow/HotZone/DefaultBar/Volume/Brightness/Network/ResourceMonitor/WeatherButton`; media `PlayerWidget→MediaWidget/MediaWindow/MediaVideo/WaveVisualizer`; `WeatherIsland/WeatherWidget` thinned to `WeatherCard` wrapper; new shared `AppBadge/AppMasonryRow/AppVideo/AppSegmentedControl/AppTextArea/SystemResourcesContent` + `CryptoItem/NotificationItem`; `supabase/` functions+migrations added.
- 2026-09-15 features: workspace overview as `OverviewIsland` (`BarState "overview"` pri 85, `Ipc.toggleOverview`, `SUPER+SHIFT+TAB` in `hypr/config/bind.lua`) rebuilt end-4-style: 3×2 live pager (`widgets/overview/OverviewBody.qml` + `OverviewPreview.qml` with `ScreencopyView live:true`, geometry from `hyprctl clients -j` poll since `lastIpcObject` is stale, drag windows between `DropArea` cards → `movetoworkspace`, click focus / middle-click close, island widened 660→920, hover-leave close via shared `IslandHoverPin` (new optional `leaveDelay`, overview binds `Settings.revealPressure`; pin grants a 1s open-grace on creation so keybind-opened islands survive cursor travel — without it a 250ms pressure closes the island before arrival, seen 2026-09-15; new `armOnCreation` opt-out, overview sets false so it never closes before first hover); card clicks focus + close, tile clicks stay open (leave/toggle/Esc all close); all-10 5×2 grid with fully derived heights (`gridH` from `cardH`, no hardcoded px — leaves report implicitHeight 0 so arithmetic-from-metrics is the pattern); actions via `hl.dsp.*` Lua dispatchers (`hyprctl dispatch` verbs and `Hyprland.dispatch` raw strings both evaluate as Lua and fail — proven via IPC probe); drop target resolved geometrically at release (`DropArea.onDropped` never fires for internal drags); geometry keys normalized (`HyprlandToplevel.address` is bare-hex vs hyprctl `0x…` — root-caused via live IPC diag 2026-09-15); Network (Quickshell.Networking + nmcli: status, Wi-Fi toggle, rescan, top-6 AP connect) + Bluetooth (bluetoothctl: power, device list, connect, 8s poll) share one collapsible `Card` dropdown ("Connectivity") in `ControlPanelBody` built from shared `AppCheckBox/AppButton` + Theme-only styling.
- 2026-09-21 transition rewrite (Caelestia-expressive motion, pure QML — no C++): `Theme.anim` tokens (10 durations × scale + 12 BezierSpline curves) + shared `Anim/AnchorAnim/CAnim/AnimLoader` in `widgets/shared/`; `Bar.qml` exit driver (close-to-`default` folds `expand` 1→0 under `exitingFrom`, `exitTimer` = `anim.normal`, mid-exit reopen retargets, other states supersede); `IslandExpandClip` → `Emphasized`; Player/Weather/System/Overview/Recording gained `expand`+unfold (were static snap); pill width/shift + stack crossfade + `AppSegmentedControl`/`AppProgress`/`SystemResourcesContent`/`AppButton`/`AppTooltip` + control-card heights on tokens; launcher sliding highlight (`highlightFollowsCurrentItem: false` + `currentItem.y/height` rect). Deliberately untouched: toast `OutExpo` ViewTransitions + lock `SpringAnimation`. Blob goo (Caelestia `Blobs/` ~1700-line C++ SDF plugin) investigated and **deferred** — needs a CMake toolchain + plugin install this repo has none of; motion ships without it. Verified: `qmllint` exit 0 where env allows (255 = HEAD baseline), 2× `bar.sh` restarts clean, full IPC toggle matrix with zero `typeerror|referenceerror`.
