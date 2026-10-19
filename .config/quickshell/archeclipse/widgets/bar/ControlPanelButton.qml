import QtQuick
import Quickshell
import qs.services
import qs.theme

// Port of Utilities.tsx ControlPanelButton — toggles the control island
// (quick settings) in the bar pill.
Rectangle {
    id: root

    property string monitorName: ""

    width: 32
    height: Theme.barContentHeight
    radius: Theme.radius
    color: mouse.containsMouse ? Theme.surfaceHover : "transparent"

    Text {
        anchors.centerIn: parent
        text: "\uf303"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 1
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // Toggle the control island in the bar pill. Wallpaper sits
            // above control (priority), so yield it first — otherwise
            // opening control while the wallpaper island is up looks dead.
            if (BarState.stateFor(root.monitorName) === "control")
                BarState.deactivate("control", root.monitorName);
            else {
                BarState.deactivate("wallpaper", root.monitorName);
                BarState.activate("control", 0, root.monitorName);
            }
        }
    }
}
