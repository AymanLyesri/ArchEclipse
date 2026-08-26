import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.services
import QtQuick.Controls

// Port of widgets/leftPanel/LeftPanel.tsx — side panel on the left edge.
// Anchored TOP | LEFT | BOTTOM, exclusive when enabled, hidden by default.
// Opened via HotZone dwell, SUPER+L keybind, or IPC togglePanel.
PanelWindow {
    id: root

    required property ShellScreen screen
    readonly property string monitorName: {
        const hmon = Hyprland.monitorFor(screen);
        return hmon ? hmon.name : screen.name;
    }

    // Window geometry / layer
    anchors { left: true; top: true; bottom: true }
    implicitWidth: Settings.leftPanelWidth
    color: "transparent"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusiveZone: Settings.leftPanelLock ? width : -1
    WlrLayershell.layer: WlrLayershell.Layer.Top

    // Visibility: controlled by HotZone, keybind, or IPC
    property bool visible: false

    // Selected widget state
    property string selectedWidget: "UserProfile"

    // Register with Registry for IPC togglePanel
    Component.onCompleted: {
        Registry.register(`left-panel-${root.monitorName}`, root);
    }
    Component.onDestruction: {
        Registry.unregister(`left-panel-${root.monitorName}`);
    }

    // Idle hide timer (when not locked)
    Timer {
        id: hideTimer
        interval: 300
        onTriggered: {
            if (!Settings.leftPanelLock) root.visible = false;
        }
    }

    // Hover handling — keep open while mouse is over panel
    HoverHandler {
        id: panelHover
        enabled: true
        onHoveredChanged: {
            if (hovered) hideTimer.stop();
            else if (!Settings.leftPanelLock) hideTimer.restart();
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

        // Left sidebar with widget selectors
        Rectangle {
            id: sidebar
            width: 56
            height: parent.height
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: Theme.bg
            radius: Theme.radius
            clip: true
            border.width: 1
            border.color: Theme.border

            // Widget selector buttons
            Column {
                id: selectorColumn
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                spacing: 8

                Repeater {
                    model: [
                        { name: "UserProfile", icon: "\uf007" },
                        { name: "BooruViewer", icon: "\uf03e" },
                        { name: "ChatBot", icon: "\uf4b8" },
                        { name: "CustomScripts", icon: "\uf121" },
                        { name: "Donations", icon: "\u2665" },
                        { name: "KeyBinds", icon: "\uf11c" },
                        { name: "MangaViewer", icon: "\uf02d" },
                        { name: "SettingsWidget", icon: "\uf013" }
                    ]
                    delegate: Button {
                        id: selectorBtn
                        width: parent.width
                        height: 40
                        checkable: true
                        checked: root.selectedWidget === modelData.name
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
                            root.selectedWidget = modelData.name;
                        }
                    }
                }
            }
        }

        // Main content area (widget stack)
        Item {
            id: contentArea
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 8
            anchors.bottomMargin: 8

            // Widget stack - only one visible at a time
            Loader {
                id: widgetLoader
                anchors.fill: parent
                sourceComponent: {
                    switch (root.selectedWidget) {
                    case "UserProfile": return userProfileWidget;
                    case "BooruViewer": return booruViewerWidget;
                    case "ChatBot": return chatBotWidget;
                    case "CustomScripts": return customScriptsWidget;
                    case "Donations": return donationsWidget;
                    case "KeyBinds": return keyBindsWidget;
                    case "MangaViewer": return mangaViewerWidget;
                    case "SettingsWidget": return settingsWidget;
                    default: return defaultWidget;
                    }
                }
            }

            Component {
                id: defaultWidget
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    Text {
                        text: "Left Panel"
                        font.pixelSize: 24
                        color: Theme.fg
                    }
                    Text {
                        text: "Select a widget from the sidebar"
                        color: Theme.fgDim
                    }
                }
            }

            // Placeholder components for each widget
            Component {
                id: userProfileWidget
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    Text { text: "User Profile"; font.pixelSize: 24; color: Theme.fg }
                    Text { text: "User profile widget"; color: Theme.fgDim }
                }
            }
            Component {
                id: booruViewerWidget
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    Text { text: "Booru Viewer"; font.pixelSize: 24; color: Theme.fg }
                    Text { text: "Booru viewer widget"; color: Theme.fgDim }
                }
            }
            Component {
                id: chatBotWidget
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    Text { text: "Chat Bot"; font.pixelSize: 24; color: Theme.fg }
                    Text { text: "Chat bot widget"; color: Theme.fgDim }
                }
            }
            Component {
                id: customScriptsWidget
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    Text { text: "Custom Scripts"; font.pixelSize: 24; color: Theme.fg }
                    Text { text: "Custom scripts widget"; color: Theme.fgDim }
                }
            }
            Component {
                id: donationsWidget
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    Text { text: "Donations"; font.pixelSize: 24; color: Theme.fg }
                    Text { text: "Donations widget"; color: Theme.fgDim }
                }
            }
            Component {
                id: keyBindsWidget
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    Text { text: "Key Binds"; font.pixelSize: 24; color: Theme.fg }
                    Text { text: "Key binds widget"; color: Theme.fgDim }
                }
            }
            Component {
                id: mangaViewerWidget
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    Text { text: "Manga Viewer"; font.pixelSize: 24; color: Theme.fg }
                    Text { text: "Manga viewer widget"; color: Theme.fgDim }
                }
            }
            Component {
                id: settingsWidget
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    Text { text: "Settings"; font.pixelSize: 24; color: Theme.fg }
                    Text { text: "Settings widget"; color: Theme.fgDim }
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
}