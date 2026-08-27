import QtQuick
import QtQuick.Controls
import qs.theme

// Calendar widget ported from widgets/rightPanel/components/Calendar.tsx
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    Rectangle {
        id: container
        anchors.fill: parent
        color: "transparent"

        Column {
            anchors.centerIn: parent
            spacing: 8

            // Simple calendar header
            Row {
                spacing: 4
                Repeater {
                    model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                    delegate: Label {
                        text: modelData
                        font.pixelSize: Theme.fontSize - 1
                        font.bold: true
                        color: Theme.fgDim
                        width: 40
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Simple calendar grid
            Grid {
                columns: 7
                spacing: 4
                Repeater {
                    model: 42  // 6 weeks * 7 days
                    delegate: Item {
                        width: 40
                        height: 40
                        property int day: index + 1
                        property bool isCurrentMonth: day >= 1 && day <= 31

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            radius: 4
                            border.width: 1
                            border.color: Theme.border
                        }

                        Text {
                            anchors.centerIn: parent
                            text: isCurrentMonth ? day : ""
                            color: Theme.fg
                            font.pixelSize: Theme.fontSize
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                // Could select date here
                            }
                        }
                    }
                }
            }
        }
    }
}