import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.bar
import qs.services
import qs.theme

// Port of AlwaysOnWidget.tsx — the full <Weather /> widget in a BOTTOM
// layer panel, hidden while a client is fullscreen or setting disabled.
PanelWindow {
id: root

required property ShellScreen screen
anchors { left: true; bottom: true }
exclusiveZone: -1
WlrLayershell.layer: WlrLayer.Overlay
color: "transparent"
margins { left: 10; bottom: 10 }
implicitWidth: 330
implicitHeight: weatherBody.implicitHeight + 24
visible: !fullscreenActive

readonly property bool fullscreenActive: {
    BarState.hyprlandTick;
    const mon = Hyprland.monitorFor(screen);
    const ws = mon?.activeWorkspace;
    if (!ws) return false;
    return Hyprland.toplevels.values.some(t => t.workspace === ws && t.lastIpcObject?.fullscreen);
}

Rectangle {
    id: weatherBody
    width: weatherContentView.implicitWidth + 28
    height: weatherContentView.implicitHeight + 28
    anchors.centerIn: parent
    radius: Theme.radius
    color: Theme.moduleBg
    border.color: Theme.border
    border.width: 1

    WeatherWidget {
        id: weatherContentView
        anchors.centerIn: parent
        width: 300
        moreDetails: false
    }
}
}
