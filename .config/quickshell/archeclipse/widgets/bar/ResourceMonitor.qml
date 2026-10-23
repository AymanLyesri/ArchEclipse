import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.theme
import qs.services
import qs.widgets.shared

// Port of Utilities.tsx ResourceMonitor — CPU / RAM / GPU horizontal bars,
// stacked vertically (one on top of the other).
// Hover pulses the system-monitor island (BarState "system").
// Middle-click dispatches to workspace 5 (monitor workspace).
Item {
    id: root

    property string monitorName: ""
    // Fixed footprint in the bar, but bars stretch to full widget width —
    // if the parent gives us more room the tracks expand with it.
    width: 70
    implicitWidth: 70
    Layout.fillWidth: true
    Layout.preferredWidth: 70
    height: Theme.barContentHeight
    implicitHeight: Theme.barContentHeight

    readonly property var res: SysInfo.systemResources
    Component.onCompleted: SysInfo.acquireResources()
    Component.onDestruction: SysInfo.releaseResources()

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
    readonly property int barHeight: 2

    // Middle-click layer underneath — bar Items are mouse-transparent so
    // clicks fall through to here from anywhere on the stack. Left-click
    // is intentionally a no-op: opening is hover-only (Weather/Network
    // parity), the island pins itself while hovered via IslandHoverPin.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                // Jump to the monitor workspace.
                Hyprland.dispatch("workspace 5");
            }
        }
    }

    // Hover dwell (Settings.revealInPressure, 0 = instant) so brushing the
    // cursor across the bar doesn't pulse the island by accident.
    // Root-level (full widget) so the 3px inter-bar gaps can't reset the
    // dwell — the per-bar handlers below are tooltip-only.
    Timer {
        id: dwellTimer
        interval: Settings.revealInPressure
        repeat: false
        onTriggered: BarState.activate("system", 3000, root.monitorName)
    }

    HoverHandler {
        id: rootHover
        onHoveredChanged: {
            if (rootHover.hovered) {
                if (Settings.revealInPressure <= 0)
                    BarState.activate("system", 3000, root.monitorName);
                else
                    dwellTimer.restart();
            } else {
                dwellTimer.stop();
            }
        }
    }

    Column {
        id: stack
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Repeater {
            id: rep

            model: 3

            // Per-index lookup instead of a rebuilt JS-array model: every
            // sysmonitor tick (2s) used to re-create the whole bar tree,
            // which dominated idle CPU (bar visible = 15% core). Restore the
            // array-as-model form only for per-tick structural changes.
            readonly property var bars: [
                {
                    frac: root.cpuFrac,
                    color: Theme.chart1,
                    tip: root.res ? `CPU Usage ${Number(root.res.cpuLoad).toFixed(1)}%` : "CPU: N/A"
                },
                {
                    frac: root.ramFrac,
                    color: Theme.chart2,
                    tip: root.res ? `RAM Usage ${Math.round(root.ramFrac * 100)}% (${Number(root.res.ramUsedGB).toFixed(2)}/${Number(root.res.ramTotalGB).toFixed(2)} GB)` : "RAM: N/A"
                },
                {
                    frac: root.gpuFrac,
                    color: Theme.chart3,
                    tip: root.gpuTip
                }
            ]

            Item {
                id: barItem
                required property int index
                readonly property var modelData: rep.bars[index]
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
                    color: Theme.track

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, barItem.frac))
                        height: parent.height
                        radius: parent.radius
                        color: barItem.modelData.color
                        Behavior on width {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }
                    }
                }

                AppTooltip {
                    visible: barHover.hovered
                    text: barItem.modelData.tip
                    delay: 500
                }

                // Tooltip-only hover: the island pulse lives at root level
                // so inter-bar gaps can't reset the dwell.
                HoverHandler {
                    id: barHover
                }
            }
        }
    }
}
