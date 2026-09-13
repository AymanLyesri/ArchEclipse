# AGENTS.md — ArchEclipse Quickshell Config

> Contributor guide for agentic workers. The AGS → Quickshell migration is
> **complete (2026-09-12)**: the shell is 100% Quickshell/QtQuick, the legacy
> AGS tree (`.config/ags/`) has been removed, and its scripts/assets were
> vendored into `.config/quickshell/archeclipse/scripts/` + `assets/`.
> Branch `quickshell-migration` is pending merge into `master`.

## 1. Architecture

### 1.1 Entry point — `shell.qml`

`ShellRoot` with per-monitor instantiation via `Variants { model: Quickshell.screens }`:

| Window | Source | Notes |
|---|---|---|
| `Bar` | `widgets/bar/Bar.qml` | Main pill; one instance per monitor |
| `BarHoverWindow` | `widgets/bar/BarHoverWindow.qml` | Edge strip that dwell-reveals an auto-hidden bar |
| `NotificationPopups` | `widgets/notifications/NotificationPopups.qml` | Toast popups, per monitor |
| `LockScreen` | `widgets/lock/LockScreen.qml` | Single scope; compositor creates one `WlSessionLockSurface` per screen (no `Variants`) |

Startup also `mkdir -p`s every cache dir `FileView` writes to (writes to missing dirs fail silently)
and primes `FastfetchPins` so its pins-watcher attaches at boot.

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

### 1.3 Islands (bar pill pages) — `widgets/bar/islands/`

All former side panels now live **inside the bar pill** as `BarState` pages, not separate windows:

| Island | State | Body |
|---|---|---|
| `LeftIsland.qml` | `left` | Former left panel via `StackLayout` of lazy `Loader`s (see 1.4) |
| `RightIsland.qml` | `right` | Enabled `Settings.rightPanelWidgets`, outer `SmoothFlickable` + per-widget inner scroll |
| `SearchIsland.qml` + `widgets/launcher/LauncherPanel.qml` | `search` | Launcher results (input lives in the island, results in the panel) |
| `ControlIsland` / `PlayerIsland` / `WeatherIsland` / `WallpaperIsland` / `RecordingIsland` / `SystemMonitorIsland` | pulses | Transient/utility pages |

Shared island helpers (`widgets/bar/islands/`, module `qs.widgets.bar.islands`):

| Component | Job |
|---|---|
| `IslandExpandClip` | Spring-unfold body clip (`expand` 0→1 drives clip + opacity + scale) |
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

`StackLayout` of 8 `Loader`s (`UserProfile, BooruViewer, ChatBot, MangaViewer,
SettingsWidget, CustomScripts, KeyBinds, Donations`). Each activates on first select
(`tabPrimed`) and **stays alive** to preserve scroll/page/chat state. `activeWidget`
exposes the live tab; `hostPanel` back-reference lets popups (e.g. booru dialog) veto
auto-hide via `popupHovered`. Island height is explicit (`bodyHeight`, full monitor
height); each widget scrolls internally.

### 1.5 Services — `services/` (module `qs.services`, see `services/qmldir`)

All stateful logic is a QML singleton (`pragma Singleton`), UI files stay dumb:

| Singleton | Job |
|---|---|
| `BarState` | Pill state machine (1.2) |
| `Registry` | Island/window handle map (`left-island-<mon>`, `lock-screen`); `selectLeftTab()` |
| `Ipc` | `qs ipc call …` targets: `toggleSearch/Control/Wallpaper/Bar/LeftPanel/RightPanel/Panel`, `showWidget`, `screenrecord <mode>`, `lock …` |
| `Launcher` | Query pipeline (`cb/note/apps/emoji/translate/units/arithmetic/URL/>palette/fuzzy`), `results`, `selectedIndex`, `quickAppOrder` + history files under `~/.cache/quickshell/launcher/` |
| `ScreenRecorder` | `wf-recorder` via `~/.config/hypr/scripts/screenrecord.sh`; `isRecording` is **polled** (`pgrep`, 1s) + 1.2s settle — lags reality ~2s, never use it for rapid toggle decisions |
| `Notifications` | Daemon mirror: ephemeral `popupToasts` vs retained `history`; `Recorder` toasts get red-dot treatment |
| `Settings` | Persisted config (`theme/Settings.qml`): bar/panel geometry, hotzones, widgets, booru, apiKeys, waifu, hyprland mirror; `updateSetting/persist/schedulePersist/reload` |
| `Weather, Brightness, KeyboardLayout, SysInfo, VolumeWatcher, …` | Device/API polling singletons (`Weather` owns `fmt/fmtRaw/formatTime/formatDate` for `WeatherCard`; `SysInfo.bandwidth` is the single `bandwidth-loop` owner bound by `Bandwidth`) |

`utils/` (`JsonUtils, MonitorUtils, SettingsUtils, TimeUtils, WindowManager`) is pure helpers.
`scripts/` holds `booru.py`, `cava/`, `auth-server-callback.py`. Hyprland-side scripts live
**outside** this repo (`~/.config/hypr/scripts/screenrecord.sh`, `filemanager.sh`,
`screenshot.sh`); keybinds in `~/.config/hypr/config/bind.lua` shell out via `qsIpc`
(e.g. `SUPER+SHIFT+R` → `screenrecord now`).

### 1.6 Theme — `theme/` (module `qs.theme`)

`Theme.qml` + `Settings.qml` singletons (see `theme/qmldir`). All widgets consume
`Theme.fg/bg/surface/accent/radius/fontSize/…` — never hardcode colors. Shared controls
in `widgets/shared/` (module `qs.widgets.shared`, see its `qmldir`): `AppButton`,
`AppSlider`, `AppTextField`, `AppCheckBox`, `AppComboBox`, `AppSpinBox`, `AppKeybind`,
`AppImage`, `AppTooltip`, `AppProgress`, `AppMasonry`, `SmoothFlickable`,
`SmoothListView`, `SmoothWheelHandler`.

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
   (`Drag.active`/`DropArea` reorder + `isDragging` auto-hide hold); its
   `WindowActions` did migrate to shared. `IslandWindowActions` keeps the existing
   icon buttons verbatim — `Settings.*Exclusivity`/`*Lock` are bools, so the
   shared cluster copies the inline bool-toggle logic, not string labels.
   WallpaperIsland registers its *body* (not the island root) — `Ipc.wallpaperDiag`
   reads body probes off the handle.

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

- `qmllint <touched files>` must pass (exit 0) before claiming anything.
- Reload with **SUPER+B** and repro the exact thread steps; check off Discord message ids.
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
