pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Mirrors the subset of the quickshell settings.json
// (~/.cache/quickshell/settings/settings.json) that the bar and panels
// consume. Values are read once at startup; the settings UI remains the
// editor and this shell follows the same file throughout.
Singleton {
    id: root

    // --- simple booleans / ints / strings ---
    property bool barLock: true
    property bool barSmartHide: false
    property bool barDefault: true
    property bool barFullWidth: false
    property real revealPressure: 500
    property bool barOrientation: true        // true = top
    property bool workspaceNumbers: false

    // bar layout toggles (workspaces / information / utilities sections)
    // barLayoutOrder preserves the drag-reorder sequence for persist().
    property var barLayout: ({
            workspaces: true,
            information: true,
            utilities: true
        })
    property var barLayoutOrder: ["workspaces", "information", "utilities"]

    property string dateFormat: "%H:%M"
    readonly property var dateFormats: ["%H:%M", "%I:%M %p"]
    property real uiOpacity: 0.618
    property int uiScale: 10
    property int uiFontSize: 12

    property real leftPanelHotZoneSize: 5
    property real rightPanelHotZoneSize: 5
    property bool leftPanelHotZone: true
    property bool rightPanelHotZone: true
    property bool notifDnd: false
    property bool leftPanelLock: false
    property bool rightPanelLock: false
    property bool leftPanelExclusivity: true
    property bool rightPanelExclusivity: true
    property int leftPanelWidth: 400
    property int rightPanelWidth: 250
    // Lockscreen grace period in seconds (Esc dismisses the lock without a
    // password within this window after locking), persisted, default 10.
    property int lockGraceSeconds: 10
    // Selected left-panel tab (persisted)
    property string leftPanelWidget: "UserProfile"
    // Wallpaper switcher category (persisted)
    property string wallpaperCategory: "defaults/sfw"
    // Wallpaper provider (persisted): "local" (default/* + custom folders)
    // or "wallhaven" (wallhaven.cc API). Filter state for the Wallhaven
    // provider (persisted under wallpaperSwitcher.wallhaven).
    property string wallpaperProvider: "local"
    property var wallpaperWallhaven: root.defaultWallpaperWallhaven()
    // Shared wallpaper masonry view (persisted): row count + exact tile
    // height in px. Both providers (local + wallhaven) render through one
    // AppMasonryRow driven by these; the island grows to fit (true height).
    property int wallpaperMasonryRows: 2
    property int wallpaperTileSize: 120
    // Default Wallhaven filter state (single source; reload() merges the
    // saved file over a fresh copy). categories/purity are wallhaven.cc
    // bit-strings: categories = general/anime/people, purity = sfw/sketchy/nsfw.
    function defaultWallpaperWallhaven() {
        return {
            q: "",
            categories: "111",
            purity: "100",
            sorting: "date_added",
            order: "desc",
            topRange: "1M",
            atleast: "",
            ratios: "",
            page: 1
        };
    }
    // Weather city override (empty = Auto/IP), persisted
    property string weatherCity: ""

    // Right panel widgets — datalist with enabled flag.
    // CODE IS SOURCE OF TRUTH FOR ICONS: persist()/reload() only save/restore
    // {name, enabled} + order. Edit icons here (defaultRightPanelWidgets) and
    // they will not be clobbered by settings.json.
    property var rightPanelWidgets: root.defaultRightPanelWidgets()
    // Canonical widget definitions (names + code-owned icons + default enabled).
    function defaultRightPanelWidgets() {
        return [
            {
                name: "Waifu",
                icon: "\uf004",
                enabled: true
            },
            {
                name: "Media",
                icon: "\uf04b",
                enabled: true
            },
            {
                name: "NotificationHistory",
                icon: "\uf0f3",
                enabled: true
            },
            {
                name: "Calendar",
                icon: "\uf073",
                enabled: true
            },
            {
                name: "SystemResources",
                icon: "\uf4bc",
                enabled: true
            },
        ];
    }
    // Merge a saved widgets list onto the code defaults: keep file order +
    // enabled flags, drop unknown names, always take icons from code, append
    // any code-defined widgets missing from the file (new widgets).
    function mergeRightPanelWidgets(saved) {
        const defs = root.defaultRightPanelWidgets();
        const byName = {};
        for (const d of defs)
            byName[d.name] = d;
        if (!Array.isArray(saved))
            return defs;
        const out = [];
        for (const w of saved) {
            if (!w || !w.name || !byName[w.name])
                continue;
            if (out.some(e => e.name === w.name))
                continue;
            out.push({
                name: w.name,
                icon: byName[w.name].icon,
                enabled: (w.enabled ?? byName[w.name].enabled ?? true)
            });
        }
        for (const d of defs) {
            if (!out.some(e => e.name === d.name))
                out.push({
                    name: d.name,
                    icon: d.icon,
                    enabled: d.enabled
                });
        }
        return out.length > 0 ? out : defs;
    }
    property bool autoWorkspaceSwitching: true

    // Bar-pinned crypto favorite (Information center)
    property var cryptoFavorite: ({
            symbol: "",
            timeframe: ""
        })

    property var booru: ({
            api: ({
                    name: "Danbooru",
                    value: "danbooru",
                    url: "https://danbooru.donmai.us/",
                    idSearchUrl: "https://danbooru.donmai.us/posts/"
                }),
            tags: ["-rating:explicit"],
            limit: 100,
            page: 1,
            columns: 3,
            bookmarks: [],
            pins: [],
            selectedTab: "Danbooru"
        })
    // Initialized with shipped defaults (not {}) so early fetchers (Booru
    // onCompleted) have credentials even before the settings file load
    // merges saved values over them. Single source: defaultApiKeys() below
    // (this used to paste the same literal twice).
    // Per-service User-Agent strings. Kept centralized so every widget/backend
    // uses the same editable values while still allowing services to have
    // different requirements.
    property var apiKeys: root.defaultApiKeys()
    property var userAgents: root.defaultUserAgents()

    function defaultUserAgents() {
        return {
            booru: "QuickshellBooru/1.0 (ArchLinux; Hyprland)",
            mangaDex: "ArchEclipse-MangaCLI/1.0",
            mangaLib: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            waifu: "QuickshellBooru/1.0 (ArchLinux; Hyprland)",
            fastfetch: "QuickshellBooru/1.0 (ArchLinux; Hyprland)"
        };
    }

    function mergeUserAgents(saved) {
        const d = root.defaultUserAgents();
        if (!saved || typeof saved !== "object")
            return d;
        for (const key of Object.keys(d)) {
            const v = saved[key];
            if (v !== undefined && v !== null && String(v).trim() !== "")
                d[key] = String(v);
        }
        return d;
    }

    function userAgent(name) {
        return String((root.userAgents || {})[name] || root.defaultUserAgents()[name] || "");
    }

    // Default API credentials (shipped fallback). Used when the settings
    // file has none saved — the defaults stay in memory; QS must do the
    // same or booru.py hard-rejects danbooru/gelbooru with MISSING_CREDENTIALS.
    function defaultApiKeys() {
        return {
            openrouter: {
                user: {
                    value: ""
                },
                key: {
                    value: ""
                }
            },
            danbooru: {
                user: {
                    value: "publicapi"
                },
                key: {
                    value: "Pr5ddYN7P889AnM6nq2nhgw1"
                }
            },
            gelbooru: {
                user: {
                    value: "1667355"
                },
                key: {
                    value: "1ccd9dd7c457c2317e79bd33f47a1138ef9545b9ba7471197f477534efd1dd05"
                }
            },
            safebooru: {
                user: {
                    value: "publicapi"
                },
                key: {
                    value: "Pr5ddYN7P889AnM6nq2nhgw1"
                }
            },
            // Wallhaven needs only a key (no user); empty = guest mode
            // (SFW-only). A key unlocks sketchy/NSFW purity + user filters.
            wallhaven: {
                key: {
                    value: ""
                }
            }
        };
    }

    // Merge saved apiKeys over the defaults (per api, per field), accepting
    // both the nested shape {user:{value}} and flat strings.
    function mergeApiKeys(saved) {
        const d = root.defaultApiKeys();
        if (!saved)
            return d;
        for (const api of Object.keys(d)) {
            const s = saved[api];
            if (s == null)
                continue;
            for (const field of ["user", "key"]) {
                const v = s[field];
                if (v == null)
                    continue;
                const str = (typeof v === "object") ? (v.value ?? "") : String(v);
                if (str !== "")
                    d[api][field] = {
                        value: str
                    };
            }
        }
        return d;
    }

    // Unwrap one credential as a plain string regardless of stored shape.
    function apiKey(api, field) {
        const v = (root.apiKeys || {})[api]?.[field];
        if (v == null)
            return "";
        return String((typeof v === "object" ? (v.value ?? "") : v)).replace(/\n/g, "").trim();
    }

    // Single place listing the code-owned default sets: a new defaulted key
    // adds its row here (plus a default*/merge* pair only if the file shape
    // needs normalization on load). Startup snapshot; merge*() above keep
    // calling default*() so every load gets a fresh mutable copy.
    // (Stepping stone toward table-driven persist()/reload(): those bodies
    // stay authoritative until a live SUPER+B round-trip rewire verifies
    // byte-identical settings.json — not possible in a headless pass.)
    readonly property var _defaults: ({
            "apiKeys": defaultApiKeys(),
            "rightPanelWidgets": defaultRightPanelWidgets()
        })
    // Static hyprland leaf metadata, transcribed verbatim from persist()
    // below ({name, min, max, type} per leaf + reload() default in def).
    // Table order matches persist()'s insertion order. NOTE the two
    // on-disk key orders persist() uses: general/decoration leaves are
    // {name, value, min, max, type} but blur/shadow leaves are
    // {name, value, type, min, max} (flagged typeFirst) — the loop below
    // reproduces both so on-disk bytes never change.
    readonly property var _hyprlandLeafSchema: [
        {
            path: ["general", "border_size"],
            name: "Border Size",
            min: 0,
            max: 10,
            type: "int",
            def: 0
        },
        {
            path: ["general", "gaps_in"],
            name: "Gaps In",
            min: 0,
            max: 20,
            type: "int",
            def: 7
        },
        {
            path: ["general", "gaps_out"],
            name: "Gaps Out",
            min: 0,
            max: 40,
            type: "int",
            def: 10
        },
        {
            path: ["decoration", "rounding"],
            name: "Rounding",
            min: 0,
            max: 50,
            type: "int",
            def: 16
        },
        {
            path: ["decoration", "active_opacity"],
            name: "Active Opacity",
            min: 0,
            max: 1,
            type: "float",
            def: 0.9
        },
        {
            path: ["decoration", "inactive_opacity"],
            name: "Inactive Opacity",
            min: 0,
            max: 1,
            type: "float",
            def: 0.8
        },
        {
            path: ["decoration", "blur", "enabled"],
            name: "Blur Enabled",
            min: 0,
            max: 1,
            type: "bool",
            def: true,
            typeFirst: true
        },
        {
            path: ["decoration", "blur", "size"],
            name: "Blur Size",
            min: 0,
            max: 10,
            type: "int",
            def: 4,
            typeFirst: true
        },
        {
            path: ["decoration", "blur", "passes"],
            name: "Blur Passes",
            min: 0,
            max: 10,
            type: "int",
            def: 4,
            typeFirst: true
        },
        {
            path: ["decoration", "blur", "xray"],
            name: "Blur Xray",
            min: 0,
            max: 1,
            type: "bool",
            def: false,
            typeFirst: true
        },
        {
            path: ["decoration", "shadow", "enabled"],
            name: "Shadow Enabled",
            min: 0,
            max: 1,
            type: "bool",
            def: true,
            typeFirst: true
        },
        {
            path: ["decoration", "shadow", "range"],
            name: "Shadow Range",
            min: 0,
            max: 20,
            type: "int",
            def: 15,
            typeFirst: true
        },
        {
            path: ["decoration", "shadow", "render_power"],
            name: "Shadow Render Power",
            min: 0,
            max: 20,
            type: "int",
            def: 3,
            typeFirst: true
        }
    ]

    // Waifu widget setting group
    property var waifu: null

    // ChatBot provider + image-gen toggle (default: first provider, off).
    property string chatBotApi: "openai/gpt-4o-mini"
    property bool chatBotImageGeneration: false

    // Blur settings (size / passes / enabled)
    property bool barBlur: true
    property int barBlurPasses: 3
    property int barBlurSize: 4

    // Theme variants
    property bool dynamicThemeColors: true
    property bool dynamicThemeVariants: true

    // Always-on widget visibility
    property bool alwaysOnWidgetVisibility: true

    // KeyStrokeVisualizer settings
    property bool keyStrokeVisualizerVisibility: false
    property var keyStrokeVisualizerAnchor: ["bottom", "left"]

    // File manager (detected + selected)
    property var fileManagerOptions: []
    property string fileManager: ""

    // Profile picture
    property string profilePicturePath: ""

    // Hyprland settings (plain values internally; persist() writes the
    // {name,value,min,max,type} leaf shape the settings panel renders).
    property var hyprland: ({
            general: {
                border_size: 0,
                gaps_in: 7,
                gaps_out: 10
            },
            decoration: {
                rounding: 16,
                active_opacity: 0.9,
                inactive_opacity: 0.8,
                blur: {
                    enabled: true,
                    size: 4,
                    passes: 4,
                    xray: false
                },
                shadow: {
                    enabled: true,
                    range: 15,
                    render_power: 3
                }
            }
        })

    // --- functions ---

    function fmt(d, f) {
        const p = n => n.toString().padStart(2, "0");
        if (f === "%I:%M %p") {
            let h = d.getHours() % 12;
            if (h === 0)
                h = 12;
            return `${p(h)}:${p(d.getMinutes())} ${d.getHours() < 12 ? "AM" : "PM"}`;
        }
        return `${p(d.getHours())}:${p(d.getMinutes())}`;
    }

    // Update a setting by dotted path and persist to settings.json
    function updateSetting(path, value) {
        // Dotted paths that map to flat QS properties (Singleton cannot
        // gain new properties at runtime, so root["rightPanel"] = {} throws).
        const aliases = {
            "bar.lock": "barLock",
            "bar.smartHide": "barSmartHide",
            "bar.expanded": "barDefault",
            "bar.default": "barDefault",
            "bar.fullWidth": "barFullWidth",
            "bar.revealPressure": "revealPressure",
            "bar.orientation": "barOrientation",
            "bar.workspaceNumbers": "workspaceNumbers",
            "bar.blur": "barBlur",
            "bar.blurSize": "barBlurSize",
            "bar.blurPasses": "barBlurPasses",
            "ui.opacity": "uiOpacity",
            "ui.scale": "uiScale",
            "ui.fontSize": "uiFontSize",
            "leftPanel.hotZoneSize": "leftPanelHotZoneSize",
            "rightPanel.hotZoneSize": "rightPanelHotZoneSize",
            "leftPanel.hotZone": "leftPanelHotZone",
            "rightPanel.hotZone": "rightPanelHotZone",
            "leftPanel.lock": "leftPanelLock",
            "rightPanel.lock": "rightPanelLock",
            "leftPanel.exclusivity": "leftPanelExclusivity",
            "rightPanel.exclusivity": "rightPanelExclusivity",
            "leftPanel.width": "leftPanelWidth",
            "leftPanel.widget": "leftPanelWidget",
            "wallpaperSwitcher.category": "wallpaperCategory",
            "wallpaperSwitcher.provider": "wallpaperProvider",
            "wallpaperSwitcher.wallhaven": "wallpaperWallhaven",
            "wallpaperSwitcher.masonryRows": "wallpaperMasonryRows",
            "wallpaperSwitcher.tileSize": "wallpaperTileSize",
            "weather.city": "weatherCity",
            "rightPanel.width": "rightPanelWidth",
            "rightPanel.widgets": "rightPanelWidgets",
            "crypto.favorite": "cryptoFavorite",
            "notifications.dnd": "notifDnd",
            "lockscreen.graceSeconds": "lockGraceSeconds",
            "autoWorkspaceSwitching": "autoWorkspaceSwitching",
            "dynamicThemeColors": "dynamicThemeColors",
            "dynamicThemeVariants": "dynamicThemeVariants",
            "alwaysOnWidget.visibility": "alwaysOnWidgetVisibility",
            "keyStrokeVisualizer.visibility": "keyStrokeVisualizerVisibility",
            "keyStrokeVisualizer.anchor": "keyStrokeVisualizerAnchor",
            "fileManager": "fileManager",
            "profilePicturePath": "profilePicturePath",
            "chatBot.api": "chatBotApi",
            "chatBot.imageGeneration": "chatBotImageGeneration",
            "waifuWidget.current": "waifu"
        };
        if (aliases[path] !== undefined) {
            // Widget icons are code-owned: never store incoming icons, merge
            // onto the code defaults so a stale settings.json can't stick.
            if (path === "rightPanel.widgets") {
                root[aliases[path]] = root.mergeRightPanelWidgets(value);
            } else {
                root[aliases[path]] = value;
            }
            persist();
            return;
        }
        const parts = path.split(".");
        let obj = root;
        for (let i = 0; i < parts.length - 1; i++) {
            const p = parts[i];
            if (obj[p] === undefined || typeof obj[p] !== "object" || obj[p] === null) {
                return;
            } else {
                obj = obj[p];
            }
        }
        const key = parts[parts.length - 1];
        obj[key] = value;
        // Reassign a FRESH clone so the top-level var change signal fires.
        // (Assigning the same object reference back is a no-op: nested
        // bindings like `Settings.booru.limit` never re-evaluate.)
        if (parts.length > 1) {
            root[parts[0]] = Object.assign({}, obj);
        }
        persist();
    }

    // Persist current settings back to the JSON file.
    // Shape is nested (bar.lock, leftPanel.width, ...) — reload() reads the
    // same shape and tolerates unknown/missing keys.
    // Leaf settings are written as {value}; plain-value settings (locks,
    // plain-value settings (locks, widths, dnd, fileManager) stay plain.
    function persist() {
        if (!root.ready)
            return;
        try {
            const s = {
                bar: {
                    lock: {
                        value: root.barLock
                    },
                    smartHide: {
                        value: root.barSmartHide
                    },
                    default: {
                        value: root.barDefault
                    },
                    expanded: {
                        value: root.barDefault
                    },
                    fullWidth: {
                        value: root.barFullWidth
                    },
                    revealPressure: {
                        value: root.revealPressure
                    },
                    orientation: {
                        value: root.barOrientation
                    },
                    workspaceNumbers: {
                        value: root.workspaceNumbers
                    },
                    layout: (root.barLayoutOrder || ["workspaces", "information", "utilities"]).map(n => ({
                                name: n,
                                enabled: (root.barLayout || {})[n] ?? true
                            })),
                    blur: {
                        value: root.barBlur
                    },
                    blurSize: {
                        value: root.barBlurSize
                    },
                    blurPasses: {
                        value: root.barBlurPasses
                    }
                },
                dateFormat: root.dateFormat,
                crypto: {
                    favorite: root.cryptoFavorite
                },
                ui: {
                    opacity: {
                        value: root.uiOpacity
                    },
                    scale: {
                        value: root.uiScale
                    },
                    fontSize: {
                        value: root.uiFontSize
                    }
                },
                leftPanel: {
                    hotZoneSize: {
                        value: root.leftPanelHotZoneSize
                    },
                    hotZone: {
                        value: root.leftPanelHotZone
                    },
                    lock: root.leftPanelLock,
                    exclusivity: root.leftPanelExclusivity,
                    width: root.leftPanelWidth,
                    widget: {
                        name: root.leftPanelWidget
                    }
                },
                rightPanel: {
                    hotZoneSize: {
                        value: root.rightPanelHotZoneSize
                    },
                    hotZone: {
                        value: root.rightPanelHotZone
                    },
                    lock: root.rightPanelLock,
                    exclusivity: root.rightPanelExclusivity,
                    width: root.rightPanelWidth,
                    // Icons are code-owned: persist only {name, enabled} +
                    // order so icon edits in code are never clobbered.
                    widgets: (root.rightPanelWidgets || []).map(w => ({
                                name: w.name,
                                enabled: !!w.enabled
                            }))
                },
                notifications: {
                    dnd: root.notifDnd
                },
                lockscreen: {
                    graceSeconds: root.lockGraceSeconds
                },
                wallpaperSwitcher: {
                    category: root.wallpaperCategory,
                    provider: root.wallpaperProvider,
                    wallhaven: root.wallpaperWallhaven,
                    masonryRows: root.wallpaperMasonryRows,
                    tileSize: root.wallpaperTileSize
                },
                weather: {
                    city: root.weatherCity
                },
                autoWorkspaceSwitching: {
                    value: root.autoWorkspaceSwitching
                },
                // Hyprland leaf shape {name,value,min,max,type} — the settings
                // panel renders from it (plain numbers would be mistaken for
                // nested groups and render nothing). Driven by
                // _hyprlandLeafSchema above (single source for labels/limits);
                // blur/shadow leaves keep their {name,value,type,min,max}
                // order via typeFirst so on-disk bytes never change.
                "hyprland": (() => {
                        const out = {};
                        for (const leaf of root._hyprlandLeafSchema) {
                            const v = leaf.path.reduce((o, k) => ((o == null) ? o : o[k]), root.hyprland) ?? leaf.def;
                            let node = out;
                            for (let i = 0; i < leaf.path.length - 1; i++) {
                                const g = leaf.path[i];
                                if (node[g] === undefined)
                                    node[g] = {};
                                node = node[g];
                            }
                            const key = leaf.path[leaf.path.length - 1];
                            node[key] = (leaf.typeFirst === true) ? {
                                name: leaf.name,
                                value: v,
                                type: leaf.type,
                                min: leaf.min,
                                max: leaf.max
                            } : {
                                name: leaf.name,
                                value: v,
                                min: leaf.min,
                                max: leaf.max,
                                type: leaf.type
                            };
                        }
                        return out;
                    })(),
                dynamicThemeColors: {
                    value: root.dynamicThemeColors
                },
                dynamicThemeVariants: {
                    value: root.dynamicThemeVariants
                },
                alwaysOnWidget: {
                    "visibility": {
                        value: root.alwaysOnWidgetVisibility
                    }
                },
                keyStrokeVisualizer: {
                    "visibility": {
                        value: root.keyStrokeVisualizerVisibility
                    },
                    "anchor": {
                        value: root.keyStrokeVisualizerAnchor
                    }
                },
                fileManager: root.fileManager,
                profilePicturePath: root.profilePicturePath,
                "waifuWidget": {
                    current: root.waifu
                },
                "chatBot": {
                    api: root.chatBotApi,
                    imageGeneration: root.chatBotImageGeneration
                },
                "booru": {
                    api: root.booru.api,
                    tags: root.booru.tags,
                    limit: root.booru.limit,
                    page: root.booru.page,
                    columns: root.booru.columns,
                    bookmarks: root.booru.bookmarks,
                    pins: root.booru.pins,
                    selectedTab: root.booru.selectedTab ?? root.booru.api?.name ?? "Danbooru"
                },
                "apiKeys": root.apiKeys,
                "userAgents": root.userAgents
            };
            _lastText = JSON.stringify(s, null, 2);
            _file.setText(_lastText);
        } catch (e) {
            console.warn("[Settings] Failed to persist:", e);
        }
    }

    // FileView for settings. NOTE: bare reload() here would resolve to
    // FileView.reload() (re-read method), NOT the settings parser below —
    // always qualify with root. (This shadowing was why settings silently
    // stopped applying after a restart.)
    property FileView _file: FileView {
        path: `${Quickshell.env("HOME")}/.cache/quickshell/settings/settings.json`
        watchChanges: true
        // Delayed: FileView saves are async, so an immediate re-read can
        // catch pre-write bytes and persist the stale state back over the
        // fresh one (seen: limit 30 reverted to 40 in-file). 300ms lets our
        // own write land; _lastText then makes it a no-op.
        onFileChanged: _reloadTimer.restart()
        onLoaded: {
            root.reload();
            root.ready = true;
        }
    }
    // Last text we wrote (or successfully adopted): reload() skips it so
    // our own watcher echo can't churn assignments back over newer state.
    property string _lastText: ""
    property Timer _reloadTimer: Timer {
        interval: 300
        onTriggered: root.reload()
    }
    // Fallback: FileView never emits loaded for a missing file, which left
    // ready=false forever and gated every persist() (no settings.json was
    // ever created). If onLoaded hasn't fired in 2s, adopt disk state and
    // open the gate — persist() then creates the file with current values.
    property Timer _readyTimer: Timer {
        interval: 2000
        repeat: false
        onTriggered: {
            if (root.ready)
                return;
            root.reload();
            root.ready = true;
            root.persist();
        }
    }
    // Gate: FileView loads async, so any persist() before the first load
    // would write in-memory defaults over the user's saved file (seen:
    // booru.limit 20 clobbered back to 100 on restart). Nothing persists
    // until the on-disk values have been adopted.
    property bool ready: false

    // Fresh on-disk settings for upload sync — never an empty stub
    // (uploading {} would wipe remote).
    function readLocalSettingsJson() {
        try {
            const text = _file.text();
            if (text && text.trim().startsWith("{"))
                return JSON.parse(text);
        } catch (e) {}
        return {};
    }

    function reload() {
        try {
            const text = _file.text();
            if (text !== "" && text.trim().startsWith("{")) {
                if (text === root._lastText)
                    return;
                const s = JSON.parse(text);
                root._lastText = text;
                root.barLock = s.bar?.lock?.value ?? true;
                root.barSmartHide = s.bar?.smartHide?.value ?? false;
                root.barDefault = s.bar?.default?.value ?? s.bar?.expanded?.value ?? true;
                root.barFullWidth = s.bar?.fullWidth?.value ?? false;
                root.revealPressure = s.bar?.revealPressure?.value ?? 250;
                root.barOrientation = s.bar?.orientation?.value ?? true;
                root.workspaceNumbers = s.bar?.workspaceNumbers?.value ?? false;

                // bar layout
                const layout = {};
                if (Array.isArray(s.bar?.layout)) {
                    for (const w of s.bar.layout) {
                        layout[w.name] = !!w.enabled;
                    }
                }
                root.barLayout = {
                    workspaces: layout.workspaces ?? true,
                    information: layout.information ?? true,
                    utilities: layout.utilities ?? true
                };
                // Preserve the file's widget order (drag-reorder sequence);
                // fall back to the default order on unknown entries.
                if (Array.isArray(s.bar?.layout) && s.bar.layout.length > 0) {
                    const known = ["workspaces", "information", "utilities"];
                    const ordered = s.bar.layout.map(w => w.name).filter(n => known.includes(n));
                    for (const n of known)
                        if (!ordered.includes(n))
                            ordered.push(n);
                    root.barLayoutOrder = ordered;
                }

                root.dateFormat = s.dateFormat ?? "%H:%M";
                root.cryptoFavorite = s.crypto?.favorite ?? {
                    symbol: "",
                    timeframe: ""
                };
                root.uiOpacity = s.ui?.opacity?.value ?? 0.618;
                root.uiScale = s.ui?.scale?.value ?? 10;
                root.uiFontSize = s.ui?.fontSize?.value ?? 12;

                root.leftPanelHotZoneSize = s.leftPanel?.hotZoneSize?.value ?? 5;
                root.rightPanelHotZoneSize = s.rightPanel?.hotZoneSize?.value ?? 5;
                root.leftPanelHotZone = s.leftPanel?.hotZone?.value ?? true;
                root.rightPanelHotZone = s.rightPanel?.hotZone?.value ?? true;
                root.notifDnd = s.notifications?.dnd ?? false;
                root.leftPanelLock = !!s.leftPanel?.lock;
                root.rightPanelLock = !!s.rightPanel?.lock;
                root.leftPanelExclusivity = s.leftPanel?.exclusivity ?? true;
                root.rightPanelExclusivity = s.rightPanel?.exclusivity ?? true;
                root.leftPanelWidth = (typeof s.leftPanel?.width === "object" && s.leftPanel?.width !== null ? s.leftPanel.width.value : s.leftPanel?.width) ?? 400;
                // The file may store the selector object {name, icon}; QS persists
                // only {name} and restores only the name — left icons live in
                // (LeftIsland) and are never clobbered by the file.
                // legacy QS files used the flat "leftPanel.widget" key.
                const _lpw = s["leftPanel.widget"] ?? s.leftPanel?.widget;
                root.leftPanelWidget = (typeof _lpw === "string" ? _lpw : _lpw?.name) ?? "UserProfile";
                const _wc = s.wallpaperSwitcher?.category;
                root.wallpaperCategory = ((typeof _wc === "object" && _wc !== null ? _wc.value : _wc) ?? "defaults/sfw");
                // Wallhaven provider state: merge the saved filter object over
                // fresh defaults so new params never come back undefined.
                // Bit-strings are re-validated (3 chars of 0/1); sorting falls
                // back to date_added on unknown values; page clamps to >= 1.
                const _wp = s.wallpaperSwitcher?.provider;
                root.wallpaperProvider = ((_wp && typeof _wp === "object" ? _wp.value : _wp) ?? "local");
                if (root.wallpaperProvider !== "local" && root.wallpaperProvider !== "wallhaven")
                    root.wallpaperProvider = "local";
                const _whSaved = s.wallpaperSwitcher?.wallhaven;
                const _wh = root.defaultWallpaperWallhaven();
                if (_whSaved && typeof _whSaved === "object") {
                    const pick = (v, fb) => ((v !== undefined && v !== null) ? String(v) : fb);
                    _wh.q = pick(_whSaved.q, _wh.q);
                    const bits = (v, fb) => (/^[01]{3}$/.test(String(v ?? "")) ? String(v) : fb);
                    _wh.categories = bits(_whSaved.categories, _wh.categories);
                    _wh.purity = bits(_whSaved.purity, _wh.purity);
                    const _sortings = ["date_added", "relevance", "random", "views", "favorites", "toplist"];
                    _wh.sorting = _sortings.includes(_whSaved.sorting) ? _whSaved.sorting : _wh.sorting;
                    _wh.order = (_whSaved.order === "asc" ? "asc" : "desc");
                    _wh.topRange = pick(_whSaved.topRange, _wh.topRange);
                    _wh.atleast = pick(_whSaved.atleast, _wh.atleast);
                    _wh.ratios = pick(_whSaved.ratios, _wh.ratios);
                    _wh.page = Math.max(1, parseInt(_whSaved.page) || 1);
                }
                root.wallpaperWallhaven = _wh;
                // Shared masonry view: plain or {value} leaves, clamped
                // (rows 1-4, tile height 80-200px).
                const _mr = s.wallpaperSwitcher?.masonryRows;
                const _mrV = (typeof _mr === "object" && _mr !== null ? _mr.value : _mr);
                root.wallpaperMasonryRows = Math.min(4, Math.max(1, parseInt(_mrV) || 2));
                const _ts = s.wallpaperSwitcher?.tileSize;
                const _tsV = (typeof _ts === "object" && _ts !== null ? _ts.value : _ts);
                root.wallpaperTileSize = Math.min(200, Math.max(80, parseInt(_tsV) || 120));
                const _wth = s.weather?.city ?? s.weatherCity;
                root.weatherCity = ((typeof _wth === "object" && _wth !== null ? _wth.value : _wth) ?? "");
                root.rightPanelWidth = (typeof s.rightPanel?.width === "object" && s.rightPanel?.width !== null ? s.rightPanel.width.value : s.rightPanel?.width) ?? 250;
                // Drop stale/removed widgets (e.g. retired Crypto/ScriptTimer)
                // so deleted options never reappear from an old settings file.
                // Icons are code-owned: file contributes only order + enabled.
                if (Array.isArray(s.rightPanel?.widgets)) {
                    root.rightPanelWidgets = root.mergeRightPanelWidgets(s.rightPanel.widgets);
                }
                root.autoWorkspaceSwitching = s.autoWorkspaceSwitching?.value ?? true;

                // Rating tag leads, defaulting to -rating:explicit. Done here
                // (not viewer boot) so the file's tags are normalized the
                // moment they are adopted — viewer boot may run before or
                // after this either way.
                let _tags = (s.booru?.tags ?? ["-rating:explicit"]).slice();
                const _rt = _tags.find(t => t.match(/[-]rating:explicit|rating:explicit/));
                _tags = _tags.filter(t => !t.match(/[-]rating:explicit|rating:explicit/));
                _tags.unshift(_rt ?? "-rating:explicit");
                root.booru = {
                    api: s.booru?.api ?? {
                        name: "Danbooru",
                        value: "danbooru",
                        url: "https://danbooru.donmai.us/",
                        idSearchUrl: "https://danbooru.donmai.us/posts/"
                    },
                    tags: _tags,
                    limit: s.booru?.limit ?? 100,
                    page: s.booru?.page ?? 1,
                    columns: s.booru?.columns ?? 3,
                    bookmarks: s.booru?.bookmarks ?? [],
                    pins: s.booru?.pins ?? [],
                    selectedTab: s.booru?.selectedTab ?? s.booru?.api?.name ?? "Danbooru"
                };
                root.apiKeys = root.mergeApiKeys(s.apiKeys);
                root.userAgents = root.mergeUserAgents(s.userAgents);

                // Waifu widget
                root.waifu = s.waifuWidget?.current ?? null;

                // ChatBot provider (restored on launch; stored as the model
                // value string here).
                const cbApi = s.chatBot?.api;
                root.chatBotApi = (cbApi && typeof cbApi === "object" ? cbApi.value : cbApi) ?? "openai/gpt-4o-mini";
                root.chatBotImageGeneration = s.chatBot?.imageGeneration ?? false;

                // Blur settings
                root.barBlur = s.bar?.blur?.value ?? true;
                root.barBlurPasses = s.bar?.blurPasses?.value ?? 3;
                root.barBlurSize = s.bar?.blurSize?.value ?? 4;

                // Lockscreen grace period (seconds of free Esc dismiss)
                root.lockGraceSeconds = s.lockscreen?.graceSeconds ?? 10;

                const _dtc = s.dynamicThemeColors;
                root.dynamicThemeColors = (typeof _dtc === "object" && _dtc !== null ? _dtc.value : _dtc) ?? true;
                const _dtv = s.dynamicThemeVariants;
                root.dynamicThemeVariants = (typeof _dtv === "object" && _dtv !== null ? _dtv.value : _dtv) ?? true;

                // Always-on widget visibility
                root.alwaysOnWidgetVisibility = s.alwaysOnWidget?.visibility?.value ?? true;

                // KeyStrokeVisualizer (anchor: legacy plain array or {value} leaf)
                root.keyStrokeVisualizerVisibility = s.keyStrokeVisualizer?.visibility?.value ?? false;
                const _ka = s.keyStrokeVisualizer?.anchor;
                root.keyStrokeVisualizerAnchor = (Array.isArray(_ka) ? _ka : _ka?.value) ?? ["bottom", "left"];

                // File manager
                root.fileManager = s.fileManager ?? "";

                // Profile picture path
                root.profilePicturePath = s.profilePicturePath ?? "";

                // Hyprland settings (full schema incl. blur passes 4, xray,
                // xray, gaps, opacities — previously partial, which reset
                // missing keys to 0/false on every reload). Defaults come
                // from _hyprlandLeafSchema so persist()/reload() agree.
                root.hyprland = (() => {
                        const out = {};
                        for (const leaf of root._hyprlandLeafSchema) {
                            const node = leaf.path.reduce((o, k) => ((o == null) ? undefined : o[k]), s.hyprland);
                            const v = ((typeof node === "object" && node !== null) ? node.value : undefined) ?? leaf.def;
                            let target = out;
                            for (let i = 0; i < leaf.path.length - 1; i++) {
                                const g = leaf.path[i];
                                if (target[g] === undefined)
                                    target[g] = {};
                                target = target[g];
                            }
                            target[leaf.path[leaf.path.length - 1]] = v;
                        }
                        return out;
                    })();
            }
        } catch (e) {
            console.warn("[Settings] parse failed:", e);
        }
    }

    Component.onCompleted: {
        root.reload();
        root._readyTimer.start();
    }

    // Auto-persist: debounce writes so the settings file isn't thrashed
    // by rapid UI toggles (e.g. dragging the opacity slider).
    property Timer _persistTimer: Timer {
        interval: 250
        onTriggered: persist()
    }
    function schedulePersist() {
        if (root.ready)
            _persistTimer.start();
    }

    // Watch directly-written settings properties and auto-persist.
    // Rule: a handler exists ONLY for keys with a direct `Settings.x = ...`
    // writer outside updateSetting() (verified via
    // `rg "Settings\.[a-zA-Z]+ =" widgets/ services/ theme/ shell.qml` plus
    // bracket writes). updateSetting() persists directly, so its exclusive
    // keys need no handler. onApiKeysChanged stays: SettingsWidget
    // setNestedValue() writes Settings["apiKeys"] directly (and the merge
    // in reload() normalizes credentials on external edits).
    Connections {
        target: root
        function onBarLockChanged() {
            root.schedulePersist();
        }
        function onBarSmartHideChanged() {
            root.schedulePersist();
        }
        function onBarDefaultChanged() {
            root.schedulePersist();
        }
        function onBarFullWidthChanged() {
            root.schedulePersist();
        }
        function onRevealPressureChanged() {
            root.schedulePersist();
        }
        function onBarOrientationChanged() {
            root.schedulePersist();
        }
        function onWorkspaceNumbersChanged() {
            root.schedulePersist();
        }
        function onBarLayoutOrderChanged() {
            root.schedulePersist();
        }
        function onBarLayoutChanged() {
            root.schedulePersist();
        }
        function onLeftPanelExclusivityChanged() {
            root.schedulePersist();
        }
        function onRightPanelExclusivityChanged() {
            root.schedulePersist();
        }
        function onRightPanelWidgetsChanged() {
            root.schedulePersist();
        }
        function onCryptoFavoriteChanged() {
            root.schedulePersist();
        }
        function onApiKeysChanged() {
            root.schedulePersist();
        }
        function onDateFormatChanged() {
            root.schedulePersist();
        }
        function onUiOpacityChanged() {
            root.schedulePersist();
        }
        function onUiScaleChanged() {
            root.schedulePersist();
        }
        function onUiFontSizeChanged() {
            root.schedulePersist();
        }
        function onLeftPanelHotZoneSizeChanged() {
            root.schedulePersist();
        }
        function onRightPanelHotZoneSizeChanged() {
            root.schedulePersist();
        }
        function onLeftPanelHotZoneChanged() {
            root.schedulePersist();
        }
        function onRightPanelHotZoneChanged() {
            root.schedulePersist();
        }
        function onLockGraceSecondsChanged() {
            root.schedulePersist();
        }
        function onLeftPanelLockChanged() {
            root.schedulePersist();
        }
        function onRightPanelLockChanged() {
            root.schedulePersist();
        }
        function onLeftPanelWidthChanged() {
            root.schedulePersist();
        }
        function onLeftPanelWidgetChanged() {
            root.schedulePersist();
        }
        function onRightPanelWidthChanged() {
            root.schedulePersist();
        }
        function onHyprlandChanged() {
            root.schedulePersist();
        }
        function onBarBlurChanged() {
            root.schedulePersist();
        }
        function onBarBlurPassesChanged() {
            root.schedulePersist();
        }
        function onBarBlurSizeChanged() {
            root.schedulePersist();
        }
        function onDynamicThemeColorsChanged() {
            root.schedulePersist();
        }
        function onDynamicThemeVariantsChanged() {
            root.schedulePersist();
        }
        function onWaifuChanged() {
            root.schedulePersist();
        }
        function onBooruChanged() {
            root.schedulePersist();
        }
        function onChatBotApiChanged() {
            root.schedulePersist();
        }
        function onAlwaysOnWidgetVisibilityChanged() {
            root.schedulePersist();
        }
        function onKeyStrokeVisualizerVisibilityChanged() {
            root.schedulePersist();
        }
        function onKeyStrokeVisualizerAnchorChanged() {
            root.schedulePersist();
        }
        function onFileManagerChanged() {
            root.schedulePersist();
        }
    }
}
