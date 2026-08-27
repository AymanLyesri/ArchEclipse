import Quickshell
import QtQuick
import qs.theme
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

Item {
    id: root

    // System tray
    property var trayBox: Item {
        id: tray
        visible: Quickshell.Services.SystemTray.items.length > 0

        qs.widgets.SystemTray {
            id: systemTray
            maxItems: 3
            icons: Quickshell.Services.SystemTray.items
        }
    }

    // Power profiles (placeholder)
    property var powerBox: Item {
        id: power
        visible: false
        // Power profiles popover would go here
    }

    // Focused client title (optional)
    property var clientBox: Item {
        id: client
        visible: false
        // Focused window title
    }

    Row {
        id: row
        anchors.fill: parent
        spacing: 5

        Loader { sourceComponent: trayBox }
        Loader { sourceComponent: powerBox }
        Loader { sourceComponent: clientBox }
    }

    function measureWidth() {
        const [, natural] = row.measure(Qt.Horizontal, -1)
        return natural
    }
}