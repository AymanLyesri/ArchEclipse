pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Mirrors the subset of ArchEclipse settings.json (cache/settings/settings.json)
// that the bar and panels consume. Values are read once at startup — the AGS settings UI
// remains the editor; this shell follows the same file so both stay in sync.
Singleton {
    id: root

    // --- simple booleans / ints / strings ---
    property bool barLock: true
    property bool barSmartHide: false
    property bool barExpanded: false
    property bool barFullWidth: false
    property real revealPressure: 250
    property bool barOrientation: true        // true = top
    property bool workspaceNumbers: false

    // bar layout toggles (AGS: bar.layout = [{name:"workspaces",enabled:true}, ...])
    property var barLayout: ({ workspaces: true, information: true, utilities: true })

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

    // Right panel widgets — mirrors AGS rightPanel.widgets (datalist with enabled flag)
    property var rightPanelWidgets: [
        { name: "Waifu",               icon: "\u{f004}", enabled: true },
        { name: "Media",               icon: "\u{f01d}", enabled: true },
        { name: "NotificationHistory", icon: "\u{f0f3}", enabled: true },
        { name: "ScriptTimer",         icon: "\u{f017}", enabled: false },
        { name: "Crypto",              icon: "\u{f15a}", enabled: false },
        { name: "Calendar",            icon: "\u{f073}", enabled: true },
        { name: "SystemResources",     icon: "\u{f080}", enabled: true },
    ]
    property bool autoWorkspaceSwitching: true

    // Bar-pinned crypto favorite (Information center), mirrors AGS crypto.favorite
    property var cryptoFavorite: ({ symbol: "", timeframe: "" })

    property var booru: ({
        api: ({ name: "Danbooru", value: "danbooru", url: "https://danbooru.donmai.us/", idSearchUrl: "https://danbooru.donmai.us/posts/" }),
        tags: ["-rating:explicit"],
        limit: 100,
        page: 1,
        columns: 3,
        bookmarks: [],
        pins: []
    })
    property var apiKeys: ({})

    // Waifu widget (AGS: waifuWidget setting group)
    property var waifu: null

    // Blur settings (AGS: bar.blur.size, bar.blur.passes, bar.blur.enabled)
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

    // Hyprland settings (AGS: hyprland.decoration.rounding, etc.)
    readonly property var hyprland: ({
        general: { border_size: 0 },
        decoration: {
            rounding: 16,
            blur: { enabled: true, size: 4, passes: 3 },
            shadow: { enabled: true, range: 15, render_power: 3 }
        }
    })

    // --- functions ---

    function fmt(d, f) {
        const p = (n) => n.toString().padStart(2, "0");
        if (f === "%I:%M %p") {
            let h = d.getHours() % 12; if (h === 0) h = 12;
            return `${p(h)}:${p(d.getMinutes())} ${d.getHours() < 12 ? "AM" : "PM"}`;
        }
        return `${p(d.getHours())}:${p(d.getMinutes())}`;
    }

    // Update a setting by dotted path and persist to settings.json
    function updateSetting(path, value) {
        // AGS dotted paths that map to flat QS properties (Singleton cannot
        // gain new properties at runtime, so root["rightPanel"] = {} throws).
        const aliases = {
            "rightPanel.widgets": "rightPanelWidgets",
            "crypto.favorite": "cryptoFavorite"
        };
        if (aliases[path] !== undefined) {
            root[aliases[path]] = value;
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
        // Reassign the top-level object so bindings on it re-evaluate
        // (mutating a JS sub-object alone emits no change signal).
        if (parts.length > 1) {
            root[parts[0]] = obj;
        }
        persist();
    }

    // Persist current settings back to the JSON file
    function persist() {
        try {
            const s = {
                "bar.lock": { value: root.barLock },
                "bar.smartHide": { value: root.barSmartHide },
                "bar.expanded": { value: root.barExpanded },
                "bar.fullWidth": { value: root.barFullWidth },
                "bar.revealPressure": { value: root.revealPressure },
                "bar.orientation": { value: root.barOrientation },
                "bar.workspaceNumbers": { value: root.workspaceNumbers },
                "dateFormat": root.dateFormat,
                "crypto.favorite": root.cryptoFavorite,
                "ui.opacity": { value: root.uiOpacity },
                "ui.scale": { value: root.uiScale },
                "ui.fontSize": { value: root.uiFontSize },
                "leftPanel.hotZoneSize": { value: root.leftPanelHotZoneSize },
                "rightPanel.hotZoneSize": { value: root.rightPanelHotZoneSize },
                "leftPanel.hotZone": { value: root.leftPanelHotZone },
                "rightPanel.hotZone": { value: root.rightPanelHotZone },
                "notifications.dnd": root.notifDnd,
                "leftPanel.lock": root.leftPanelLock,
                "rightPanel.lock": root.rightPanelLock,
                "leftPanel.exclusivity": root.leftPanelExclusivity,
                "rightPanel.exclusivity": root.rightPanelExclusivity,
                "leftPanel.width": { value: root.leftPanelWidth },
                "rightPanel.width": { value: root.rightPanelWidth },
                "rightPanel.widgets": root.rightPanelWidgets,
                "autoWorkspaceSwitching": { value: root.autoWorkspaceSwitching },
                "bar.layout": [
                    { name: "workspaces", enabled: root.barLayout.workspaces },
                    { name: "information", enabled: root.barLayout.information },
                    { name: "utilities", enabled: root.barLayout.utilities }
                ],
                "dynamicThemeColors": root.dynamicThemeColors,
                "dynamicThemeVariants": root.dynamicThemeVariants,
                "alwaysOnWidget": { "visibility": { value: root.alwaysOnWidgetVisibility } },
                "keyStrokeVisualizer": { "visibility": { value: root.keyStrokeVisualizerVisibility }, "anchor": root.keyStrokeVisualizerAnchor },
                "fileManager": root.fileManager,
                "bar.blur": { value: root.barBlur },
                "bar.blurSize": { value: root.barBlurSize },
                "bar.blurPasses": { value: root.barBlurPasses },
                "profilePicturePath": root.profilePicturePath,
                "waifuWidget": {
                    current: root.waifu
                },
                "booru": {
                    api: root.booru.api,
                    tags: root.booru.tags,
                    limit: root.booru.limit,
                    page: root.booru.page,
                    columns: root.booru.columns,
                    bookmarks: root.booru.bookmarks,
                    pins: root.booru.pins
                },
                "apiKeys": root.apiKeys
            };
            _file.setText(JSON.stringify(s, null, 2));
        } catch (e) {
            console.warn("[Settings] Failed to persist:", e);
        }
    }

    // FileView for settings
    property FileView _file: FileView {
        path: `${Quickshell.env("HOME")}/.config/ags/cache/settings/settings.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: reload()
    }

    function reload() {
        try {
            const text = _file.text()
            if (text !== "" && text.trim().startsWith("{")) {
                const s = JSON.parse(text)
                root.barLock = s.bar?.lock?.value ?? true
                root.barSmartHide = s.bar?.smartHide?.value ?? false
                root.barExpanded = s.bar?.expanded?.value ?? false
                root.barFullWidth = s.bar?.fullWidth?.value ?? false
                root.revealPressure = s.bar?.revealPressure?.value ?? 250
                root.barOrientation = s.bar?.orientation?.value ?? true
                root.workspaceNumbers = s.bar?.workspaceNumbers?.value ?? false

                // bar layout
                const layout = {};
                if (Array.isArray(s.bar?.layout)) {
                    for (const w of s.bar.layout) {
                        layout[w.name] = !!w.enabled;
                    }
                }
                root.barLayout = { workspaces: layout.workspaces ?? true, information: layout.information ?? true, utilities: layout.utilities ?? true };

                root.dateFormat = s.dateFormat ?? "%H:%M"
                root.cryptoFavorite = s.crypto?.favorite ?? { symbol: "", timeframe: "" }
                root.uiOpacity = s.ui?.opacity?.value ?? 0.618
                root.uiScale = s.ui?.scale?.value ?? 10
                root.uiFontSize = s.ui?.fontSize?.value ?? 12

                root.leftPanelHotZoneSize = s.leftPanel?.hotZoneSize?.value ?? 5
                root.rightPanelHotZoneSize = s.rightPanel?.hotZoneSize?.value ?? 5
                root.leftPanelHotZone = s.leftPanel?.hotZone?.value ?? true
                root.rightPanelHotZone = s.rightPanel?.hotZone?.value ?? true
                root.notifDnd = s.notifications?.dnd ?? false
                root.leftPanelLock = !!s.leftPanel?.lock
                root.rightPanelLock = !!s.rightPanel?.lock
                root.leftPanelExclusivity = s.leftPanel?.exclusivity ?? true
                root.rightPanelExclusivity = s.rightPanel?.exclusivity ?? true
                root.leftPanelWidth = s.leftPanel?.width?.value ?? 400
                root.rightPanelWidth = s.rightPanel?.width?.value ?? 250
                root.rightPanelWidgets = s.rightPanel?.widgets ?? root.rightPanelWidgets
                root.autoWorkspaceSwitching = s.autoWorkspaceSwitching?.value ?? true

                root.booru = {
                    api: s.booru?.api ?? { name: "Danbooru", value: "danbooru", url: "https://danbooru.donmai.us/", idSearchUrl: "https://danbooru.donmai.us/posts/" },
                    tags: s.booru?.tags ?? ["-rating:explicit"],
                    limit: s.booru?.limit ?? 100,
                    page: s.booru?.page ?? 1,
                    columns: s.booru?.columns ?? 3,
                    bookmarks: s.booru?.bookmarks ?? [],
                    pins: s.booru?.pins ?? []
                }
                root.apiKeys = s.apiKeys ?? {}

                // Waifu widget
                root.waifu = s.waifuWidget?.current ?? null

                // Blur settings
                root.barBlur = s.bar?.blur?.value ?? true
                root.barBlurPasses = s.bar?.blurPasses?.value ?? 3
                root.barBlurSize = s.bar?.blurSize?.value ?? 4

                root.dynamicThemeColors = s.dynamicThemeColors ?? true
                root.dynamicThemeVariants = s.dynamicThemeVariants ?? true

                // Always-on widget visibility
                root.alwaysOnWidgetVisibility = s.alwaysOnWidget?.visibility?.value ?? true

                // KeyStrokeVisualizer
                root.keyStrokeVisualizerVisibility = s.keyStrokeVisualizer?.visibility?.value ?? false
                root.keyStrokeVisualizerAnchor = s.keyStrokeVisualizer?.anchor ?? ["bottom", "left"]

                // File manager
                root.fileManager = s.fileManager ?? ""

                // Profile picture path
                root.profilePicturePath = s.profilePicturePath ?? ""

                // Hyprland settings
                root.hyprland = {
                    general: { border_size: s.hyprland?.general?.border_size?.value ?? 0 },
                    decoration: {
                        rounding: s.hyprland?.decoration?.rounding?.value ?? 16,
                        blur: {
                            enabled: s.hyprland?.decoration?.blur?.enabled?.value ?? true,
                            size: s.hyprland?.decoration?.blur?.size?.value ?? 4,
                            passes: s.hyprland?.decoration?.blur?.passes?.value ?? 3
                        },
                        shadow: {
                            enabled: s.hyprland?.decoration?.shadow?.enabled?.value ?? true,
                            range: s.hyprland?.decoration?.shadow?.range?.value ?? 15,
                            render_power: s.hyprland?.decoration?.shadow?.render_power?.value ?? 3
                        }
                    }
                }
            }
        } catch (e) {
            console.warn("[Settings] parse failed:", e)
        }
    }

    Component.onCompleted: {
        reload()
    }

    // Auto-persist: debounce writes so the settings file isn't thrashed
    // by rapid UI toggles (e.g. dragging the opacity slider).
    property Timer _persistTimer: Timer {
        interval: 250
        onTriggered: persist()
    }
    function schedulePersist() { _persistTimer.start() }

    // Watch key settings properties for changes and auto-persist
    Connections {
        target: root
        function onBarLockChanged() { root.schedulePersist() }
        function onBarSmartHideChanged() { root.schedulePersist() }
        function onBarExpandedChanged() { root.schedulePersist() }
        function onBarFullWidthChanged() { root.schedulePersist() }
        function onRevealPressureChanged() { root.schedulePersist() }
        function onBarOrientationChanged() { root.schedulePersist() }
        function onWorkspaceNumbersChanged() { root.schedulePersist() }
        function onDateFormatChanged() { root.schedulePersist() }
        function onUiOpacityChanged() { root.schedulePersist() }
        function onUiScaleChanged() { root.schedulePersist() }
        function onUiFontSizeChanged() { root.schedulePersist() }
        function onLeftPanelHotZoneSizeChanged() { root.schedulePersist() }
        function onRightPanelHotZoneSizeChanged() { root.schedulePersist() }
        function onLeftPanelHotZoneChanged() { root.schedulePersist() }
        function onRightPanelHotZoneChanged() { root.schedulePersist() }
        function onNotifDndChanged() { root.schedulePersist() }
        function onLeftPanelLockChanged() { root.schedulePersist() }
        function onRightPanelLockChanged() { root.schedulePersist() }
        function onLeftPanelWidthChanged() { root.schedulePersist() }
        function onRightPanelWidthChanged() { root.schedulePersist() }
        function onAutoWorkspaceSwitchingChanged() { root.schedulePersist() }
        function onBarBlurChanged() { root.schedulePersist() }
        function onBarBlurPassesChanged() { root.schedulePersist() }
        function onBarBlurSizeChanged() { root.schedulePersist() }
        function onDynamicThemeColorsChanged() { root.schedulePersist() }
        function onDynamicThemeVariantsChanged() { root.schedulePersist() }
        function onProfilePicturePathChanged() { root.schedulePersist() }
        function onWaifuChanged() { root.schedulePersist() }
        function onBooruChanged() { root.schedulePersist() }
        function onAlwaysOnWidgetVisibilityChanged() { root.schedulePersist() }
        function onKeyStrokeVisualizerVisibilityChanged() { root.schedulePersist() }
        function onKeyStrokeVisualizerAnchorChanged() { root.schedulePersist() }
        function onFileManagerChanged() { root.schedulePersist() }
    }
}