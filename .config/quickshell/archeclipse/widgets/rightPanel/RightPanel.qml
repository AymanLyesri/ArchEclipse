import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.widgets.bar
import qs.widgets.media

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

    // Idle hide timer (when not locked) - AGS uses 0ms delay
    Timer {
        id: hideTimer
        interval: 0
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
            // AGS RightPanel puts <main-content/> first and <Actions/> last:
            // the sidebar displays on the RIGHT (mirrors LeftPanel's left rail).
            layoutDirection: Qt.RightToLeft

            // ----- Sidebar with widget toggles (drag-reorderable) -----
            Rectangle {
                id: sidebar
                width: 48
                height: parent.height
                color: Theme.bg
                radius: Theme.radius
                border.width: 1
                border.color: Theme.border
                clip: true
                visible: true

                Column {
                    id: selectorColumn
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
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

                            // --- Drag to reorder (AGS WidgetActions drag) ---
                            property bool dragging: false
                            Drag.active: dragArea.drag.active
                            Drag.hotSpot: Qt.point(width / 2, height / 2)
                            Drag.source: selectorItem
                            Drag.mimeData: { "text/plain": String(index) }

                            Rectangle {
                                id: dragVisual
                                anchors.fill: parent
                                color: modelData.enabled ? (selectorItem.dragging ? Theme.accent : Theme.accentBg) : "transparent"
                                radius: 8
                                border.width: modelData.enabled ? 1 : 0
                                border.color: selectorItem.dragging ? Theme.accent : Theme.accent
                                opacity: selectorItem.dragging ? 0.6 : 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    font.pixelSize: 20
                                    font.family: "Font Awesome 6 Free"
                                    color: modelData.enabled ? Theme.accent : Theme.fg
                                }

                                DropArea {
                                    id: dropArea
                                    anchors.fill: parent
                                    onEntered: {
                                        const list = Settings.rightPanelWidgets.slice()
                                        const from = Number(drag.source.index)
                                        const to = selectorItem.index
                                        if (from === to || !list[from]) return
                                        const [item] = list.splice(from, 1)
                                        list.splice(to, 0, item)
                                        Settings.rightPanelWidgets = list
                                        Settings.updateSetting("rightPanel.widgets", list)
                                    }
                                }

                                MouseArea {
                                    id: dragArea
                                    anchors.fill: parent
                                    drag.target: selectorItem
                                    drag.axis: Drag.YAxis
                                    drag.minimumY: -selectorItem.index * 48
                                    drag.maximumY: (Settings.rightPanelWidgets.length - 1 - selectorItem.index) * 48
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton

                                    onPressed: selectorItem.dragging = true
                                    onReleased: {
                                        selectorItem.dragging = false
                                        selectorItem.x = 0
                                        selectorItem.y = 0
                                    }

                                    onClicked: {
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

                // ----- Window Actions (AGS WindowActions, valign END) -----
                // Shared plain-Button styling with LeftPanel's action cluster.
                Column {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 8
                        width: parent.width
                        spacing: 4

                        // Expand (+50 to max 1500)
                        Button {
                            width: parent.width
                            padding: 8
                            contentItem: Text { anchors.centerIn: parent; text: "\u{F067}"; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; color: parent.parent.hovered ? Theme.accent : Theme.fg; horizontalAlignment: Text.AlignHCenter }
                            background: Rectangle { anchors.fill: parent; color: parent.hovered ? Theme.moduleBg : "transparent"; radius: 6 }
                            ToolTip.visible: hovered; ToolTip.text: "Expand panel"; ToolTip.delay: 600
                            onClicked: {
                                const w = Settings.rightPanelWidth
                                Settings.rightPanelWidth = w < 1500 ? w + 50 : 1500
                            }
                        }
                        // Shrink (−50 to min 250)
                        Button {
                            width: parent.width
                            padding: 8
                            contentItem: Text { anchors.centerIn: parent; text: "\u{F068}"; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; color: parent.parent.hovered ? Theme.accent : Theme.fg; horizontalAlignment: Text.AlignHCenter }
                            background: Rectangle { anchors.fill: parent; color: parent.hovered ? Theme.moduleBg : "transparent"; radius: 6 }
                            ToolTip.visible: hovered; ToolTip.text: "Shrink panel"; ToolTip.delay: 600
                            onClicked: {
                                const w = Settings.rightPanelWidth
                                Settings.rightPanelWidth = w > 250 ? w - 50 : 250
                            }
                        }
                        // Exclusivity (AGS: active = non-exclusive, inverted)
                        Button {
                            id: exclBtn
                            width: parent.width
                            checkable: true
                            checked: !Settings.rightPanelExclusivity
                            padding: 8
                            contentItem: Text { anchors.centerIn: parent; text: "\u{F2E0}"; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; color: exclBtn.checked ? Theme.accent : Theme.fg; horizontalAlignment: Text.AlignHCenter }
                            background: Rectangle { anchors.fill: parent; color: exclBtn.hovered ? Theme.moduleBg : (exclBtn.checked ? Theme.accentBg : "transparent"); radius: 6 }
                            ToolTip.visible: hovered; ToolTip.text: Settings.rightPanelExclusivity ? "Exclusive zone: on" : "Exclusive zone: off"; ToolTip.delay: 600
                            onToggled: Settings.rightPanelExclusivity = !checked
                        }
                        // Lock
                        Button {
                            id: lockBtn
                            width: parent.width
                            checkable: true
                            checked: Settings.rightPanelLock
                            padding: 8
                            contentItem: Text { anchors.centerIn: parent; text: lockBtn.checked ? "\u{F023}" : "\u{F2DC}"; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; color: lockBtn.checked ? Theme.accent : Theme.fg; horizontalAlignment: Text.AlignHCenter }
                            background: Rectangle { anchors.fill: parent; color: lockBtn.hovered ? Theme.moduleBg : (lockBtn.checked ? Theme.accentBg : "transparent"); radius: 6 }
                            ToolTip.visible: hovered; ToolTip.text: Settings.rightPanelLock ? "Unlock panel" : "Lock panel"; ToolTip.delay: 600
                            onToggled: Settings.rightPanelLock = checked
                        }
                        // Close
                        Button {
                            width: parent.width
                            padding: 8
                            contentItem: Text { anchors.centerIn: parent; text: "\u{F00D}"; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; color: parent.parent.hovered ? Theme.danger : Theme.fg; horizontalAlignment: Text.AlignHCenter }
                            background: Rectangle { anchors.fill: parent; color: parent.hovered ? Theme.moduleBg : "transparent"; radius: 6 }
                            ToolTip.visible: hovered; ToolTip.text: "Close panel"; ToolTip.delay: 600
                            onClicked: root.visible = false
                        }
                    }
            }

            // ----- Main content area — all enabled widgets -----
            ScrollView {
                id: contentScroll
                width: parent.width - sidebar.width
                height: parent.height
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AlwaysOn

                Column {
                    id: contentColumn
                    // Width MUST come from the ScrollView's explicit width, never
                    // the viewport (parent.width): the viewport width negotiates
                    // with content size, which feeds back through delegates and
                    // wedges the scene in a silent polish loop (0-width freeze).
                    width: contentScroll.width
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
                            // Panel-card heights per widget (AGS stacks natural-height
                            // cards; QS cards have fixed heights with internal scroll).
                            // Heights must stay in sync with each widget's content.
                            height: {
                                switch (modelData.name) {
                                case "Waifu":               return 360
                                case "Media":                return 240
                                case "NotificationHistory":  return 440
                                case "ScriptTimer":          return 320
                                case "Crypto":               return 440
                                case "Calendar":             return 330
                                case "SystemResources":      return 300
                                default: return 300
                                }
                            }
                            // AGS: .right-panel .main-content > * box-shadow 0 5 10 rgba(0,0,0,0.2)
                            // + .new-widget opacity-in 0.6s. The card is a tinted Rectangle
                            // with a RectangularShadow effect (QtQuick.Effects, Qt6).
                            Rectangle {
                                id: cardBg
                                anchors.fill: parent
                                anchors.margins: 5
                                color: Theme.moduleBg
                                radius: Theme.radius
                                border.width: 1
                                border.color: Theme.border
                                // AGS opacity-in on freshly added widget (.new-widget class)
                                opacity: 0
                                Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                                Component.onCompleted: opacity = 1

                                RectangularShadow {
                                    anchors.fill: parent
                                    // AGS BOX-SHADOW: 0px 5px 10px rgba(0,0,0,0.2)
                                    offset.x: 0
                                    offset.y: 5
                                    radius: 10
                                    spread: 0
                                    color: Qt.rgba(0, 0, 0, 0.2)
                                }
                            }

                            Loader {
                                id: widgetLoader
                                width: parent.width
                                height: parent.height
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