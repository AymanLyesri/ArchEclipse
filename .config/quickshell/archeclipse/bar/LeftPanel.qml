import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.widgets
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
    WlrLayershell.layer: WlrLayer.Top

    // Visibility: controlled by HotZone, keybind, or IPC
    // Don't declare local 'visible' property - it shadows WindowInterface.visible
    // The actual window visibility is controlled by the PanelWindow's visible property

    // Selected widget state
    property string selectedWidget: "UserProfile"

    // Register with Registry for IPC togglePanel
    Component.onCompleted: {
        Registry.register(`left-panel-${root.monitorName}`, root);
        // Start hidden
        visible = false;
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

        // Left sidebar with widget selectors
        Rectangle {
            id: sidebar
            width: 48
            height: parent.height
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
                        checkable: true
                        checked: root.selectedWidget === modelData.name
                        padding: 10
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

            // Placeholder components for each widget - use actual widget implementations
            Component {
                id: userProfileWidget
                UserProfileWidget {}
            }
            Component {
                id: booruViewerWidget
                BooruViewerWidget {}
            }
            Component {
                id: chatBotWidget
                ChatBotWidget {}
            }
            Component {
                id: customScriptsWidget
                CustomScriptsWidget {}
            }
            Component {
                id: donationsWidget
                DonationsWidget {}
            }
            Component {
                id: keyBindsWidget
                KeyBindsWidget {}
            }
            Component {
                id: mangaViewerWidget
                MangaViewerWidget {}
            }
            Component {
                id: settingsWidget
                SettingsWidget {}
            }
        }
    }

    // Escape key closes panel - handled by focus scope
    Item {
        id: keyHandler
        focus: true
        Keys.onEscapePressed: {
            if (root.visible) {
                root.visible = false;
                event.accepted = true;
            }
        }
    }
}