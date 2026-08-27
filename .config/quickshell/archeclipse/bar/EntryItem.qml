import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

// Crypto Entry Item component
Item {
    id: root
    property var entry: {}
    signal deleteClicked(string id)
    signal editClicked(var entry)

    property bool isHovered: false

    Rectangle {
        id: container
        anchors.fill: parent
        color: Theme.moduleBg
        radius: Theme.radius
        border.width: 1
        border.color: Theme.border
        clip: true

        Column {
            anchors.fill: parent
            spacing: 8
            anchors.margins: 12

            // Header
            Row {
                spacing: 8
                Column {
                    spacing: 2
                    Label {
                        id: symbolLabel
                        text: entry.symbol.toUpperCase()
                        font.pixelSize: Theme.fontSize + 4
                        font.bold: true
                        color: Theme.fg
                    }
                    Label {
                        id: timeframeLabel
                        text: entry.timeframe + " timeframe"
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fgDim
                    }
                }

                Item { Layout.fillWidth: true }

                // Hover actions
                Row {
                    id: actionButtons
                    spacing: 4
                    visible: isHovered
                    opacity: isHovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Button {
                        text: "📌"
                        ToolTip.visible: hovered
                        ToolTip.delay: 500
                        ToolTip.text: "Pin to bar"
                        onClicked: {
                            // TODO: Implement pin to bar
                        }
                        background: Rectangle {
                            color: Theme.accentBg
                            radius: 4
                            border.width: 1
                            border.color: Theme.accent
                        }
                        contentItem: Text {
                            anchors.centerIn: parent
                            color: Theme.accent
                            font.pixelSize: Theme.fontSize
                        }
                    }
                    Button {
                        text: "✏"
                        ToolTip.visible: hovered
                        ToolTip.delay: 500
                        ToolTip.text: "Edit"
                        onClicked: root.editClicked(entry)
                        background: Rectangle {
                            color: Theme.accentBg
                            radius: 4
                            border.width: 1
                            border.color: Theme.accent
                        }
                        contentItem: Text {
                            anchors.centerIn: parent
                            color: Theme.accent
                            font.pixelSize: Theme.fontSize
                        }
                    }
                    Button {
                        text: "✕"
                        ToolTip.visible: hovered
                        ToolTip.delay: 500
                        ToolTip.text: "Delete"
                        onClicked: root.deleteClicked(entry.id)
                        background: Rectangle {
                            color: Theme.dangerBg
                            radius: 4
                            border.width: 1
                            border.color: Theme.danger
                        }
                        contentItem: Text {
                            anchors.centerIn: parent
                            color: Theme.danger
                            font.pixelSize: Theme.fontSize
                        }
                    }
                }
            }

            // Placeholder for crypto chart/data
            Rectangle {
                height: 100
                width: parent.width
                color: Theme.bg
                radius: 4
                border.width: 1
                border.color: Theme.border

                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    Label {
                        text: entry.symbol.toUpperCase() + " (" + entry.timeframe + ")"
                        color: Theme.fg
                        font.pixelSize: Theme.fontSize
                    }
                    Label {
                        text: entry.showPrice ? "Price: $--,---" : ""
                        color: Theme.fgDim
                        font.pixelSize: Theme.fontSize - 1
                    }
                    Label {
                        text: entry.showGraph ? "[Chart would appear here]" : ""
                        color: Theme.fgDim
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.isHovered = true
            onExited: root.isHovered = false
        }
    }
}