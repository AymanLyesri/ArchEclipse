import QtQuick
import QtQuick.Controls
import qs.theme

// Calendar widget — month view with day-of-week header and date grid.
// Mirrors AGS Calendar.tsx which used Gtk.Calendar, but rendered natively.
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    readonly property date today: new Date()
    readonly property var monthNames: ["January", "February", "March", "April",
        "May", "June", "July", "August", "September", "October", "November", "December"]

    // First day of current month at 00:00
    readonly property date monthStart: new Date(today.getFullYear(), today.getMonth(), 1)
    readonly property int firstDayOfWeek: (monthStart.getDay() + 6) % 7  // 0=Mon
    readonly property int daysInMonth: new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate()

    // Total cells: 4 weeks min → 28 + offset + days, round up to full weeks
    readonly property int totalCells: Math.ceil((firstDayOfWeek + daysInMonth) / 7) * 7

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Column {
            anchors.centerIn: parent
            spacing: 8

            // Month header
            Text {
                text: monthNames[root.today.getMonth()] + " " + root.today.getFullYear()
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
                color: Theme.fg
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Day-of-week headers
            Grid {
                columns: 7
                spacing: 4
                Repeater {
                    model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                    delegate: Text {
                        text: modelData
                        width: 34
                        height: 22
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fgDim
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Date grid
            Grid {
                columns: 7
                spacing: 4
                Repeater {
                    model: root.totalCells
                    delegate: Item {
                        width: 34; height: 24
                        property int day: index - root.firstDayOfWeek + 1
                        property bool isCurrentMonth: day >= 1 && day <= root.daysInMonth
                        property bool isToday: isCurrentMonth && day === root.today.getDate()

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: parent.isToday ? 4 : 0
                            color: "transparent"
                            border.color: parent.isToday ? Theme.accent : "transparent"
                            border.width: parent.isToday ? 1 : 0
                        }

                        Text {
                            anchors.centerIn: parent
                            text: parent.isCurrentMonth ? parent.day : ""
                            color: parent.isCurrentMonth ? (parent.isToday ? Theme.accent : Theme.fg) : Theme.fgDim
                            font.pixelSize: Theme.fontSize
                            font.bold: parent.isToday
                        }
                    }
                }
            }
        }
    }
}
