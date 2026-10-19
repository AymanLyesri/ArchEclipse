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
    // and briefly highlight a specific field after switching. Requests are
    // queued by monitor so only the destination island can consume one.
    function selectLeftTab(tabName, target, monitorName) {
        const monitor = monitorName || root.monitorName;
        Settings.setLeftPanelWidgetFor(monitor, tabName);
        BarState.activate("left", 0, monitor);
        if (target !== undefined)
            root.setPendingTarget(target, monitor);
    }

    property var pendingTargets: ({})
    function setPendingTarget(target, monitorName) {
        const monitor = monitorName || root.monitorName;
        if (!monitor)
            return;
        const next = Object.assign({}, root.pendingTargets || {});
        next[monitor] = String(target || "");
        root.pendingTargets = next;
    }

    function takePendingTarget(monitorName): string {
        const monitor = monitorName || root.monitorName;
        if (!monitor)
            return "";
        const next = Object.assign({}, root.pendingTargets || {});
        const target = String(next[monitor] || "");
        if (target !== "") {
            delete next[monitor];
            root.pendingTargets = next;
        }
        return target;
    }
}
