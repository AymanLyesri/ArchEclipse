import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import qs.theme
import qs.services
import qs.bar

// Port of Utilities.tsx ResourceMonitor — CPU / RAM / GPU circular rings.
// Clicking dispatches to workspace 5 (AGS Gtk.GestureClick); hovering reveals
// the full SystemResources popover (AGS Gtk.Popover + EventControllerMotion).
Row {
    id: root
    spacing: 10

    readonly property var res: SysInfo.systemResources
    readonly property real maxGpu: {
        const loads = (res?.gpus ?? []).map(g => g.load).filter(l => l !== null);
        return loads.length ? Math.max(...loads) / 100 : 0;
    }

    // Hover popover (AGS ResourceMonitor popover with SystemResources)
    Popup {
        id: resPopup
        parent: root
        y: root.height + 6
        x: root.width / 2 - resPopup.implicitWidth / 2
        padding: 6
        closePolicy: Popup.NoAutoClose
        background: Rectangle { color: Theme.moduleBg; radius: 8; border.color: Theme.border }

        SystemResourcesWidget {
            width: 300
            className: "resource-monitor-popover"
        }

        // Stay open while hovering popover (AGS popoverMotion)
        HoverHandler {
            onHoveredChanged: {
                if (hovered) root._hideTimer.stop()
                else root._hideTimer.start()
            }
        }
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) { root._hideTimer.stop(); resPopup.open() }
            else root._hideTimer.start()
        }
    }

    Timer {
        id: _hideTimer
        interval: 80
        onTriggered: resPopup.close()
    }

    Repeater {
        model: [
            { icon: "", val: root.res?.cpuLoad ?? null, tip: "CPU", tooltip: root.res?.cpuLoad !== undefined ? `CPU Usage ${root.res.cpuLoad}%` : "" },
            { icon: "", val: (root.res?.ramUsedGB && root.res?.ramTotalGB) ? root.res.ramUsedGB / root.res.ramTotalGB : null, tip: "RAM", tooltip: (root.res?.ramUsedGB && root.res?.ramTotalGB) ? `RAM Usage ${Math.round(root.res.ramUsedGB / root.res.ramTotalGB * 100)}%` : "" },
            { icon: "󱤟", val: root.maxGpu || null, tip: "GPU", tooltip: (root.res?.gpus?.length ?? 0) > 0 ? (root.res.gpus.map(g => `${g.driver}: ${g.load ?? "N/A"}%`).join(" | ")) : "" }
        ]

        Item {
            id: ringItem
            required property var modelData
            readonly property real frac: modelData.val === null ? 0 : Math.min(1, modelData.val)
            visible: modelData.val !== null && modelData.val !== undefined

            width: 18; height: 18
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: canvas
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const cx = width / 2, cy = height / 2, r = width / 2 - 1.5;
                    ctx.lineWidth = 2;
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.15);
                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
                    if (ringItem.frac > 0) {
                        ctx.strokeStyle = Theme.foregroundSecondary;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + ringItem.frac * Math.PI * 2);
                        ctx.stroke();
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: ringItem.modelData.icon
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 9
            }

            ToolTip.visible: ringItemMa.containsMouse && ringItem.modelData.tooltip !== ""
            ToolTip.text: ringItem.modelData.tooltip

            MouseArea {
                id: ringItemMa
                anchors.fill: parent
                hoverEnabled: true
                // AGS: clicking the whole resource monitor dispatches workspace 5
                onClicked: Hyprland.dispatch("workspace 5")
            }
        }
    }
}
