import QtQuick
import QtQuick.Controls
import qs.theme
import qs.services
import qs.widgets.shared

// Shared system-resources content used by both SystemMonitorIsland and the right panel's
// SystemResourcesWidget: wide lays cards out horizontally, narrow stacks them.
// Each metric group is a raised plate; the meters are the only accent on the surface, so the
// eye lands on the numbers and the fills rather than on card outlines.
Column {
    id: root
    spacing: Theme.spaceMd

    readonly property var stats: SysInfo.systemResources
    readonly property var gpus: stats?.gpus ?? []
    readonly property real cpuFrac: (stats?.cpuLoad ?? null) !== null ? Math.max(0, Math.min(1, stats.cpuLoad / 100)) : 0
    readonly property real ramFrac: (stats?.ramUsedGB && stats?.ramTotalGB) ? Math.max(0, Math.min(1, stats.ramUsedGB / stats.ramTotalGB)) : 0
    readonly property int totalCards: 2 + root.gpus.length
    readonly property bool stacked: width < 380
    readonly property real cardWidth: width <= 0 ? 0 : (root.stacked ? width : (width - Theme.spaceSm * (root.totalCards - 1)) / root.totalCards)

    Component.onCompleted: SysInfo.acquireResources()
    Component.onDestruction: SysInfo.releaseResources()

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

    // One metric plate: icon + label header, a meter, then key/value rows.
    component MetricCard: Rectangle {
        id: card

        property string glyph: ""
        property string label: ""
        property real frac: 0
        property var rows: []
        default property alias body: inner.data

        width: root.cardWidth
        height: inner.implicitHeight + Theme.spaceLg
        radius: Theme.radius
        color: Theme.surfaceRaised

        Column {
            id: inner
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.pad
            spacing: Theme.spaceSm

            Row {
                width: parent.width
                spacing: Theme.spaceXs + 2
                Text {
                    text: card.glyph
                    color: Theme.accent
                    font.pixelSize: Theme.typeBody
                    font.family: Theme.fontFamily
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    text: card.label
                    color: Theme.fg
                    font.pixelSize: Theme.typeLabel
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.letterSpacing: 0.4
                    elide: Text.ElideRight
                    width: parent.width - parent.spacing * 2 - chip.width
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    id: chip
                    text: Math.round(card.frac * 100) + "%"
                    color: Theme.accent
                    font.pixelSize: Theme.typeCaption
                    font.family: Theme.fontFamily
                    font.preferShaping: false
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Rectangle {
                width: parent.width
                height: 5
                radius: Theme.radius
                color: Theme.track

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, card.frac))
                    height: parent.height
                    radius: Theme.radius
                    color: Theme.accent

                    Behavior on width {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }
                }
            }
        }
    }

    // ---- header ----
    Row {
        width: parent.width
        spacing: Theme.spaceSm
        Label {
            text: "System Resources"
            font.pixelSize: Theme.typeSubtitle
            font.family: Theme.fontFamily
            font.bold: true
            color: Theme.fg
            width: parent.width - updatedLabel.width - Theme.spaceSm
            elide: Text.ElideRight
        }
        Label {
            id: updatedLabel
            text: root.stats ? "Updated " + (root.stats.updatedAt || "--") : "—"
            font.pixelSize: Theme.typeCaption
            font.family: Theme.fontFamily
            color: Theme.muted
        }
    }

    Label {
        visible: !root.stats
        text: "Collecting system stats…"
        color: Theme.muted
        font.pixelSize: Theme.typeLabel
        font.family: Theme.fontFamily
    }

    // ---- resource cards (Flow wraps to vertical when stacked) ----
    Flow {
        visible: root.stats
        width: parent.width
        spacing: Theme.spaceSm

        MetricCard {
            glyph: Icons.cpu
            label: root.stats?.cpuLabel || "CPU"
            frac: root.cpuFrac

            Text {
                text: "Load  " + root.fmt(root.stats?.cpuLoad, 1, "%")
                font.pixelSize: Theme.typeLabel
                font.family: Theme.fontFamily
                color: Theme.fgDim
            }
            Text {
                text: "Clock  " + root.fmt(root.stats?.clockGHz, 2, " GHz")
                font.pixelSize: Theme.typeLabel
                font.family: Theme.fontFamily
                color: Theme.fgDim
            }
            Text {
                text: "Temp  " + root.fmt(root.stats?.cpuTempC, 1, "°C")
                font.pixelSize: Theme.typeLabel
                font.family: Theme.fontFamily
                color: Theme.fgDim
            }
        }

        MetricCard {
            glyph: Icons.ram
            label: "RAM"
            frac: root.ramFrac

            Text {
                text: "Used  " + root.fmt(root.stats?.ramUsedGB, 2, " GB")
                font.pixelSize: Theme.typeLabel
                font.family: Theme.fontFamily
                color: Theme.fgDim
            }
            Text {
                text: "Free  " + root.fmt(root.stats?.ramFreeGB, 2, " GB")
                font.pixelSize: Theme.typeLabel
                font.family: Theme.fontFamily
                color: Theme.fgDim
            }
            Text {
                text: "Total  " + root.fmt(root.stats?.ramTotalGB, 2, " GB")
                font.pixelSize: Theme.typeLabel
                font.family: Theme.fontFamily
                color: Theme.fgDim
            }
        }

        // GPU cards (dynamic)
        Repeater {
            model: root.gpus
            delegate: MetricCard {
                required property var modelData
                readonly property real frac: (modelData.load ?? null) !== null ? Math.max(0, Math.min(1, modelData.load / 100)) : 0

                glyph: Icons.gpu
                label: modelData.label || "GPU"

                Text {
                    text: "Load  " + root.fmt(modelData.load, 1, "%")
                    font.pixelSize: Theme.typeLabel
                    font.family: Theme.fontFamily
                    color: Theme.fgDim
                }
                Text {
                    text: "Mem  " + root.gpuMem(modelData.memoryUsedGB, modelData.memoryTotalGB)
                    font.pixelSize: Theme.typeLabel
                    font.family: Theme.fontFamily
                    color: Theme.fgDim
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: "Temp  " + root.fmt(modelData.tempC, 1, "°C")
                    font.pixelSize: Theme.typeLabel
                    font.family: Theme.fontFamily
                    color: Theme.fgDim
                }
            }
        }
    }
}
