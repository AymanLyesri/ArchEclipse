pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Port of utils/window.tsx — window management helpers for panels and popups
QtObject {
    id: root

    // Registry of windows by name (populated by panels on Component.onCompleted)
    property var windows: ({})

    function register(name, win) {
        const n = Object.assign({}, windows);
        n[name] = win;
        windows = n;
    }

    function unregister(name) {
        const n = Object.assign({}, windows);
        delete n[name];
        windows = n;
    }

    function showWindow(name) {
        const w = windows[name];
        if (w) {
            w.visible = true;
            return true;
        }
        console.warn(`[Window] Window not found: ${name}`);
        return false;
    }

    function hideWindow(name) {
        const w = windows[name];
        if (w) {
            w.visible = false;
            return true;
        }
        return false;
    }

    function toggleWindow(name) {
        const w = windows[name];
        if (w) {
            w.visible = !w.visible;
            return true;
        }
        return false;
    }

    function getWindow(name) {
        return windows[name] || null;
    }
}