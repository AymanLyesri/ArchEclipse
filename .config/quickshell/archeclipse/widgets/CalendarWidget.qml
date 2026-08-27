import Quickshell
import QtQuick
import qs.theme

Item {
    id: root

    property string className: ""

    // Calendar using QtQuick Calendar
    import QtQuick.Controls 2.15

    Calendar {
        id: calendar
        anchors.fill: parent
        locale: Qt.locale("en_US")
        weekNumbersVisible: false

        // Style
        background: Rectangle {
            color: qs.theme.Theme.background
        }

        delegate: Text {
            width: 40
            height: 40
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: "JetBrainsMono NFP"
            font.pixelSize: 12
            color: {
                if (styleData.selected) return qs.theme.Theme.background
                else if (styleData.currentMonth) return qs.theme.Theme.foreground
                else return qs.theme.Theme.color8
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 4
                visible: styleData.selected
                color: qs.theme.Theme.accent
                z: -1
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 4
                visible: styleData.today && !styleData.selected
                border.color: qs.theme.Theme.accent
                border.width: 2
                z: -1
            }
        }

        // Navigation bar
        navigationBar: ToolBar {
            height: 40
            background: Rectangle { color: qs.theme.Theme.color0 }

            Row {
                anchors.fill: parent
                spacing: 10
                anchors.margins: 10

                ToolButton {
                    text: "◀"
                    font.family: "JetBrainsMono NFP"
                    onClicked: calendar.month -= 1
                    background: Rectangle { color: "transparent" }
                }

                ToolButton {
                    text: calendar.month + " " + calendar.year
                    font.family: "JetBrainsMono NFP"
                    font.bold: true
                    enabled: false
                    background: Rectangle { color: "transparent" }
                }

                ToolButton {
                    text: "▶"
                    font.family: "JetBrainsMono NFP"
                    onClicked: calendar.month += 1
                    background: Rectangle { color: "transparent" }
                }
            }
        }
    }
}