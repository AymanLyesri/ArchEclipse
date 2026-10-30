pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services
import qs.theme

// Tracks island/window handles by monitor for IPC lookup: side islands register as
// "left-island-<monitorName>" plus a bare alias; windows keep their own keys.
QtObject {
    id: root

    readonly property string monitorName: {
        const mon = Hyprland.focusedMonitor
        return mon ? mon.name : Quickshell.env("MONITOR_NAME") || "eDP-1"
    }

    property var _windows: ({})

    function register(name, window) {
        root._windows[name] = window
    }

    function unregister(name) {
        delete root._windows[name]
    }

    // No auto-unregister helper: the engine does not expose `destroyed` as a connectable
    // value, so each island unregisters in its own Component.onDestruction block.

    function get(name) {
        return root._windows[name] || null
    }

    function toggle(name) {
        const w = root.get(name)
        if (w) w.visible = !w.visible
    }

    // Optional `target` ("provider.field") lets the destination widget scroll to and
    // highlight a field; requests queue per monitor so only that island consumes one.
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
