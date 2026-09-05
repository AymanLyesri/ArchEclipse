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

    // Show the left panel for a monitor and switch its active tab
    // (mirrors AGS QuickApps "Keybinds": show left-panel + setGlobalSetting leftPanel.widget).
    function selectLeftTab(tabName) {
        // find a registered left panel
        let panel = null
        for (const key in root._windows) {
            if (key.startsWith("left-panel-")) { panel = root._windows[key]; break }
        }
        if (!panel) return
        panel.visible = true
        if (panel.selectTab) panel.selectTab(tabName)
    }
}
