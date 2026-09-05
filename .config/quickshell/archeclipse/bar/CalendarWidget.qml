import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

// CalendarWidget — port of AGS rightPanel/components/Calendar.tsx.
// AGS mounts a Gtk.Calendar (navigable month view, "today" emphasis).
// This is a ground-up QML month grid: month navigation, weekday header,
// today highlight, and current-month day fills.
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    readonly property var now: new Date()
    property var viewDate: new Date(now.getFullYear(), now.getMonth(), 1)

    // weekday header labels (localized short names)
    readonly property var weekdayNames: (function() {
        // Use a fixed Monday-first week to match typical GTK calendar layouts;
        // derive from a known-simple date to get localized prefixes.
        // Fall back to S M T W T F S if locale names are empty.
        const d = new Date(2021, 0, 4) // a Monday
        const names = []
        for (let i = 0; i < 7; i++) {
            const s = Qt.locale().dayName((d.getDay() + i) % 7 === 0 ? 7 : (d.getDay() + i) % 7)
                .slice(0, 2)
            names.push(s || "")
        }
        return names
    })()

    function moveMonth(delta) {
        root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() + delta, 1)
    }

    function isToday(y, m, d) {
        return y === now.getFullYear() && m === now.getMonth() && d === now.getDate()
    }

    // Build the 6x7 grid; leading cells from prev month, trailing from next.
    readonly property var cells: (function() {
        const y = root.viewDate.getFullYear()
        const m = root.viewDate.getMonth()
        const firstDay = new Date(y, m, 1).getDay()      // 0=Sun
        // Monday-first offset
        const lead = (firstDay + 6) % 7
        const daysInMonth = new Date(y, m + 1, 0).getDate()
        const prevDays = new Date(y, m, 0).getDate()

        const out = []
        // leading cells (prev month)
        for (let i = lead - 1; i >= 0; i--) {
            const pm = m === 0 ? 11 : m - 1
            const py = m === 0 ? y - 1 : y
            out.push({ day: prevDays - i, d: prevDays - i, m: pm, y: py, inMonth: false })
        }
        // current month
        for (let d = 1; d <= daysInMonth; d++) {
            out.push({ day: d, d, m, y, inMonth: true })
        }
        // trailing cells (next month) to fill 6 rows
        let rem = 42 - out.length
        const nm = m === 11 ? 0 : m + 1
        const ny = m === 11 ? y + 1 : y
        for (let d = 1; d <= rem; d++) {
            out.push({ day: d, d, m: nm, y: ny, inMonth: false })
        }
        return out
    })()

    Column {
        anchors.fill: parent
        spacing: 6

        // Header: month nav + title
        Row {
            width: parent.width
            spacing: 8

            Rectangle {
                width: 26; height: 26; radius: 6
                color: prevMa.containsMouse ? Theme.accentBg : Theme.moduleBg
                Text {
                    anchors.centerIn: parent
                    text: "\u{F053}" // chevron-left
                    color: prevMa.containsMouse ? Theme.accent : Theme.fg
                    font.pixelSize: Theme.fontSize
                }
                MouseArea {
                    id: prevMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.moveMonth(-1)
                }
            }

            Text {
                Layout.fillWidth: true
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                text: Qt.locale().monthName(root.viewDate.getMonth(), Locale.LongFormat)
                      + " " + root.viewDate.getFullYear()
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
            }

            Rectangle {
                width: 26; height: 26; radius: 6
                color: nextMa.containsMouse ? Theme.accentBg : Theme.moduleBg
                Text {
                    anchors.centerIn: parent
                    text: "\u{F054}" // chevron-right
                    color: nextMa.containsMouse ? Theme.accent : Theme.fg
                    font.pixelSize: Theme.fontSize
                }
                MouseArea {
                    id: nextMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.moveMonth(1)
                }
            }
        }

        // Weekday header
        Row {
            width: parent.width
            Repeater {
                model: root.weekdayNames
                delegate: Text {
                    width: parent.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
            }
        }

        // Day grid (6 rows x 7)
        Grid {
            columns: 7
            width: parent.width
            columnSpacing: 1
            rowSpacing: 1
            Repeater {
                model: root.cells
                delegate: Rectangle {
                    // Guarded: item is 0-wide before the Loader stretches it;
                    // a negative width wedges the scene in a silent polish loop
                    width: Math.max(0, root.width / 7 - 1)
                    height: 26
                    radius: 4
                    color: modelData.inMonth
                        ? (cellMa.containsMouse ? Theme.accentBg : Theme.moduleBg)
                        : "transparent"
                    border.width: modelData.inMonth && cellMa.containsMouse ? 1 : 0
                    border.color: Theme.accent

                    Rectangle {
                        visible: modelData.inMonth && root.isToday(modelData.y, modelData.m, modelData.d)
                        anchors.fill: parent
                        radius: 4
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.accent
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.d
                        color: !modelData.inMonth
                            ? Theme.fgDim
                            : (root.isToday(modelData.y, modelData.m, modelData.d) ? Theme.accent : Theme.foreground)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: root.isToday(modelData.y, modelData.m, modelData.d)
                    }

                    MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }
    }
}
