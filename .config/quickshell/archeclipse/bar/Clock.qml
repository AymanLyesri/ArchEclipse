import QtQuick
import Quickshell
import qs.theme
import qs.services

// Port of Information.tsx (clock part) — click cycles dateFormats.
// Hovering reveals the long date, mirroring the CustomRevealer.
Rectangle {
    id: root

    readonly property string longFormat: " dddd · d MMM yyyy "

    width: clockLabel.width + 10
    height: 22
    radius: Theme.radius
    color: hover.hovered ? Theme.buttonHoverBg : "transparent"

    property string timeText: Settings.fmt(new Date(), Settings.dateFormat)
    SystemClock { precision: SystemClock.Minutes; onDateChanged: root.timeText = Settings.fmt(new Date(), Settings.dateFormat) }

    Behavior on color { ColorAnimation { duration: 200 } }

    Text {
        id: clockLabel
        anchors.centerIn: parent
        text: hover.hovered ? Qt.formatDate(new Date(), root.longFormat) : root.timeText
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const idx = Settings.dateFormats.indexOf(Settings.dateFormat);
            const next = Settings.dateFormats[(idx + 1) % Settings.dateFormats.length];
            Settings.dateFormat = next;
            root.timeText = Settings.fmt(new Date(), next);
        }
    }

    HoverHandler { id: hover }
}
