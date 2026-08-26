import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.services
import QtQuick.Controls

// Port of widgets/rightPanel/RightPanel.tsx — side panel on the right edge.
// Anchored TOP | RIGHT | BOTTOM, exclusive when enabled, hidden by default.
// Opened via HotZone dwell, SUPER+R keybind, or IPC togglePanel.
PanelWindow {
    id: root

    required property ShellScreen screen
    readonly property string monitorName: {
        const hmon = Hyprland.monitorFor(screen);
        return hmon ? hmon.name : screen.name;
    }

    // Window geometry / layer
    anchors { right: true; top: true; bottom: true }
    implicitWidth: Settings.rightPanelWidth
    color: "transparent"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusiveZone: Settings.rightPanelLock ? width : -1
    WlrLayershell.layer: WlrLayershell.Layer.Top

    // Visibility: controlled by HotZone, keybind, or IPC
    property bool visible: false

    // Selected widget state - track which widgets are enabled and their order
    property var enabledWidgets: [
        { name: "Calendar", icon: "\uf073", enabled: true },
        { name: "CryptoViewer", icon: "\uf15a", enabled: true },
        { name: "NotificationHistory", icon: "\uf0f3", enabled: true },
        { name: "ScriptTimer", icon: "\uf017", enabled: false },
        { name: "SystemResources", icon: "\uf080", enabled: true },
        { name: "Waifu", icon: "\uf0ac", enabled: false }
    ]

    // Register with Registry for IPC togglePanel
    Component.onCompleted: {
        Registry.register(`right-panel-${root.monitorName}`, root);
    }
    Component.onDestruction: {
        Registry.unregister(`right-panel-${root.monitorName}`);
    }

    // Idle hide timer (when not locked)
    Timer {
        id: hideTimer
        interval: 300
        onTriggered: {
            if (!Settings.rightPanelLock) root.visible = false;
        }
    }

    // Hover handling — keep open while mouse is over panel
    HoverHandler {
        id: panelHover
        enabled: true
        onHoveredChanged: {
            if (hovered) hideTimer.stop();
            else if (!Settings.rightPanelLock) hideTimer.restart();
        }
    }

    // Main panel content
    Rectangle {
        id: panelBg
        anchors.fill: parent
        color: Theme.moduleBg
        radius: Theme.radius
        border.width: 1
        border.color: Theme.border

        // Right sidebar with widget selectors (draggable in AGS)
        Rectangle {
            id: sidebar
            width: 56
            height: parent.height
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: Theme.bg
            radius: Theme.radius
            clip: true
            border.width: 1
            border.color: Theme.border

            // Widget selector buttons with drag handles
            Column {
                id: selectorColumn
                anchors { right: parent.right; left: parent.left; top: parent.top; margins: 8 }
                spacing: 8

                Repeater {
                    model: root.enabledWidgets
                    delegate: Button {
                        id: selectorBtn
                        width: parent.width
                        height: 40
                        checkable: true
                        checked: modelData.enabled
                        contentItem: Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.pixelSize: 20
                            font.family: "Font Awesome 6 Free"
                            color: selectorBtn.checked ? Theme.accent : Theme.fg
                        }
                        background: Rectangle {
                            anchors.fill: parent
                            color: selectorBtn.checked ? Theme.accentBg : "transparent"
                            radius: 8
                            border.width: selectorBtn.checked ? 1 : 0
                            border.color: Theme.accent
                        }
                        onClicked: {
                            // Toggle widget enabled state
                            const idx = root.enabledWidgets.indexOf(modelData);
                            if (idx >= 0) {
                                const updated = root.enabledWidgets.slice();
                                updated[idx] = Object.assign({}, updated[idx], { enabled: !updated[idx].enabled });
                                root.enabledWidgets = updated;
                            }
                        }
                    }
                }
            }
        }

        // Main content area - display enabled widgets in order
        Item {
            id: contentArea
            anchors.left: parent.left
            anchors.right: sidebar.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 8
            anchors.bottomMargin: 8

            // Stack of enabled widgets in order
            Column {
                anchors.fill: parent
                spacing: 16

                Repeater {
                    model: root.enabledWidgets.filter(w => w.enabled)
                    delegate: Loader {
                        width: parent.width
                        sourceComponent: {
                            switch (modelData.name) {
                            case "Calendar": return calendarWidget;
                            case "CryptoViewer": return cryptoWidget;
                            case "NotificationHistory": return notificationHistoryWidget;
                            case "ScriptTimer": return scriptTimerWidget;
                            case "SystemResources": return systemResourcesWidget;
                            case "Waifu": return waifuWidget;
                            default: return defaultWidget;
                            }
                        }
                    }
                }
            }
        }
    }

    // Escape key closes panel
    Keys.onEscapePressed: {
        if (visible) {
            visible = false;
            event.accepted = true;
        }
    }

    // Placeholder components for each widget
    Component {
        id: defaultWidget
        Column {
            anchors.centerIn: parent
            spacing: 16
            Text { text: "Right Panel"; font.pixelSize: 24; color: Theme.fg }
            Text { text: "Select widgets from the sidebar"; color: Theme.fgDim }
        }
    }
    Component {
        id: calendarWidget
        Column {
            anchors.centerIn: parent
            spacing: 16
            Text { text: "Calendar"; font.pixelSize: 24; color: Theme.fg }
            Text { text: "Calendar widget"; color: Theme.fgDim }
        }
    }
    Component {
        id: cryptoWidget
        Column {
            anchors.centerIn: parent
            spacing: 16
            Text { text: "Crypto Viewer"; font.pixelSize: 24; color: Theme.fg }
            Text { text: "Crypto widget"; color: Theme.fgDim }
        }
    }
    Component {
        id: notificationHistoryWidget
        Column {
            anchors.centerIn: parent
            spacing: 16
            Text { text: "Notification History"; font.pixelSize: 24; color: Theme.fg }
            Text { text: "Notification history widget"; color: Theme.fgDim }
        }
    }
    Component {
        id: scriptTimerWidget
        Column {
            anchors.centerIn: parent
            spacing: 16
            Text { text: "Script Timer"; font.pixelSize: 24; color: Theme.fg }
            Text { text: "Script timer widget"; color: Theme.fgDim }
        }
    }
    Component {
        id: systemResourcesWidget
        Column {
            anchors.centerIn: parent
            spacing: 16
            Text { text: "System Resources"; font.pixelSize: 24; color: Theme.fg }
            Text { text: "System resources widget"; color: Theme.fgDim }
        }
    }
    Component {
        id: waifuWidget
        Column {
            anchors.centerIn: parent
            spacing: 16
            Text { text: "Waifu"; font.pixelSize: 24; color: Theme.fg }
            Text { text: "Waifu widget"; color: Theme.fgDim }
        }
    }
}