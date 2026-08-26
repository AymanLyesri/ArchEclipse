import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.bar
import qs.services
import qs.theme

// Port of AlwaysOnWidget.tsx — bottom-left weather card, BOTTOM layer,
// hidden while a client is fullscreen or setting disabled.
PanelWindow {
    id: root

    required property ShellScreen screen
    anchors { left: true; bottom: true }
    exclusiveZone: -1
    color: "transparent"
    margins { left: 10; bottom: 10 }
    implicitWidth: weatherCard.implicitWidth + 24
    implicitHeight: weatherCard.implicitHeight + 20
    visible: !fullscreenActive

    readonly property bool fullscreenActive: {
        BarState.hyprlandTick;
        const mon = Hyprland.monitorFor(screen);
        const ws = mon?.activeWorkspace;
        if (!ws) return false;
        return Hyprland.toplevels.values.some(t => t.workspace === ws && t.lastIpcObject?.fullscreen);
    }

    Rectangle {
        id: weatherCard
        anchors.centerIn: parent
        radius: Theme.radius
        color: Theme.moduleBg

        Column {
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Weather.data ? Weather.icon(Weather.data.current.weather_code) : "\u{F0599}"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 14
                color: Theme.foreground
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Weather.data ? `${Math.round(Weather.data.current.temperature_2m)}${Weather.data.current_units?.temperature_2m ?? "°"}` : "…"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                color: Theme.foreground
            }
            Text {
                visible: Weather.data !== null
                anchors.horizontalCenter: parent.horizontalCenter
                text: Weather.data?.city ?? ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
                color: Theme.foregroundSecondary
            }
        }
    }
}
