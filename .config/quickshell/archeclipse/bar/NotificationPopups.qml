import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
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
                property bool bodyExpanded: false

                width: 400
                height: contentCol.childrenRect.height + 20 + (buttonsRow.visible ? buttonsRow.height + 8 : 0)
                radius: Theme.radius
                color: critical ? Qt.rgba(0.66, 0.27, 0.27, 0.95) : Theme.moduleBg
                border.color: Qt.alpha(Theme.foreground, 0.1)
                border.width: 1

                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Column {
                    id: mainCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Row {
                        id: contentCol
                        width: parent.width
                        spacing: 10

                        // ---- app icon (file path → Image, else nerd glyph) ----
                        Item {
                            id: iconSlot
                            width: 28
                            height: 28
                            Image {
                                id: iconImg
                                visible: source.toString() !== ""
                                anchors.fill: parent
                                source: {
                                    const p = card.modelData;
                                    // AGS prefers appIcon file, else image file
                                    if (p.appIcon && p.appIcon.startsWith("/")) return p.appIcon;
                                    return "";
                                }
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: false
                            }
                            Text {
                                visible: !iconImg.visible
                                width: parent.width; height: parent.height
                                text: card.modelData.urgency === NotificationUrgency.Critical ? "\u{F0266}" : "\u{F059A}"
                                color: card.critical ? "white" : Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 22
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Column {
                            width: parent.width - 38
                            spacing: 3

                            // ---- top bar: title + time ----
                            RowLayout {
                                spacing: 6
                                width: parent.width
                                Text {
                                    text: card.modelData.summary || card.modelData.appName
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    color: card.critical ? "white" : Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                    font.pixelSize: Theme.fontSize
                                }
                                Text {
                                    readonly property double t: (card.modelData.notif && card.modelData.notif.time) || card.modelData.time || 0
                                    text: parent.t > 0
                                        ? new Date(parent.t * 1000).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", hour12: false })
                                        : ""
                                    color: card.critical ? Qt.alpha("white", 0.7) : Theme.fgDim
                                    font.pixelSize: Theme.fontSize - 2
                                    visible: text !== ""
                                }
                            }

                            // ---- body (expandable) ----
                            Text {
                                width: parent.width
                                visible: card.modelData.body !== ""
                                text: card.modelData.body
                                wrapMode: Text.WordWrap
                                maximumLineCount: card.bodyExpanded ? undefined : 4
                                elide: card.bodyExpanded ? Text.ElideNone : Text.ElideRight
                                color: card.critical ? Qt.alpha("white", 0.85) : Theme.foregroundSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                            }
                        }
                    }

                    // ---- action buttons (mirrors AGS getActions) ----
                    Row {
                        id: actionsRow
                        visible: (card.modelData.actions || []).length > 0
                        spacing: 4
                        Repeater {
                            model: card.modelData.actions || []
                            delegate: Button {
                                required property var modelData
                                text: modelData.text
                                height: 24
                                onClicked: Notifications.invokeAction(card.modelData.id, index)
                                background: Rectangle {
                                    color: Theme.moduleBg
                                    border.color: Theme.border
                                    radius: 4
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: Theme.fg
                                    font.pixelSize: Theme.fontSize - 2
                                }
                            }
                        }
                    }

                    // ---- popup control buttons: copy, expand, dismiss ----
                    Row {
                        id: buttonsRow
                        visible: card.isHovered
                        spacing: 4
                        Button {
                            text: "\u{f0c5}"
                            onClicked: {
                                const t = card.modelData.body || card.modelData.summary;
                                if (t) Quickshell.execDetached(["wl-copy", t]);
                            }
                            contentItem: Text { text: parent.text; color: Theme.fg; font.pixelSize: 11; anchors.centerIn: parent }
                            background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
                        }
                        Button {
                            text: card.bodyExpanded ? "\u{f07e}" : "\u{f07c}"
                            visible: (card.modelData.body || "").length > 60
                            onClicked: card.bodyExpanded = !card.bodyExpanded
                            contentItem: Text { text: parent.text; color: Theme.fg; font.pixelSize: 11; anchors.centerIn: parent }
                            background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
                        }
                        Button {
                            text: "\u{f00d}"
                            onClicked: Notifications.closePopup(card.modelData.id, true)
                            contentItem: Text { text: parent.text; color: Theme.fg; font.pixelSize: 11; anchors.centerIn: parent }
                            background: Rectangle { color: Theme.moduleBg; radius: 4; border.color: Theme.border }
                        }
                    }
                }

                property bool isHovered: false
                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: card.isHovered = true
                    onExited: card.isHovered = false
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton)
                            Notifications.closePopup(card.modelData.id, true);   // AGS right-click dismiss
                    }
                }
            }
        }
    }
}
