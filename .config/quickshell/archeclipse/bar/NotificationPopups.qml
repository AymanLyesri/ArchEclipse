import QtQuick
import Quickshell
import qs.theme
import qs.services

// Port of NotificationPopups.tsx window — top-right stack of popup cards,
// overlay layer, hidden when empty. One per monitor like AGS.
PanelWindow {
    id: root

    required property ShellScreen screen
    anchors { top: true; right: true }
    exclusiveZone: -1
    color: "transparent"
    aboveWindows: true
    margins { top: 10; right: 10 }
    implicitWidth: 400
    implicitHeight: popColumn.childrenRect.height + 4
    visible: Notifications.popups.length > 0

    Column {
        id: popColumn
        anchors.top: parent.top
        anchors.right: parent.right
        width: parent.width
        spacing: Theme.spacing

        Repeater {
            model: Notifications.popups

            Rectangle {
                id: card
                required property var modelData
                readonly property bool critical:
                    modelData.urgency === NotificationUrgency.Critical

                width: 400
                height: contentCol.childrenRect.height + 20
                radius: Theme.radius
                color: critical ? Qt.rgba(0.66, 0.27, 0.27, 0.95) : Theme.moduleBg
                border.color: Qt.alpha(Theme.foreground, 0.1)
                border.width: 1

                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Row {
                    id: contentCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    // icon
                    Text {
                        width: 28
                        text: {
                            const p = card.modelData;
                            if (p.image && !p.image.startsWith("/")) return "";
                            return p.urgency === NotificationUrgency.Critical ? "\u{F0266}" : "\u{F059A}";
                        }
                        visible: text !== ""
                        color: card.critical ? "white" : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - (iconText.visible ? 38 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Row {
                            spacing: 8
                            width: parent.width
                            Text {
                                text: card.modelData.summary || card.modelData.appName
                                elide: Text.ElideRight
                                width: parent.width - actionsRow.width - 20
                                color: card.critical ? "white" : Theme.foreground
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fontSize
                            }
                            Row {
                                id: actionsRow
                                spacing: 4
                                Repeater {
                                    model: card.modelData.actions.length > 2 ? 0 : card.modelData.actions.length
                                    Text {
                                        required property int index
                                        text: card.modelData.actions[index]?.text ?? ""
                                        color: Theme.secondary
                                        font.underline: true
                                        font.pixelSize: Theme.fontSize - 2
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: Notifications.invokeAction(card.modelData.id, parent.index)
                                        }
                                    }
                                }
                            }
                        }
                        Text {
                            width: parent.width
                            visible: card.modelData.body !== ""
                            text: card.modelData.body
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            color: card.critical ? Qt.alpha("white", 0.85) : Theme.foregroundSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: Notifications.closePopup(card.modelData.id, true)   // right-click dismiss (AGS behavior)
                }
            }
        }
    }
}
