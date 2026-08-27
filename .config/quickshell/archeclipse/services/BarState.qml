pragma Singleton
import Quickshell
import QtQuick
import qs.theme

Singleton {
    id: root

    // Priority map (compact base 0 < recording 40 < expanded 60 < pulses 80 < search 100)
    property var priority: {
        "compact": 0,
        "recording": 40,
        "expanded": 60,
        "volume": 80,
        "brightness": 80,
        "network": 80,
        "player": 80,
        "search": 100
    }

    // Active states with hold timers
    property var activeStates: {}

    // Bar shown overrides (per monitor)
    property var barShown: {}

    // Hyprland tick for reactive deps
    property int hyprlandTick: 0

    // Current resolved state
    property string state: "compact"

    // Hold timers
    property var holdTimers: {}

    // Debounce timer
    property var debounceTimer: null

    // Settings reference
    property var settings: qs.theme.Settings

    // Lock setting (from settings)
    property bool lock: true
    property bool expanded: false
    property bool orientation: true
    property bool smartHide: false
    property bool fullWidth: false

    Component.onCompleted: {
        root.settings = Settings
        root.lock = Settings.barLock ?? true
        root.expanded = Settings.barExpanded ?? false
        root.orientation = Settings.barOrientation ?? true
        root.smartHide = Settings.barSmartHide ?? false
        root.fullWidth = Settings.barFullWidth ?? false

        root.activeStates = {
            compact: { priority: root.priority.compact }
        }
        if (root.expanded) {
            root.activate("expanded", 0)
        }
    }

    // Resolve highest priority active state
    function resolveState(): string {
        var best = "compact"
        var bestPriority = -Infinity
        for (var name in root.activeStates) {
            var entry = root.activeStates[name]
            if (entry.priority > bestPriority) {
                best = name
                bestPriority = entry.priority
            }
        }
        return best
    }

    // Activate a state (with optional holdMs for auto-deactivate)
    function activate(name, holdMs) {
        var priority = root.priority[name]
        if (priority === undefined) return

        // Cancel existing timer for this state
        if (root.holdTimers[name]) {
            root.holdTimers[name].stop()
            root.holdTimers[name] = null
        }

        root.activeStates[name] = { priority: priority }

        if (holdMs !== undefined) {
            root.holdTimers[name] = Timer.singleShot(holdMs, () => {
                root.deactivate(name)
            })
        }

        root.debounceResolve()
    }

    // Deactivate a state
    function deactivate(name) {
        if (name === "compact") return // base is permanent

        // Don't deactivate expanded if lock is on
        if (name === "expanded" && root.expanded) return

        if (root.holdTimers[name]) {
            root.holdTimers[name].stop()
            root.holdTimers[name] = null
        }

        delete root.activeStates[name]
        root.debounceResolve()
    }

    // Debounced resolve (100ms)
    function debounceResolve() {
        if (root.debounceTimer) {
            root.debounceTimer.stop()
        }
        root.debounceTimer = Timer.singleShot(100, () => {
            root.state = root.resolveState()
        })
    }

    // Reveal bar for a monitor
    function revealBar(monitorName) {
        root.barShown[monitorName] = true
    }

    // Conceal bar for a monitor
    function concealBar(monitorName) {
        delete root.barShown[monitorName]
    }
}