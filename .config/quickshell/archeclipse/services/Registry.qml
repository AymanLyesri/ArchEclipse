pragma Singleton
import QtQuick
import Quickshell

// Registry — tracks panel windows by monitor name for IPC lookup.
// Panels register themselves on Component.onCompleted with a key like
// "left-panel-<monitorName>" so Ipc.togglePanel and HotZone can find them.
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

    function get(name) {
        return root._windows[name] || null
    }

    function toggle(name) {
        const w = root.get(name)
        if (w) w.visible = !w.visible
    }
}
