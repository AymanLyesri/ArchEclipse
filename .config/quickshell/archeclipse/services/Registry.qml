pragma Singleton
import QtQuick
import Quickshell
import qs.services
import qs.theme

// Registry — tracks island/window handles by monitor name for IPC lookup.
// Side islands register themselves as "left-island-<monitorName>" (and the
// bare "left-island" alias); other windows keep their own keys.
QtObject {
    id: root

    readonly property string monitorName: {
        const mon = Quickshell.Hyprland?.focusedMonitor
        return mon ? mon.name : Quickshell.env("MONITOR_NAME") || "eDP-1"
    }

    property var _windows: ({})

    function register(name, window) {
        root._windows[name] = window
    }

    function unregister(name) {
        delete root._windows[name]
    }

    // NOTE: there is intentionally no trackIsland auto-unregister helper:
    // this engine does not expose the `destroyed` signal as a connectable
    // value (`item.destroyed === undefined` on live items, verified
    // 2026-09-13), so keyed entries are unregistered in each island's own
    // Component.onDestruction block (bare alias + keyed entry together).

    function get(name) {
        return root._windows[name] || null
    }

    function toggle(name) {
        const w = root.get(name)
        if (w) w.visible = !w.visible
    }

    // Optional `target` is a widget-defined key (e.g. an API key's
    // "provider.field" path) the destination widget can use to scroll to
    // and briefly highlight a specific field after switching. It's a
    // fire-and-forget request: the destination widget is expected to pick
    // it up from pendingTarget and clear it once handled.
    function selectLeftTab(tabName, target) {
        Settings.leftPanelWidget = tabName;
        BarState.activate("left", 0);
        if (target !== undefined)
            root.pendingTarget = target;
    }

    // Consumed by whichever widget becomes visible via selectLeftTab's
    // `target` argument; cleared by that widget once handled.
    property string pendingTarget: ""
}
