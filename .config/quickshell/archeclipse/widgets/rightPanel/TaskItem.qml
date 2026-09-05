import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.widgets.shared

// Script Timer Task Item component
Item {
    id: root
    property var task: {}
    signal deleteClicked(string id)
    signal editClicked(var task)
    signal toggleClicked(string id)

    property bool isHovered: false

    Rectangle {
        id: container
        anchors.fill: parent
        color: task.active ? Theme.moduleBg : Theme.bg
        radius: Theme.radius
        border.width: 1
        border.color: task.active ? Theme.border : Theme.fgDim
        clip: true

        Column {
            anchors.fill: parent
            spacing: 6
            anchors.margins: 12

            // Header
            Row {
                spacing: 8
                Column {
                    spacing: 2
                    Label {
                        id: nameLabel
                        text: task.name
                        font.pixelSize: Theme.fontSize + 2
                        font.bold: true
                        color: task.active ? Theme.fg : Theme.fgDim
                    }
                    Row {
                        spacing: 5
                        Label {
                            id: scheduleLabel
                            text: root.formatNextRun(task.nextRun)
                            font.pixelSize: Theme.fontSize - 1
                            color: Theme.fgDim
                        }
                        Label {
                            id: typeLabel
                            text: task.type ? "🔁" : "1️⃣"
                            font.pixelSize: Theme.fontSize - 1
                            color: Theme.fgDim
                        }
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

                    CheckBox {
                        id: activeCheck
                        checked: task.active
                        onToggled: root.toggleClicked(task.id)
                    }
                    AppButton {
                        icon: "✏"
                        idleBg: Theme.accentBg
                        idleFg: Theme.accent
                        outlined: true
                        outlineColor: Theme.accent
                        tooltipText: "Edit"
                        onClicked: root.editClicked(task)
                    }
                    AppButton {
                        icon: "✕"
                        idleBg: Theme.dangerBg
                        idleFg: Theme.danger
                        outlined: true
                        outlineColor: Theme.danger
                        tooltipText: "Delete"
                        onClicked: root.deleteClicked(task.id)
                    }
                }
            }

            // Command
            Label {
                text: task.command.length > 40 ? task.command.substring(0, 40) + "..." : task.command
                font.pixelSize: Theme.fontSize - 1
                color: Theme.fgDim
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.isHovered = true
            onExited: root.isHovered = false
        }
    }

    function formatNextRun(nextRun) {
        if (!nextRun) return "Not scheduled";
        const date = new Date(nextRun);
        const now = new Date();
        const isToday = date.toDateString() === now.toDateString();

        if (isToday) {
            return "Today, " + date.toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", hour12: false });
        }
        return date.toLocaleString("en-US", { hour: "2-digit", minute: "2-digit", hour12: false, month: "short", day: "numeric" });
    }
}