import QtQuick
import Quickshell
import qs.theme

// Port of Utilities.tsx ControlPanelButton — placeholder until the
// ControlPanel widget is migrated (Phase: panels). Kept as the anchor button
// so the utilities row keeps its slot and spacing identical to AGS.
Rectangle {
    width: 24; height: 20
    radius: Theme.radius
    color: mouse.containsMouse ? Theme.buttonHoverBg : "transparent"

    Text {
        anchors.centerIn: parent
        text: "\u{F15FC}"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 1
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: console.warn("[ControlPanel] panel not yet migrated")
    }
}
