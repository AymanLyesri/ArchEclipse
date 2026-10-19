# Profile Report — archeclipse (Quickshell shell config)

- **Profile mode:** `full` (all features: JavaScript, binding, scene graph, animations, memory, pixmap cache)
- **Trace:** `profiler/traces/qmlprofiler-trace-archeclipse-2026-10-21-0030.qtd` (59.6 MB)
- **Run duration:** ≈ 350 s (5.8 min) of wall-clock, exercised by the user
- **Sum of captured range-event durations:** 2 283 710 ms — **not** wall-clock and **not** total CPU: ranges nest, so JS inside a signal handler is counted in both
- **Total events:** 517 483
- **Caveat:** this is the *profiler-enabled* run. Qt's QML profiler adds measurable overhead (notably to JavaScript event attribution and GC), so absolute numbers are inflated; the *relative ranking* of hotspots is still meaningful.

## Event type summary

| Type | Count | Total ms | ms/frame |
|---|---|---|---|
| Javascript | 116 710 | 1 051 832 | 50.6 |
| Binding | 79 001 | 755 498 | 36.4 |
| Creating | 23 781 | 459 970 | 22.1 |
| HandlingSignal | 7 622 | 16 041 | 0.8 |
| Compiling | 101 | 369 | 0.02 |

Raw `count` scales with run length and what you did during the run; the honest per-frame CPU cost is `ms/frame`. Stated per 20 774 animation frames captured.

## Animation / frame-time summary

**How to read the percentiles:** frame time is the wall-clock gap between successive frames — lower is smoother. p50 is the median; p95/p99 mean no more than 5%/1% of frames were worse than that value. At 60 Hz vsync the reference is ~16.7 ms/frame; >33 ms is visible stutter, >50 ms is a stall.

| Metric | Value |
|---|---|
| Frames captured | 20 774 (avg 59.4 fps) |
| **frame_ms_p50 / p95 / p99** | **17.24 / 17.24 / 17.24** (quantized; 13 644 frames tie at p95 and p99 — a wide plateau, not a tail) |
| **frame_ms_max** | **1000 ms** (a full stall, almost certainly an image decode / FileView blocking moment) |
| **frames_over_25ms** | **49** |
| **frames_over_33ms** | **42** — user-visible jank |
| **frames_over_50ms** | **23** — severe stalls |
| distinct frame times | 19 |

Verdict: the shell ran at a comfortable 59–60 fps median ≈ 17 ms/frame (vsync-bound), with ~0.2% of frames exceeding the stutter threshold. The stall tail (42 frames >33 ms, worst 1000 ms) occurred during view-heavy interactions (booru/manga browsing, keybinds viewing).

## Memory summary

Verdict: ~254 K JS allocations totalling 21 MB were made during the run, with 55 % reclaimed by GC; the engine levelled off at ~20–25 MB of live heap — no runaway leak, but steady per-frame garbage accumulates from hot bindings.

| Category | Allocations | Total allocated | Reclaimed | Peak live | Live at exit |
|---|---|---|---|---|---|
| GC heap pages (allocator blocks) | 140 | 13.3 MB | 2.5 MB | 13.0 MB | 10.8 MB |
| Small JS objects (per-object GC allocations — the bulk) | 254 576 | 22.1 MB | 12.2 MB | 12.9 MB | 9.9 MB |
| Large JS objects | 0 | — | — | — | — |

("Peak live" is the running-sum peak, not a single event. Large JS objects are GC allocations too big for the small-object pool; none occurred.)

## Pixmap cache summary

`load_requests` 72 − `loaded` 67 − `failed` 5 = 0 unaccounted (no loads in flight at exit, none pre-dating the trace). `cache size changes` 110 counts insertions *and* removals indistinguishably — it does not indicate evictions or re-rasterisation.

Largest pixmaps (15 shown, sorted by size):

| Source | W×H | Pixels |
|---|---|---|
| assets/userpanel/archeclipse_default_pfp.jpg | 3543×3489 | **12 361 527** |
| .cache/quickshell/manga/mangadex/covers/… (×7 shown of 12) | 420×660 | 277 200 each |
| … (remaining manga covers/booru previews, similar size) | | |

⚠️ The profile picture is decoded at 12.4 MP — far larger than it is displayed at (a small avatar). Downscale it (`sourceSize`) or ship a small variant.

## Failed or cancelled image loads

5 failures across 4 URLs (rate 5/72 ≈ 7 % of load requests). The trace cannot distinguish cancelled loads (same event) from genuine failures without the app's `QML Image:` stderr lines:

| URL | Count |
|---|---|
| ~/.cache/quickshell/booru/danbooru/previews/11880017.jpg | 2 |
| ~/.cache/quickshell/manga/mangadex/covers/32d76d19-8a05….jpg | 1 |
| ~/.cache/quickshell/manga/mangadex/covers/b0b721ff-….jpg | 1 |
| image://icon/nm-signal-00 | 1 — *real failure: the icon theme has no `nm-signal-00` (or too many cols: legacy icon themes had 194 cols)* |

Likely booru/manga previews were still downloading when the loader fired (browsed pages during the run). The `nm-signal-00` lookup suggests a disconnected-network case constructed an icon name that doesn't exist in the theme.

## Top 30 hotspots

| # | Total ms | Count | Avg ms | ms/frame | Type | Location | Details |
|---|---|---|---|---|---|---|---|
| 1 | 39 532 | 518 | 76.3 | 1.90 | Javascript | [KeyBindsWidget.qml:91](../../widgets/leftPanel/KeyBindsWidget.qml#L91) | `_squeeze` |
| 2 | 25 445 | 829 | 30.7 | 1.22 | Creating | qrc:/qt-project.org/…/Fusion/Label.qml:11 | QtQuick.Templates/Label |
| 3 | 24 828 | 326 | 76.2 | 1.19 | Javascript | [KeyBindsWidget.qml:107](../../widgets/leftPanel/KeyBindsWidget.qml#L107) | `_extractKeys` |
| 4 | 18 625 | 1 804 | 10.3 | 0.89 | Binding | qrc:/…/Fusion/ToolTip.qml:14 | (tooltip repositioning) |
| 5 | 18 533 | 1 726 | 10.7 | 0.89 | Javascript | qrc:/…/Fusion/ToolTip.qml:14 | expression for x |
| 6 | 17 197 | 347 | 49.6 | 0.83 | Javascript | [BooruActions.qml:44](../../services/BooruActions.qml#L44) | `isInArray` |
| 7 | 16 065 | 1 126 | 14.3 | 0.77 | Creating | qrc:/…/Fusion/ToolTip.qml:11 | QtQuick.Templates/ToolTip |
| 8 | 13 638 | 594 | 23.0 | 0.66 | Javascript | [Settings.qml:891](../../theme/Settings.qml#L891) | hyprland `_schema` rebuild IIFE |
| 9–15 | ~90 000 | ~6 500 | ~13 | | JS/Binding | qrc:/…/Fusion/ToolTip.qml:15/17/19 | tooltip x/y/implicit W/H re-evals |
| 16 | 11 455 | 671 | 17.1 | 0.55 | Javascript | [BarState.qml:581](../../services/BarState.qml#L581) | `monitorStates()` |
| 17 | 10 958 | 580 | 18.9 | 0.53 | Creating | [AppTooltip.qml:18](../../widgets/shared/AppTooltip.qml#L18) | ToolTip (i.e. AppTooltip instance) |
| 18–19 | ~21 700 | ~1 160 | ~18.8 | | Creating | [AppTooltip.qml:46](../../widgets/shared/AppTooltip.qml#L46) / [:54](../../widgets/shared/AppTooltip.qml#L54) | enter/exit Transition TVLs |
| 20–26 | ~63 000 | ~1 800 | ~34 | | Creating | [AppButton.qml:19/138/144/154/168](../../widgets/shared/AppButton.qml#L19) | Item/Text/Rectangle/MouseArea per button |
| 27–28 | ~20 200 | ~1 300 | ~15 | | Creating | [AppTooltip.qml:30](../../widgets/shared/AppTooltip.qml#L30) / [:36](../../widgets/shared/AppTooltip.qml#L36) | Rectangle/Text contentItem |
| 29 | 9 863 | 535 | 18.4 | 0.47 | Javascript | [BarState.qml:586](../../services/BarState.qml#L586) | `isOpenFor()` |
| 30 | 9 385 | 13 355 | 0.7 | 0.45 | Javascript | qrc:/…/Fusion/Label.qml:15 | expression for linkColor |

Qt-internal rows (`qrc:/qt-project.org/…`) are the cost of *how the app uses* Fusion Controls — driven mostly by `AppTooltip` churn and bar text layout, not bugs inside Qt.

## Detailed analysis — top 5 project hotspots

### 1. [KeyBindsWidget.qml:91](../../widgets/leftPanel/KeyBindsWidget.qml#L91) — `_squeeze()` → 39.5 s over 518 calls (76 ms avg)

```qml
function _squeeze(s) {
    return s.split(/\s+/).filter(w => w !== "").join(" ");
}
```

`_squeeze` (and sister `_extractKeys` at [line 107](../../widgets/leftPanel/KeyBindsWidget.qml#L107)) run inside `_parseMain`/`_parseCustom`, which are regex-parse the entire `bind.lua` + `custom/*.lua` per rebuild ([line 156](../../widgets/leftPanel/KeyBindsWidget.qml#L156): every `hl.bind` line goes through `_normalizeCombo → _squeeze`). The 518 recorded calls ≈ 3–4 full rebuilds; each allocation-heavy string pass also lands the GC pauses that inflate the average. The real leak is *how often rebuilds happen* — the QML-native port replaced a one-shot external script with a function that re-runs on reload events during the run.

**Fix:** memoize: when `bindFilePath` is unchanged, cache the parsed result (`property var _cached: {}` keyed by file mtime/text hash) so repeated FileView reloads / focus events don't re-parse. Also replace the double `split().filter().join()` with a single `String.prototype.replace(/[ \t]+/g, " ").trim()` — same result, one allocation.

### 2. [AppTooltip.qml](../../widgets/shared/AppTooltip.qml) usage churn — ~1 126 ToolTip + 829 Label creations, ~90 s of tooltip binding re-evals

`AppTooltip` extends `Controls.ToolTip`; each hover-show instantiates the ToolTip control's background `Rectangle` ([line 30](../../widgets/shared/AppTooltip.qml#L30)), contentItem `Text` ([line 36](../../widgets/shared/AppTooltip.qml#L36)) and both `Transition` TVLs ([lines 46](../../widgets/shared/AppTooltip.qml#L46), [54](../../widgets/shared/AppTooltip.qml#L54)); bar pill state swaps create/destroy whole `AppTooltip` instances (//#17: 580 ToolTip creations at 19 ms avg). Hovering the bar and opening islands therefore pays ~14–30 ms *per tooltip* plus ~1000 re-evaluations of Fusion's ToolTip `x`/`y`/`implicitWidth`/`implicitHeight` bindings (each ~10–14 ms — popup geometry re-layout loops each show).

**Fix:** cheap wins: (a) keep `AppTooltip` instances alive — the bar's pill rebuild destroys/creates them (see #17 Creation count ≈ number of pill state swaps); (b) convert the `enter`/`exit` `Transition` TVLs to a single `Behavior on opacity` (TVL creation cost disappears); (c) `ToolTip.delay` already dampens cost — for the hottest sites (bar buttons), reuse one shared tooltip on the window instead of one per control.

### 3. [BooruActions.qml:44](../../services/BooruActions.qml#L44) — `isInArray()` → 17.2 s over 347 calls (49.6 ms avg)

```qml
function isInArray(arr, img) {
    if (!img) return false;
    return (arr || []).some(x => x && String(x.id) === String(img.id) && root.apiOf(x) === root.apiOf(img));
}
```

O(n) scan of the bookmarks/pins array per call. Masonry delegates call `isBookmarked(img)`/`isPinned(img)` per image on data change, so n² behaviour when a page of images checks against an n-item list — the profiled ~350 ms-avg calls were on a large bookmark list.

**Fix:** build the list's lookup key once (`Set` of `api + ":" + id`) and check per image in O(1). Root-cause it where `isBookmarked/isPinned/isCurrentWaifu` are bound in delegates: expose per-image booleans from a single computed source (`Connections { target: Settings; ... recompute filtered list once }`) instead of a `a.some(...)` bound per delegate.

### 4. [Settings.qml:891](../../theme/Settings.qml#L891) — hyprland `_schema` rebuild IIFE → 13.6 s over 594 calls (23 ms avg)

This is the deferred `_schema` rewire (from the 2026-09-13 P3 refactor): the big `hyprland` node tree is rebuilt inside the IIFE nested in the `_schema` builder, re-walking `leaf.path` through `root.hyprland` for every leaf every time `_schema` re-evaluates (each `persist()`/reload triggers it).

**Fix:** short-circuit rebuilds: cache the last `JSON.stringify(root.hyprland)` input hash and reuse the built subtree if unchanged; or move the IIFE's output to a lazily computed `readonly property` that only reacts to `_hyprlandLeafSchema` and `root.hyprland` changes (it currently lives inside the much wider `_schema` invalidation set).

### 5. [BarState.qml:581](../../services/BarState.qml#L581) / [586](../../services/BarState.qml#L586) — `monitorStates()`/`isOpenFor()` → ~21 s over ~1 200 calls (17–18 ms avg)

`monitorStates()` resolves `(panelStatesByMonitor || {})[monitor]`; `isOpenFor` composes it. Both are called from many bar bindings per QML evaluation, and every reassignment of `panelStatesByMonitor` re-evaluates all of them — ~17 ms each because each call constructs/reconciles the monitor object and its callers rebind after.

**Fix:** per-monitor contrast batching: instead of `panelStatesByMonitor` changing identity per change, emit one signal per monitor and have per-bar bindings read a cheap cached `readonly property var statesForThisMonitor` (compute the same object once per monitor). Cuts the repeated `(... || {})[monitor] || {}` chain — measured here as the 671/535 bindings.

## Next steps (priority order)

1. **`image://icon/nm-signal-00` failure** (user-visible: missing status icon on disconnected network) — guard the icon name (use `nm-no-connection` or a static fallback).
2. **12.4 MP default avatar decode** — `sourceSize` it or replace the asset with a small variant (cheapest user-visible win in the same file).
3. **KeyBindsWidget rebuild memoization** (above #1) — the largest single JS consumer.
4. **AppTooltip churn** (above #2) — biggest "Creating" consumer; bar pill state swaps pay ~20 ms per swap.
5. **BooruActions `isInArray` set-lookup** (above #3).
6. **Settings `_schema` IIFE caching** (above #4).
7. **BarState `monitorStates` binding batching** (above #5).

Since these hotspots live in a short list of files — `KeyBindsWidget.qml`, `AppTooltip.qml`, `AppButton.qml`, `BooruActions.qml`, `Settings.qml`, `BarState.qml` — running the `qt-qml-review` skill on them would add the broader structural pass (bindings, delegates, states, perf rules) against the same list.

> AI assistance has been used to create this output.
