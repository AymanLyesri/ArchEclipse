import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

// Single Notification Item component
Item {
    id: root
    property var notification: {}
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
            spacing: 4
            anchors.margins: 12

            Row {
                spacing: 8
                Label {
                    id: appNameLabel
                    text: notification.app_name || "Unknown"
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    color: Theme.accent
                }
                Label {
                    id: timeLabel
                    text: new Date(notification.time * 1000).toLocaleTimeString()
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fgDim
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: "✕"
                    onClicked: notification.dismiss()
                    background: Rectangle {
                        color: Theme.dangerBg
                        radius: 4
                        border.width: 1
                        border.color: Theme.danger
                    }
                    contentItem: Text {
                        anchors.centerIn: parent
                        color: Theme.danger
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }

            Label {
                id: summaryLabel
                text: notification.summary || ""
                font.pixelSize: Theme.fontSize
                color: Theme.fg
                wrapMode: Text.WordWrap
            }

            Label {
                id: bodyLabel
                text: notification.body || ""
                font.pixelSize: Theme.fontSize - 1
                color: Theme.fgDim
                wrapMode: Text.WordWrap
                visible: notification.body && notification.body.length > 0
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }
    }
}