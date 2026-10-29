# AGENTS.md — ArchEclipse Quickshell

Quickshell/QtQuick shell for ArchEclipse on Hyprland. Pure QML + Python/Rust
helpers; no C++ plugin, no build step. This checkout is a **dotfiles repo rooted
at `$HOME`** (`git status` shows `../../` paths) and the shell lives in
`.config/quickshell/archeclipse/` — that directory is the project root for all
commands below.

## Layout

| Path | Contents |
|---|---|
| `shell.qml` | `ShellRoot`: one `Bar` + one `MediaWindow` per screen (`Variants`), plus `WelcomeScreen`, `SelectionOverlay` per screen, single-scope `LockScreen`, and the two plain `IpcHandler` hosts (`Ipc`, `CaptureIpc`). Also mkdirs every `FileView` cache dir and primes `FastfetchPins`, `PpdState`, `WallpaperService`, `ClipboardService`. |
| `services/` | Stateful singletons (`services/qmldir`); UI files stay dumb. |
| `theme/` | `Theme` (tokens + motion) and `Settings` (persisted config). |
| `widgets/bar/` | Pill, bar cells, and `islands/` (in-bar pages + side pills). |
| `widgets/leftPanel/` | Left island tabs (`SettingsWidget`, `KeyBindsWidget`, `ChatBotWidget`, `DonationsWidget`, `BooruViewer/`, …), `CategoryRail` hosts, row helpers (`HyprSliderRow`, `HyprToggleRow`, `DonationCard`). |
| `widgets/rightPanel/` | Right island widgets: `Calendar`, `NotificationHistory`, `SystemResources`, `Waifu`, `Media` (in `widgets/media`). |
| `widgets/shared/` | Buttons/inputs/scroll/motion primitives + `ModelEntry.js` (model-entry accessors). |
| `widgets/{launcher,lock,media,notifications,overview,controlPanel,wallpaperPanel,weather,welcome,selection,greeter}/` | Each is its own QML module (`qmldir`). `greeter/` ships to `/etc/xdg/quickshell/archeclipse-greeter` via `scripts/sync-greeter.sh`. |
| `scripts/` | Python helpers (`booru.py`, `manga.py`, `wallhaven.py`, `chatbot/`), `sysmonitor.rs` (rustc-gated into `~/.cache/quickshell/binaries/`), greeter helpers. Hyprland-side scripts (`screenrecord.sh`, `screenshot.sh`) live outside this repo in `~/.config/hypr/scripts/`. |

Modules are declared in `qmldir` files: a new QML file must be added there or
`import qs.<module>` cannot see it. JS helpers are imported relatively
(`import "ModelEntry.js" as ModelEntry`).

## Bar state machine — `services/BarState.qml`

One main pill per monitor + independent side pills. `activate(name, holdMs,
monitorName)` / `deactivate(name, monitorName)`; `holdMs > 0` auto-deactivates,
omitted/0 stays until deactivated. `resolveState()` (100 ms debounce) picks the
highest priority for that monitor:

```
default 0 < pulses 80 (volume/brightness/network/player/weather/system)
  < overview 85 < control 90 < wallpaper 95 < search 100
```

`left`/`right`/`recording` are **side pills**, not main-pill states:
`resolveState()` skips them, so the main pill never hijacks. Side-pill
visibility reads `BarState.isOpenFor(name, monitorName)`; the recording
indicator is scoped to `ScreenRecorder.targetMonitor` (never to `state`).
`default` is the permanent base; `expanded`/`compact` are legacy aliases.
Search has one owner monitor (Launcher is a singleton); control, wallpaper and
player are per-monitor and their buttons/IPC/hover handlers must pass the
monitor.

Rules that bite:
- Closing a side pill does not change the main pill's resolved state —
  close-guards listen to `onPanelStatesByMonitorChanged` + `isOpenFor()`
  (see `BooruViewer`), never `onStateChanged`.
- Omit `holdMs` for persistent islands. HotZone hover strips need their
  **400 ms dwell**; zero-dwell cross-fires when the cursor leaves an island.
- Side pills dock to the screen edges (`leftPanelPill`/`rightPanelPill`, 8 px
  margin) and the main pill centres in the remainder with a rigid `x`; pushes
  animate via `leftPush`/`rightPush`. `leftSidePill`/`rightSidePill` chain off
  the main pill for weather/media/recording. All use the pill-level
  `IslandExpandClip` wipe; their islands' own `expand` stays dormant at 1.
- Main-stack close-to-`default` uses the exit driver (fold `expand` 1→0, then
  `exitTimer` swaps; reopen mid-exit cancels). Island→island swaps are instant.
  Cached `Loader`s hide with `expand` untouched — never replay `0`→`1` in one
  tick (the `Behavior` retarget self-cancels).
- The main stack renders `DefaultBar` for `default`, `volume`, `brightness`,
  `player`, `network`, `recording` and `control` (those pulses live in the side
  pills/OSD/panel, so they never hijack the bar). `search`, `overview`,
  `weather`, `system` and `wallpaper` replace the stack body.

Island bodies in `widgets/bar/islands/`: `SearchIsland`+`LauncherPanel`,
`OverviewIsland`, `WallpaperIsland` (primed cached loader — no refetch on
reopen), `PlayerIsland`, `WeatherIsland`, `SystemMonitorIsland`, `OsdIsland`,
`ScreenshotIsland`, `RecordingIsland`, `ControlCard` (inside `DefaultBar`'s
center pill: `openT` grows the pill box itself). Shared helpers:
`IslandExpandClip` (clip+fade+scale unfold), `IslandHoverPin` (root **is** the
`HoverHandler`; 1 s open grace, hover pins the state), `IslandEscClose`,
`IslandWindowActions`, `IslandSideRail` (left only). Islands register in `Registry`
(`left-island-<mon>`, `right-island-<mon>`, `media-panel-<mon>`, `lock-screen`).

Left island is a `StackLayout` of 8 lazy `Loader`s that stay alive after first
select (`UserProfile, BooruViewer, ChatBot, MangaViewer, SettingsWidget,
CustomScripts, KeyBinds, Donations`). Height is explicit; each tab scrolls
internally. Settings/Key Binds share `CategoryNav` (active/focus + centred
scroll) + `CategoryRail` (labels come from the host model) + `CategorySection`;
clear the focus fade on manual scroll or island close (use `BarState`, since
`visible` is effective visibility and parent hides do not reliably re-fire it).
Right island renders enabled `Settings.rightPanelWidgets` — only the five names
above; `Settings.mergeRightPanelWidgets()` drops unknown entries.

## Services (`services/qmldir`)

`BarState`, `Registry`, `Launcher` (query pipeline + history in
`~/.cache/quickshell/launcher/`), `Settings`, `Brightness` (backlight via
`brightnessctl`, DDC/CI via coalesced `ddcutil`), `ScreenRecorder` (polled
`isRecording`, ~2 s lag — never branch rapid toggles on it), `Screenshot`
(owns the script process so area selection outlives the bar island),
`Notifications`, `ClipboardService` (`wl-paste --watch` capture + `copy()`),
`WallpaperService`, `Weather`, `SysInfo`, `VolumeWatcher`, `KeyboardLayout`,
`Lyrics`, `PpdState`, `AutoCompiling`, `AutoWorkspaceSwitching`,
`FastfetchPins`, `GlobalTheme`, `BooruActions`, `Supabase`, `UserProfileState`,
`WorkspaceIcons`. `Ipc`/`CaptureIpc` are plain `IpcHandler` hosts instantiated in
`shell.qml`, not singletons.

`Settings` owns persistence (`~/.cache/quickshell/settings/settings.json`),
`updateSetting(path, value)`, `schedulePersist()`, per-monitor panel overrides,
screenshot/recording settings, and the Hyprland subtree helpers `hyprGet`,
`hyprSet`, `buildLuaConfig`, `applyHyprlandSettingLive` (writes
`~/.config/hypr/config/custom/<leaf>.lua` + `hyprctl eval`; `hyprctl keyword`
is rejected on lua-parser builds). Section rows use `HyprSliderRow` /
`HyprToggleRow`; add a leaf by adding a row, not by copying the slider body.

## Theme + motion (`theme/`)

Consume `Theme.fg/bg/surface/accent/radius/fontSize/...` — never hardcode
colours. `Theme.anim` holds durations (× `anim.scale`) and Caelestia
`Easing.BezierSpline` curves. New `Behavior`s use `Anim` (movement) or `CAnim`
(colour), never a hardcoded `NumberAnimation`; `Anim { duration: X }` keeps a
custom duration with expressive easing. Bespoke on purpose: notification toast
`ViewTransition`s and the lock-card `SpringAnimation`.

Scrolling has one tuning point: `SmoothWheelHandler` (`wheelScale`, default 28;
dense pages 24). `SmoothFlickable`/`SmoothListView` are wrappers. Never wrap a
`ListView` in a `SmoothFlickable`, and never swap `ListView` for
`Flickable`+`Repeater`.

## QML pitfalls seen here (do not repeat)

1. **Missing `import qs.<module>` → silent no-op.** `typeof` guards hide it.
2. **Flickable polish loops.** Inner widths come from the Flickable's explicit
   width, never the viewport's `parent.width`; guard negative heights.
3. **`Column` lays out on `height`, not `implicitHeight`.** A delegate that only
   sets `implicitHeight` renders 0-high.
4. **Delegate `MouseArea`s must stay wheel-transparent** (`preventStealing:
   false`, `propagateComposedEvents: true`) or they eat scroll/drag.
5. **Poll-derived state lags** (`ScreenRecorder`); use optimistic/in-flight
   guards for rapid toggles.
6. **`IslandHoverPin` must not be wrapped in an `Item`** — the handler monitors
   its parent; wrapping deadens hover and the island closes after the grace.
7. **Never derive a parent's `visible` from a child's `visible`** (Qt propagates
   false into descendants and the binding latches off). Bind containers to the
   contents' *inputs*.
8. **Never guard swaps behind `Connections onStateChanged` against a bound
   `displayed`** — the binding updates first, so the guard exits forever.
9. **`on`+Capital property names parse as signal handlers** (`Theme.onAccent`
   became `accentFg`); handlers have no default property, so inline `Timer`s
   must be property values.
10. **`qmllint` exit 255 with no output is the env baseline** for files importing
    `qs.*` (Quickshell types are invisible to standalone lint). Real gate is a
    bar reload + clean log. Files without `qs.*` imports must exit 0.
11. **QML→Hyprland actions only via `hl.dsp.*`**; `Hyprland.dispatch` strings and
    `hyprctl dispatch` verbs are parsed as Lua and fail.
12. **Hyprland data:** `HyprlandToplevel.address` is bare hex while
    `hyprctl clients -j` emits `0x…` — normalise keys; `lastIpcObject` is stale,
    poll `hyprctl clients -j` for live geometry (overview does).
13. **Clipboard history files must be written in place** (no tmp+rename): an
    inode swap freezes Quickshell's file watching and `cb` binds a boot snapshot.

## Verify

```sh
cd ~/.config/quickshell/archeclipse
qmllint <touched files>          # 0, or 255 for qs.* importers
lua ~/.config/hypr/config/scripts/bar.lua   # SUPER+B: stop + relaunch, truncates the log
# headless state checks (monitor name from `hyprctl monitors -j`):
Q="qs -p ~/.config/quickshell/archeclipse ipc call"
$Q bar toggleSearch DP-2 ; $Q bar barDiag state
$Q bar toggleLeftPanel DP-2 ; $Q bar toggleRightPanel DP-2
$Q bar toggleControl ; $Q bar togglePanel wallpaper-switcher DP-2
$Q bar togglePanel media-panel DP-2 ; $Q bar togglePanel user-panel DP-2
$Q bar toggleOverview DP-2 ; $Q bar toggleBar DP-2
$Q bar showWidget SettingsWidget DP-2     # left-island tab by name
$Q bar widgetState selected DP-2          # live widget probe
grep -in "typeerror|referenceerror|is not defined" /tmp/qs-bar-$USER.log
```

`bar barDiag state`, `notifDiag`, `playerDiag`, `playerIconDiag`, `timerDiag`,
`launcherDiag`, `wallpaperDiag`, `vitals` are QA probes — use them instead of
adding prints. `bar settingsSet <key> <base64-json>` is the supported way to push
a settings leaf from outside (writing `settings.json` directly races `persist()`).
`toggleControl` auto-closes ~1 s after opening unless hovered (HoverPin grace) —
a second call reporting "open" again is that pin, not a stuck state. Instrument
with temporary `console.log`/IPC probes only, and strip every probe before
finishing (`grep -rn "console.log\|TEMP-PROBE" <touched files>` empty).

Lock: `ipc call lock activate|focus`. Brightness:
`brightness increment|decrement|adjust|set|get[For <monitor>]`. Clipboard watcher:
`clipboard event`. Welcome: `welcome open|close|toggle[On <monitor>]`.

## Repo hygiene

- Stage only the files you touched; never `git add .`. Do not commit unless
  asked. Commit style: `fix(scope): …` / `feat(scope): …`.
- Never capture or read screenshots; verify from logs, lint, IPC results and
  numeric probes. Visual confirmation is the human's job.
- Don't reintroduce removed dead subsystems: the right-panel Crypto/ScriptTimer
  widgets (with `Crypto*`, `TaskItem`, `RightPanelCard`, `FormShell`,
  `JsonListStore`), `WaveVisualizer`, `KeyboardLayoutWidget`, `AnchorAnim`,
  `AnimLoader` and `scripts/crypto.py` are gone. `Settings` no longer persists a
  `crypto` block.
- Deferred, don't retry: Caelestia `Blobs/` C++ SDF goo (needs a CMake toolchain
  this repo does not have). Rewriting `Settings.persist()/reload()` around the
  leaf schema is only acceptable if a live round-trip proves byte-identical
  `settings.json`; the two on-disk key orders (`typeFirst`) exist for that.

## Discord issue workflow

Guild `ArchEclipse` (`1351531377467592828`). Live issues: **`#issues` forum**
(`1370070459516846151`); the `#issues` text channel (`1351531627846828047`) is
history only. `#suggestions` (`1370070987638313000`) is out of scope unless
asked.

- ✅ means "priority/likelihood-resolved" for owner @lilayman
  (`475803658148380675`), **not** "closed". Sort with it as a discount, never a
  filter; verify the reactor before trusting it. The scout bot may add ✅ only
  after the reporter/owner confirms the fix.
- Never send a browser `User-Agent` with a Bot token (Cloudflare `40333`); use
  `DiscordBot (<url>, 1.0)`. `/users/@me` works either way, which is misleading.
- Read-only agent: `~/.config/opencode/agents/issue-scout.md`; plans/specs live
  outside the repo. Per bug: report (author, timestamp, message id, thread) →
  implicate `path:line` → hypotheses with evidence → plan (edits, lint + SUPER+B
  + thread repro) → say what is missing instead of guessing.
