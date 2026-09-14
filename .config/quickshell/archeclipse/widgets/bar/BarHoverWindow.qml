import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.widgets.bar
import qs.theme
import qs.services

// A thin edge strip that dwell-reveals the auto-hidden bar.
// (revealPressure<=0 → instant, else dwell revealPressure ms). The strip
// is only relevant when the bar is auto-hidden (unlocked).
PanelWindow {
    id: root

    required property ShellScreen screen
    readonly property string monitorName: {
        const hmon = Hyprland.monitorFor(screen);
        if (hmon && hmon.name) return hmon.name;
        return screen?.name ?? "unknown";
    }

    anchors { left: true; right: true; top: Settings.barOrientation; bottom: !Settings.barOrientation }

    exclusiveZone: -1
    color: "transparent"
    aboveWindows: true

    // hidden when the bar is locked (dwell has nothing to reveal)
    visible: !Settings.barLock

    implicitHeight: 5

    // Dwell state
    property bool atEdge: false
    Timer {
        id: dwellTimer
        interval: Settings.revealPressure
        repeat: false
        onTriggered: {
            root.atEdge = false
            BarState.revealBar(root.monitorName)
        }
    }

    HoverHandler {
        id: edgeHover
        enabled: !Settings.barLock
        onHoveredChanged: {
            if (hovered) {
                // threshold<=0 → instant reveal, else dwell
                if (Settings.revealPressure <= 0) {
                    BarState.revealBar(root.monitorName)
                } else {
                    root.atEdge = true
                    dwellTimer.restart()
                }
            } else {
                root.atEdge = false
                dwellTimer.stop()
            }
        }
    }

    // invisible hit surface
    Rectangle {
        anchors.fill: parent
        color: root.color
    }
}
