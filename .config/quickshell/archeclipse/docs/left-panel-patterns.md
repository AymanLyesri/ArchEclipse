# Left Panel — reference patterns for migrating the rest of the bar

Proven on all 8 left-panel widgets (UserProfile, BooruViewer, ChatBot,
MangaViewer, SettingsWidget, CustomScripts, KeyBinds, Donations).
Follow these when migrating remaining bar widgets.

## 1. Widget structure

- One file per widget in `widgets/bar/`, registered in `widgets/bar/qmldir`
  (`WidgetName 1.0 WidgetName.qml`). No `qs.` prefix inside qmldir —
  `import qs.bar` covers it.
- Panel shells (`LeftPanel.qml`) own a `StackLayout` with ALL widgets
  instantiated (AGS `Gtk.Stack` equivalent). State (scroll, page, chat)
  survives tab switches. Order/children mirror AGS `*WidgetSelectors`.
- Tab fade: `OpacityAnimator on opacity` restarted from
  `onSelectedWidgetChanged` (AGS `.main-content > *` opacity-in 0.6s).
- Icons: Nerd-Font codepoints as `\u{F0xxx}` escapes, values copied from
  the AGS constants file (verify with `od -c`, never paste raw glyphs).
  Window-action icons live in AGS `utils/window.tsx` (expand F067,
  shrink F068, exclusivity F2D2, lock F023/F2FC, close F00D).

## 2. State management

- Shared state lives in `theme/Settings.qml` (mirror of AGS
  `cache/settings/settings.json`, same file both shells use).
- Selected tab persists: `Settings.leftPanelWidget` ↔ `leftPanel.widget`
  `{name}` key, guarded two-way sync (write-through on click +
  `Connections onLeftPanelWidgetChanged`). IPC `showWidget` writes
  Settings, never the panel property (keeps the binding intact).
- Nested mutation does NOT notify: after changing a field inside a `var`
  object, reassign a fresh copy (`Settings.x = JSON.parse(...)`) or
  touch the parent. `hyprSet()` demonstrates the reassign pattern.
- Auto-persist: `Connections` per property → `schedulePersist()` (250ms
  debounce). Every user-facing property needs an entry.
- Shared-file rule: persist the AGS leaf shape (`{name,value,min,max,type}`)
  for schema-driven sections (hyprland), or AGS renders nothing. Flush
  with `Settings.persist()` BEFORE spawning a script that
  read-modify-writes the same file (booru.py pattern).

## 3. Backend processes

- One `Component { id: xProc; Process {...} }` per operation, commands set
  at `createObject` time (never bake args into the Component).
- Exit-code rule: parse payloads in `onStreamFinished`, gate on `onExited`
  code. Per-instance `property string out` avoids cross-talk.
- Python scripts are the backend (chatbot.py, booru.py, manga.py own their
  files: history, bookmarks). QML never rewrites a script-owned file —
  reload it instead (ChatBot `loadMessages()` after reply).
- zenity cancel (exit 1) is silent, like AGS catching "exit status 1".
- Network gate: curl the endpoint with `--max-time`, bounded retries,
  then proceed regardless (AGS `waitForNetwork`).
- Change-gated polling for file state (no network on ticks); only refetch
  when the file text actually changed (AGS `monitorFile` equivalent).

## 4. Styling conventions

- Theme tokens only (`Theme.moduleBg/accent/accentBg/fg/fgDim/border/
  danger/...`). No hardcoded palette colors except AGS-verified brand
  values (donation gradients, Donations red `#f96854`/`#052d49`).
- Panel margins: AGS `marginTop/Bottom 5` + 5px side margin on the
  background rect, not the PanelWindow.
- Hover states on every button (bg + accent border/glow); ToolTips with
  600ms delay; 40px selector cells, 8px radii, 8px section spacing.
- AGS per-brand gradients: horizontal `Gradient` with hover-reversed stops
  (diagonal isn't available in QML Gradient).
- Circular avatars: rounded `Rectangle` + `clip:true`, never
  `layer.effect: Item {}` (no-op).
- Scroll overflow: AGS `scrolledwindow` → `Flickable` with explicit
  `contentWidth/Height` and `width: <flickable-id>.width` on content
  (never `parent.width` inside — polish-loop risk).

## 5. Hyprland interop (verified)

- dispatch takes ONE Lua-registry string: `hl.dsp.focus({workspace=N})`,
  `hl.dsp.exit()`, `hl.dsp.exec_cmd('...')`. Bare `hyprctl dispatch exec`
  / `workspace N` forms fail.
- Per-key lua files: nested tables `hl.config({ decoration = { ... } })`
  (flat `decoration:key = v` is invalid Lua and aborts the custom-dir
  load loop in `hyprland.lua`). Filenames match AGS (`${key}.lua`) so both
  shells overwrite the same file. Stale `quickshell-live-*` files deleted.
- Slider ranges/defaults copied from AGS `settings.constants.ts`
  (rounding 0..50, blur size/passes 0..10, shadow range/power 0..20,
  passes default 4).

## 6. Verification (required, not "Configuration Loaded")

- `qs -p <cfg> ipc call bar showWidget <Name> <mon>` for all 8 tabs +
  `togglePanel` + `hyprctl layers` (surface `xywh` is ground truth).
- `widgetState` probes: `selected/page/limit/imagesCount/bookmarkCount/
  fetchStatus`. Seed data via probes, then DELETE seeds from the file
  (persist debounce can resurrect in-memory state — verify file AND probe).
- Never trust the IPC reply alone; grep `hyprctl layers` for the surface.
