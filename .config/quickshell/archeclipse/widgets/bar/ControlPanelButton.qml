import QtQuick
import Quickshell
import qs.services
import qs.theme

// Port of Utilities.tsx ControlPanelButton — toggles the ControlPanel
// quick-settings sidebar for the (focused) monitor's bar.
Rectangle {
    id: root

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
        onClicked: {
            // Toggle the ControlPanel window on the focused monitor.
            const name = `control-panel-${Registry.monitorName}`;
            const win = Registry.get(name);
            if (win) win.visible = !win.visible;
        }
    }
}