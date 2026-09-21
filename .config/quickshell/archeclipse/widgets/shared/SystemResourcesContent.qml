import QtQuick
import QtQuick.Controls
import qs.theme
import qs.services
import qs.widgets.shared

// Shared system-resources content — single source of truth used by both
// the bar's SystemMonitorIsland and the right panel's SystemResourcesWidget.
// Width-driven: wide (>=380px) lays cards out horizontally, narrow stacks
// them full-width (Flow wraps automatically).
Column {
    id: root
    spacing: 8

    readonly property var stats: SysInfo.systemResources
    readonly property var gpus: stats?.gpus ?? []
    readonly property real cpuFrac: (stats?.cpuLoad ?? null) !== null ? Math.max(0, Math.min(1, stats.cpuLoad / 100)) : 0
    readonly property real ramFrac: (stats?.ramUsedGB && stats?.ramTotalGB) ? Math.max(0, Math.min(1, stats.ramUsedGB / stats.ramTotalGB)) : 0
    readonly property int totalCards: 2 + root.gpus.length
    readonly property bool stacked: width < 380
    readonly property real cardWidth: width <= 0 ? 0 : (root.stacked ? width : (width - 8 * (root.totalCards - 1)) / root.totalCards)

    function fmt(v, digits, suffix) {
        if (v === null || v === undefined || (typeof v === "number" && isNaN(v)))
            return "N/A";
        return Number(v).toFixed(digits) + (suffix ?? "");
    }
    function gpuMem(used, total) {
        if (used === null || used === undefined)
            return "N/A";
        if (total === null || total === undefined)
            return Number(used).toFixed(2) + " GB";
        return Number(used).toFixed(2) + "/" + Number(total).toFixed(2) + " GB";
    }

    // ---- header ----
    Row {
        width: parent.width
        spacing: 8
        Label {
            text: "System Resources"
            font.pixelSize: Theme.fontSize + 2
            font.bold: true
            color: Theme.fg
            width: parent.width - updatedLabel.width - 8
            elide: Text.ElideRight
        }
        Label {
            id: updatedLabel
            text: root.stats ? "Updated: " + (root.stats.updatedAt || "--") : "Updated: --"
            font.pixelSize: Theme.fontSize - 2
            color: Theme.fgDim
        }
    }

    Label {
        visible: !root.stats
        text: "Collecting system stats…"
        color: Theme.fgDim
        font.pixelSize: Theme.fontSize
    }

    // ---- resource cards (Flow wraps to vertical when stacked) ----
    Flow {
        visible: root.stats
        width: parent.width
        spacing: 8

        // CPU card
        Rectangle {
            width: root.cardWidth
            height: cpuCol.height + 16
            radius: 8
            color: Theme.surface
            border.color: Theme.border
            Column {
                id: cpuCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 8
                spacing: 4
                Text {
                    text: " " + (root.stats?.cpuLabel || "CPU")
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    font.family: Theme.fontFamily
                    color: Theme.fg
                    elide: Text.ElideRight
                    width: parent.width
                }
                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Theme.color8
                    Rectangle {
                        width: parent.width * root.cpuFrac
                        height: parent.height
                        radius: 2
                        color: Theme.accent
                        Behavior on width {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }
                    }
                }
                Text { text: "Load: " + root.fmt(root.stats?.cpuLoad, 1, "%"); font.pixelSize: Theme.fontSize - 1; font.family: Theme.fontFamily; color: Theme.fg }
                Text { text: "Clock: " + root.fmt(root.stats?.clockGHz, 2, " GHz"); font.pixelSize: Theme.fontSize - 1; font.family: Theme.fontFamily; color: Theme.fg }
                Text { text: "Temp: " + root.fmt(root.stats?.cpuTempC, 1, "°C"); font.pixelSize: Theme.fontSize - 1; font.family: Theme.fontFamily; color: Theme.fg }
            }
        }

        // RAM card
        Rectangle {
            width: root.cardWidth
            height: ramCol.height + 16
            radius: 8
            color: Theme.surface
            border.color: Theme.border
            Column {
                id: ramCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 8
                spacing: 4
                Text {
                    text: " RAM"
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    font.family: Theme.fontFamily
                    color: Theme.fg
                }
                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Theme.color8
                    Rectangle {
                        width: parent.width * root.ramFrac
                        height: parent.height
                        radius: 2
                        color: Theme.accent
                        Behavior on width {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }
                    }
                }
                Text { text: "Used: " + root.fmt(root.stats?.ramUsedGB, 2, " GB"); font.pixelSize: Theme.fontSize - 1; font.family: Theme.fontFamily; color: Theme.fg }
                Text { text: "Free: " + root.fmt(root.stats?.ramFreeGB, 2, " GB"); font.pixelSize: Theme.fontSize - 1; font.family: Theme.fontFamily; color: Theme.fg }
                Text { text: "Total: " + root.fmt(root.stats?.ramTotalGB, 2, " GB"); font.pixelSize: Theme.fontSize - 1; font.family: Theme.fontFamily; color: Theme.fg }
            }
        }

        // GPU cards (dynamic)
        Repeater {
            model: root.gpus
            Rectangle {
                id: gpuCard
                required property var modelData
                required property int index
                width: root.cardWidth
                height: gpuCol.height + 16
                radius: 8
                color: Theme.surface
                border.color: Theme.border
                readonly property real frac: (modelData.load ?? null) !== null ? Math.max(0, Math.min(1, modelData.load / 100)) : 0
                Column {
                    id: gpuCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 8
                    spacing: 4
                    Text {
                        text: "󱤟 " + (gpuCard.modelData.label || "GPU")
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        font.family: Theme.fontFamily
                        color: Theme.fg
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Theme.color8
                        Rectangle {
                            width: parent.width * gpuCard.frac
                            height: parent.height
                            radius: 2
                            color: Theme.accent
                            Behavior on width {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }
                        }
                    }
                    Text { text: "Load: " + root.fmt(gpuCard.modelData.load, 1, "%"); font.pixelSize: Theme.fontSize - 1; font.family: Theme.fontFamily; color: Theme.fg }
                    Text { text: "Mem: " + root.gpuMem(gpuCard.modelData.memoryUsedGB, gpuCard.modelData.memoryTotalGB); font.pixelSize: Theme.fontSize - 1; font.family: Theme.fontFamily; color: Theme.fg; elide: Text.ElideRight; width: parent.width }
                    Text { text: "Temp: " + root.fmt(gpuCard.modelData.tempC, 1, "°C"); font.pixelSize: Theme.fontSize - 1; font.family: Theme.fontFamily; color: Theme.fg }
                }
            }
        }
    }
}
