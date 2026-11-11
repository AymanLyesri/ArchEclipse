import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.services
import qs.widgets.shared

// Shared system-resources content used by both SystemMonitorIsland and the right panel's
// SystemResourcesWidget. One hero number per subsystem, a meter, then a stat grid: the layout
// answers "how loaded is it" before "what are the details". Wide pools CPU/RAM side by side;
// GPUs always take a full row because they carry the most fields.
Column {
    id: root
    spacing: Theme.spaceMd

    readonly property var stats: SysInfo.systemResources
    readonly property var gpus: stats?.gpus ?? []
    readonly property real cpuFrac: (stats?.cpuLoad ?? null) !== null ? Math.max(0, Math.min(1, stats.cpuLoad / 100)) : 0
    readonly property real ramFrac: (stats?.ramUsedGB && stats?.ramTotalGB) ? Math.max(0, Math.min(1, stats.ramUsedGB / stats.ramTotalGB)) : 0
    // CPU and RAM pair up only when each card keeps room for three stat cells.
    readonly property bool twoUp: root.width >= 460

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
            return Number(used).toFixed(1) + " GB";
        return Number(used).toFixed(1) + "/" + Number(total).toFixed(1) + " GB";
    }
    // Load colour is state, and it is always paired with the number itself.
    function loadColor(frac) {
        return frac >= 0.85 ? Theme.danger : Theme.accent;
    }

    component StatCell: Column {
        property string value: ""
        property string label: ""
        spacing: 0

        Text {
            width: parent.width
            text: parent.value
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeLabel
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: parent.label
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeCaption
            elide: Text.ElideRight
        }
    }

    // One subsystem plate: label + hero value header, meter, then evenly split stats.
    component MetricCard: Rectangle {
        id: card

        property string glyph: ""
        property string label: ""
        property string primary: ""
        property string unit: ""
        property real frac: 0
        property var statItems: []

        width: parent ? parent.width : 0
        height: inner.implicitHeight + Theme.pad * 2
        radius: Theme.radius
        color: Theme.surfaceRaised

        Column {
            id: inner
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.pad
            spacing: Theme.spaceSm

            RowLayout {
                width: parent.width
                spacing: Theme.spaceXs + 2

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: card.glyph
                    color: root.loadColor(card.frac)
                    font.pixelSize: Theme.typeBody
                    font.family: Theme.fontFamily
                }
                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: card.label
                    color: Theme.fgDim
                    font.pixelSize: Theme.typeCaption
                    font.family: Theme.fontFamily
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                    elide: Text.ElideRight
                }
                // Hero value: the first thing read, and the only large type on the plate.
                Text {
                    Layout.alignment: Qt.AlignBaseline
                    text: card.primary
                    color: root.loadColor(card.frac)
                    font.pixelSize: Theme.typeTitle
                    font.family: Theme.fontFamily
                    font.weight: Font.DemiBold
                    font.preferShaping: false
                }
                Text {
                    Layout.alignment: Qt.AlignBaseline
                    visible: card.unit !== ""
                    text: card.unit
                    color: Theme.muted
                    font.pixelSize: Theme.typeCaption
                    font.family: Theme.fontFamily
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
                    color: root.loadColor(card.frac)

                    Behavior on width {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }
                    Behavior on color {
                        CAnim {}
                    }
                }
            }

            // Stats share the row equally: values align in columns across cards.
            Row {
                width: parent.width
                spacing: Theme.spaceSm
                Repeater {
                    model: card.statItems
                    delegate: StatCell {
                        required property var modelData
                        width: (parent.width - parent.spacing * (card.statItems.length - 1)) / Math.max(1, card.statItems.length)
                        value: modelData.value
                        label: modelData.label
                    }
                }
            }
        }
    }

    // ---- header: identity + freshness ----
    RowLayout {
        width: parent.width
        spacing: Theme.spaceSm

        Label {
            Layout.fillWidth: true
            text: "System Resources"
            font.pixelSize: Theme.typeSubtitle
            font.family: Theme.fontFamily
            font.weight: Font.DemiBold
            color: Theme.fg
            elide: Text.ElideRight
        }
        Label {
            Layout.alignment: Qt.AlignVCenter
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

    // ---- CPU + RAM: two up when they fit, stacked otherwise ----
    Grid {
        visible: root.stats !== null
        width: parent.width
        columns: root.twoUp ? 2 : 1
        columnSpacing: Theme.spaceSm
        rowSpacing: Theme.spaceSm

        MetricCard {
            glyph: Icons.cpu
            label: (root.stats?.cpuLabel || "CPU").toUpperCase()
            primary: root.fmt(root.stats?.cpuLoad, 1)
            unit: "%"
            frac: root.cpuFrac
            width: root.twoUp ? (parent.width - parent.columnSpacing) / 2 : parent.width
            statItems: [
                {
                    label: "Clock",
                    value: root.fmt(root.stats?.clockGHz, 2, " GHz")
                },
                {
                    label: "Temp",
                    value: root.fmt(root.stats?.cpuTempC, 1, "°C")
                },
                {
                    label: "Threads",
                    value: root.stats?.threads ?? "N/A"
                }
            ]
        }

        MetricCard {
            glyph: Icons.ram
            label: "RAM"
            primary: root.fmt(root.stats?.ramUsage, 0)
            unit: "%"
            frac: root.ramFrac
            width: root.twoUp ? (parent.width - parent.columnSpacing) / 2 : parent.width
            statItems: [
                {
                    label: "Used",
                    value: root.fmt(root.stats?.ramUsedGB, 1, " GB")
                },
                {
                    label: "Free",
                    value: root.fmt(root.stats?.ramFreeGB, 1, " GB")
                },
                {
                    label: "Total",
                    value: root.fmt(root.stats?.ramTotalGB, 1, " GB")
                }
            ]
        }
    }

    // ---- GPUs: full width, one plate each ----
    Repeater {
        model: root.gpus
        delegate: MetricCard {
            required property var modelData
            readonly property real gpuFrac: (modelData.load ?? null) !== null ? Math.max(0, Math.min(1, modelData.load / 100)) : 0

            width: root.width
            glyph: Icons.gpu
            label: (modelData.label || "GPU").toUpperCase()
            primary: root.fmt(modelData.load, 1)
            unit: "%"
            frac: gpuFrac
            statItems: [
                {
                    label: "VRAM",
                    value: root.gpuMem(modelData.memoryUsedGB, modelData.memoryTotalGB)
                },
                {
                    label: "Temp",
                    value: root.fmt(modelData.tempC, 1, "°C")
                },
                {
                    label: "Driver",
                    value: modelData.driver || "N/A"
                }
            ]
        }
    }
}
