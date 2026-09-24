import QtQuick
import Quickshell.Io
import qs.services
import qs.theme

// Opt-in documentation capture lease. No authentication/lock/recording actions.
Item {
    id: root
    property bool active: false
    property string desiredState: ""
    property string monitor: ""
    property string widget: ""
    property var rightWidgets: null
    property var saved: null
    property double startedAt: 0

    Component.onCompleted: Registry.register("capture-session", root)
    Component.onDestruction: {
        root.restore();
        Registry.unregister("capture-session");
    }
    Timer {
        id: watchdog
        interval: 15000
        onTriggered: root.restore()
    }
    function reply(value) { return JSON.stringify(value); }
    function restore() {
        watchdog.stop();
        if (!saved) return {ok: true, restored: false};
        const s = saved;
        active = false;
        rightWidgets = null;
        desiredState = "";
        for (const name of Object.keys(BarState.activeStates || {}))
            BarState.deactivate(name);
        Settings.leftPanelWidget = s.tab;
        Launcher.lastQuery = s.query;
        Launcher.results = s.results;
        Launcher.selectedIndex = s.index;
        BarState.barShown = s.shown;
        for (const name of s.states) {
            // Do not resurrect a transient pulse after its original interval.
            const remaining = s.timers[name] ? s.timers[name] - (Date.now() - startedAt) : 0;
            if (!s.timers[name] || remaining > 0)
                BarState.activate(name, remaining);
        }
        BarState.state = BarState.resolveState();
        saved = null;
        return {ok: Settings.leftPanelWidget === s.tab,
                restored: true, state: BarState.state, tab: Settings.leftPanelWidget};
    }
    function inspectImages(item, result) {
        if (!item) return;
        // Inspect only visible visual descendants, not inactive cached tabs.
        if (item.visible === false) return;
        // Fading tiles are opacity 0 precisely while their thumbnails load.
        if (item.captureReady !== undefined) {
            result.wallpaperFound = true;
            if (!item.captureReady) result.loading++;
        }
        if (item.thumbSettled !== undefined && (!item.thumbSettled || item.opacity < 0.99))
            result.loading++;
        if (item.source !== undefined && item.status !== undefined) {
            if (item.status === 2) result.loading++;
            if (item.status === 3) result.errors++;
        }
        const children = item.children || [];
        for (let i = 0; i < children.length; i++) inspectImages(children[i], result);
    }
    IpcHandler {
        target: "capture"
        function begin(mon: string): string {
            if (root.active) return root.reply({ok: false, error: "Capture already active"});
            if (!Registry.get("capture-bar-" + mon)) return root.reply({ok: false, error: "Monitor bar unavailable"});
            const timers = {};
            for (const name of Object.keys(BarState.holdTimers || {})) {
                const t = BarState.holdTimers[name];
                if (t && t.running) timers[name] = t.interval;
            }
            root.saved = {tab: Settings.leftPanelWidget,
                states: Object.keys(BarState.activeStates || {}), timers: timers,
                shown: Object.assign({}, BarState.barShown || {}),
                query: Launcher.lastQuery, results: Launcher.results, index: Launcher.selectedIndex};
            root.monitor = mon;
            root.startedAt = Date.now();
            root.active = true;
            watchdog.restart();
            return root.reply({ok: true, tab: root.saved.tab, states: root.saved.states});
        }
        function select(name: string): string {
            if (!root.active) return root.reply({ok: false, error: "No capture lease"});
            const tabs = {"left-panel-settings": "SettingsWidget", "left-panel-keybinds": "KeyBinds",
                "left-panel-chatbot": "ChatBot", "left-panel-booru-1": "BooruViewer"};
            const states = {"app-launcher": "search", "wallpaper-switcher": "wallpaper",
                "workspace-overview": "overview", "right-panel-layout-1": "right", "right-panel-layout-2": "right"};
            if (!tabs[name] && !states[name]) return root.reply({ok: false, error: "Unsupported capture"});
            root.desiredState = "";
            for (const state of Object.keys(BarState.activeStates || {})) BarState.deactivate(state);
            const layouts = {
                "right-panel-layout-1": ["Waifu", "Media", "Calendar", "NotificationHistory"],
                "right-panel-layout-2": ["Calendar", "Media", "Waifu", "SystemResources"]
            };
            const defs = Settings.defaultRightPanelWidgets();
            root.rightWidgets = layouts[name] ? layouts[name].map(n =>
                Object.assign({}, defs.find(w => w.name === n), {enabled: true})) : null;
            root.widget = tabs[name] || "";
            if (root.widget) Settings.leftPanelWidget = root.widget;
            root.desiredState = root.widget ? "left" : states[name];
            BarState.activate(root.desiredState, 0);
            BarState.revealBar(root.monitor);
            if (name === "app-launcher") Launcher.runQuery("apps ");
            watchdog.restart();
            return root.reply({ok: true});
        }
        function status(): string {
            if (!root.active) return root.reply({ok: false, error: "Capture lease expired"});
            watchdog.restart();
            const bar = Registry.get("capture-bar-" + root.monitor);
            if (!bar) return root.reply({ok: false, error: "Bar unavailable"});
            const info = bar.captureGeometry();
            let ready = info.visible;
            if (root.desiredState === "left")
                ready = ready && BarState.leftOpen;
            else if (root.desiredState === "right")
                ready = ready && BarState.rightOpen;
            else
                ready = ready && info.displayed === root.desiredState && BarState.state === root.desiredState;
            const images = {loading: 0, errors: 0, wallpaperFound: false};
            root.inspectImages(bar.captureItem, images);
            ready = ready && images.loading === 0;
            if (root.widget) {
                const island = Registry.get("left-island-" + root.monitor);
                ready = ready && !!island && island.selectedWidget === root.widget && !!island.activeWidget;
                if (ready && root.widget === "KeyBinds") {
                    const item = island.activeWidget;
                    ready = !item.loading && item.totalBinds > 0 && item.revealCount >= item.totalBinds;
                }
                if (ready && root.widget === "BooruViewer") {
                    const item = island.activeWidget;
                    ready = item.progressStatus !== "loading" && item.progressStatus !== "error";
                }
            }
            if (root.desiredState === "wallpaper") ready = ready && images.wallpaperFound && images.errors === 0;
            if (root.desiredState === "search") ready = ready && Launcher.results.length > 0;
            return root.reply({ok: true, ready: ready, state: BarState.state,
                visible: info.visible, rect: info.rect, images: images,
                rightLayout: root.rightWidgets ? root.rightWidgets.map(w => w.name) : null});
        }
        function end(): string { return root.reply(root.restore()); }
    }
}
