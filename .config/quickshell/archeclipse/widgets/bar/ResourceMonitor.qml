import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.theme
import qs.services
import qs.widgets.shared

// Port of Utilities.tsx ResourceMonitor — CPU / RAM / GPU horizontal bars,
// stacked vertically (one on top of the other).
// Hover/click pulses the system-monitor island (BarState "system").
// Middle-click dispatches to workspace 5 (monitor workspace).
Item {
    id: root
    // Fixed footprint in the bar, but bars stretch to full widget width —
    // if the parent gives us more room the tracks expand with it.
    width: 70
    implicitWidth: 70
    Layout.fillWidth: true
    Layout.preferredWidth: 70
    height: Theme.barContentHeight
    implicitHeight: Theme.barContentHeight

    readonly property var res: SysInfo.systemResources
    // GPU load arrives as 0-100; normalize to 0-1 here.
    readonly property real cpuFrac: (res?.cpuLoad ?? null) !== null ? Math.max(0, Math.min(1, res.cpuLoad / 100)) : -1
    readonly property real ramFrac: (res?.ramUsedGB ?? null) !== null && (res?.ramTotalGB ?? null) ? Math.max(0, Math.min(1, res.ramUsedGB / res.ramTotalGB)) : -1
    readonly property real gpuFrac: {
        const loads = (res?.gpus ?? []).map(g => g.load).filter(l => l !== null && l !== undefined);
        if (!loads.length)
            return -1;
        return Math.max(0, Math.min(1, Math.max(...loads) / 100));
    }
    readonly property string gpuTip: {
        const gpus = res?.gpus ?? [];
        if (!gpus.length)
            return "GPU: N/A";
        return gpus.map(g => `${g.driver}: ${g.load ?? "N/A"}%`).join(" | ");
    }

    // (18px bar height - 2 * 3px spacing) / 3 = 4px per bar
    readonly property int barHeight: 4

    function pulseIsland(holdMs) {
        BarState.activate("system", holdMs);
    }

    // Click layer underneath — bar Items are mouse-transparent so clicks
    // fall through to here from anywhere on the stack.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                // Jump to the monitor workspace.
                Hyprland.dispatch("workspace 5");
                return;
            }
            // Left-click pins the island; clicking again dismisses it.
            if (BarState.state === "system")
                BarState.deactivate("system");
            else
                BarState.activate("system", 0);
        }
    }

    Column {
        id: stack
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Repeater {
            model: [
                {
                    frac: root.cpuFrac,
                    color: "#ff9f1c",
                    tip: root.res ? `CPU Usage ${Number(root.res.cpuLoad).toFixed(1)}%` : "CPU: N/A"
                },
                {
                    frac: root.ramFrac,
                    color: "#4aa8ff",
                    tip: root.res ? `RAM Usage ${Math.round(root.ramFrac * 100)}% (${Number(root.res.ramUsedGB).toFixed(2)}/${Number(root.res.ramTotalGB).toFixed(2)} GB)` : "RAM: N/A"
                },
                {
                    frac: root.gpuFrac,
                    color: "#ff5d5d",
                    tip: root.gpuTip
                }
            ]

            Item {
                id: barItem
                required property var modelData
                // -1 = no data -> hide bar
                readonly property real frac: modelData.frac
                visible: frac >= 0

                // Expand if there is place.
                width: stack.width
                height: root.barHeight

                Rectangle {
                    id: track
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.15)

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, barItem.frac))
                        height: parent.height
                        radius: parent.radius
                        color: barItem.modelData.color
                        Behavior on width { NumberAnimation { duration: 150 } }
                    }
                }

                AppTooltip {
                    visible: barHover.hovered
                    text: barItem.modelData.tip
                    delay: 500
                }

                // Hover dwell (Settings.revealInPressure, 0 = instant) so
                // brushing the cursor across the bar doesn't pulse the
                // island by accident.
                Timer {
                    id: dwellTimer
                    interval: Settings.revealInPressure
                    repeat: false
                    onTriggered: root.pulseIsland(3000)
                }

                HoverHandler {
                    id: barHover
                    onHoveredChanged: {
                        if (barHover.hovered) {
                            if (Settings.revealInPressure <= 0)
                                root.pulseIsland(3000);
                            else
                                dwellTimer.restart();
                        } else {
                            dwellTimer.stop();
                        }
                    }
                }
            }
        }
    }
}
