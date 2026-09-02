import Quickshell
import QtQuick
import qs.theme
import qs.bar
import Quickshell.Services.SystemTray
import Quickshell.Hyprland

// Utilities section: Battery, BrightnessWidget, Volume, SystemTray, ResourceMonitor,
// ControlPanelButton. Mirrors AGS widgets/bar/components/Utilities.tsx
Item {
    id: root

    property alias batteryPercent: battery.pct
    property alias volumePercent: volume.pct
    property alias brightnessPercent: brightness.pct

    Row {
        id: row
        anchors.fill: parent
        spacing: 5

        Battery { id: battery }
        Brightness { id: brightness }
        Volume { id: volume }

        // System tray (max 3 visible, overflow in popover)
        Item {
            id: trayContainer
            visible: Quickshell.Services.SystemTray.items.length > 0
            width: childrenRect.width
            height: 24
            Row {
                spacing: 2
                Repeater {
                    model: Quickshell.Services.SystemTray.items
                    delegate: Quickshell.Services.SystemTray.Item {
                        id: trayItem
                        iconName: model.iconName
                        tooltipText: model.tooltipText
                    }
                }
            }
        }

        // Resource monitor (click → workspace 5)
        MouseArea {
            id: resourceMonitorArea
            width: 60
            height: 24
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Hyprland.dispatch("workspace", "5")
        }

        ControlPanelButton {}
    }

    function measureWidth() {
        const [, natural] = row.measure(Qt.Horizontal, -1)
        return natural
    }
}
