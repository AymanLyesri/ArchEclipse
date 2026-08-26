pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Port of utils/monitor.ts — monitor name utilities
QtObject {
    id: root

    // Get monitor name from GdkMonitor or ShellScreen
    function getMonitorName(screen) {
        if (!screen) return "unknown";

        // If it's a Hyprland monitor object
        if (screen.name) return screen.name;

        // If it's a ShellScreen, use Hyprland mapping
        const hmon = Hyprland.monitorFor(screen);
        if (hmon && hmon.name) return hmon.name;

        // Fallback to screen name
        return screen.name || "unknown";
    }

    // Get all monitor names
    function getAllMonitorNames() {
        return Hyprland.monitors.map(m => m.name);
    }
}