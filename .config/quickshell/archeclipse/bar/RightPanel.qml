import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.bar

// Port of widgets/rightPanel/RightPanel.tsx — data-driven side panel on the
// right edge. Shows ALL enabled widgets simultaneously (like AGS), with a
// toggle sidebar for selecting which widgets are visible. Anchored TOP | RIGHT | BOTTOM,
// exclusive when locked, hidden by default. Opened via HotZone dwell,
// SUPER+R keybind, or IPC togglePanel.
PanelWindow {
    id: root
    required property ShellScreen screen
    readonly property string monitorName: {
        const hmon = Hyprland.monitorFor(screen)
        return hmon ? hmon.name : screen.name
    }

    // Window geometry / layer
    anchors { right: true; top: true; bottom: true }
    implicitWidth: Settings.rightPanelWidth
    color: "transparent"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusiveZone: Settings.rightPanelLock ? width : -1
    WlrLayershell.layer: WlrLayer.Top

    // Register with Registry for IPC togglePanel
    Component.onCompleted: {
        Registry.register(`right-panel-${root.monitorName}`, root)
        visible = false
    }
    Component.onDestruction: {
        Registry.unregister(`right-panel-${root.monitorName}`)
    }

    // Idle hide timer (when not locked)
    Timer {
        id: hideTimer
        interval: 300
        onTriggered: {
            if (!Settings.rightPanelLock) root.visible = false
        }
    }

    // Hover handling — keep open while mouse is over panel
    HoverHandler {
        id: panelHover
        enabled: true
        onHoveredChanged: {
            if (hovered) hideTimer.stop()
            else if (!Settings.rightPanelLock) hideTimer.restart()
        }
    }

    // Main panel content
    Rectangle {
        anchors.fill: parent
        color: Theme.moduleBg
        radius: Theme.radius
        border.width: 1
        border.color: Theme.border

        Row {
            anchors.fill: parent
            spacing: 0

            // ----- Sidebar with widget toggles (drag-reorderable) -----
            Rectangle {
                id: sidebar
                width: 56
                color: Theme.bg
                radius: Theme.radius
                border.width: 1
                border.color: Theme.border
                clip: true
                visible: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Repeater {
                        id: widgetSelectorRepeater
                        model: Settings.rightPanelWidgets
                        delegate: Item {
                            id: selectorItem
                            required property var modelData
                            required property int index
                            width: parent.width
                            height: 40

                            Rectangle {
                                anchors.fill: parent
                                color: modelData.enabled ? Theme.accentBg : "transparent"
                                radius: 6
                                border.width: modelData.enabled ? 1 : 0
                                border.color: Theme.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    font.pixelSize: 20
                                    color: modelData.enabled ? Theme.accent : Theme.fg
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        // Toggle enabled state
                                        const widgets = Settings.rightPanelWidgets.slice()
                                        const w = widgets[index]
                                        const newWidgets = widgets.map(item =>
                                            item.name === w.name ? Object.assign({}, item, { enabled: !item.enabled }) : item
                                        )
                                        Settings.rightPanelWidgets = newWidgets
                                        Settings.updateSetting("rightPanel.widgets", newWidgets)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ----- Main content area — all enabled widgets -----
            ScrollView {
                id: contentScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AlwaysOn

                Column {
                    id: contentColumn
                    width: parent.width
                    spacing: 8
                    padding: 8

                    Repeater {
                        id: enabledWidgetRepeater
                        model: {
                            // Filter to only enabled widgets, preserving order
                            const widgets = Settings.rightPanelWidgets
                            const result = []
                            for (let i = 0; i < widgets.length; i++) {
                                if (widgets[i].enabled) {
                                    result.push(widgets[i])
                                }
                            }
                            return result
                        }

                        delegate: Item {
                            required property var modelData
                            width: parent.width
                            height: widgetLoader.implicitHeight

                            Loader {
                                id: widgetLoader
                                anchors.fill: parent
                                anchors.margins: 4
                                sourceComponent: {
                                    switch (modelData.name) {
                                    case "Waifu":                return waifuWidget
                                    case "Media":                return mediaWidget
                                    case "NotificationHistory":  return notificationHistoryWidget
                                    case "ScriptTimer":          return scriptTimerWidget
                                    case "Crypto":               return cryptoWidget
                                    case "Calendar":             return calendarWidget
                                    case "SystemResources":      return systemResourcesWidget
                                    default: return undefinedComponent
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Widget component definitions
        Component { id: undefinedComponent; Text { text: "Unknown widget" } }
        Component { id: calendarWidget;          CalendarWidget { Layout.fillWidth: true } }
        Component { id: cryptoWidget;            CryptoWidget { Layout.fillWidth: true } }
        Component { id: mediaWidget;             MediaWidget { Layout.fillWidth: true } }
        Component { id: notificationHistoryWidget; NotificationHistoryWidget { Layout.fillWidth: true } }
        Component { id: scriptTimerWidget;       ScriptTimerWidget { Layout.fillWidth: true } }
        Component { id: systemResourcesWidget;   SystemResourcesWidget { Layout.fillWidth: true } }
        Component { id: waifuWidget;              WaifuWidget { Layout.fillWidth: true } }
    }

    // Escape key closes panel
    Item {
        id: keyHandler
        focus: true
        Keys.onEscapePressed: {
            if (root.visible) {
                root.visible = false
                event.accepted = true
            }
        }
    }
}
