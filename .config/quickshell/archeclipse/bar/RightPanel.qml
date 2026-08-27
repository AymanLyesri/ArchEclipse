import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
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
    WlrLayershell.layer: WlrLayer.Top

    // Visibility: controlled by HotZone, keybind, or IPC
    // Don't declare local 'visible' property - it shadows WindowInterface.visible
    // Instead use a private property for internal state
    property bool _visible: false
    // Expose via property alias for external access
    // The actual window visibility is controlled by the PanelWindow's visible property

    // Selected widget state - track which widgets are enabled and their order
    // Load from settings on startup
    property var enabledWidgets: [
        { name: "Calendar", icon: "\uf073", enabled: true },
        { name: "Crypto", icon: "\uf15a", enabled: false },
        { name: "Media", icon: "\uf144", enabled: false },
        { name: "NotificationHistory", icon: "\uf0f3", enabled: true },
        { name: "ScriptTimer", icon: "\uf017", enabled: false },
        { name: "SystemResources", icon: "\uf080", enabled: true },
        { name: "Waifu", icon: "\uf0ac", enabled: true }
    ]

    // Track drag state for reordering
    property int dragFromIndex: -1
    property bool isDragging: false

    // FileView for settings persistence
    property FileView _settingsFile: FileView {
        path: `${Quickshell.env("HOME")}/.config/ags/cache/settings/settings.json`
    }

    // Register with Registry for IPC togglePanel
    Component.onCompleted: {
        Registry.register(`right-panel-${root.monitorName}`, root);
        // Load widget settings from AGS settings file
        loadWidgetSettings();
        // Start hidden
        visible = false;
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
                    id: selectorRepeater
                    model: root.enabledWidgets
                    delegate: Item {
                        id: selectorItem
                        width: parent.width
                        height: 40

                        // Drag handle area (left side)
                        Rectangle {
                            id: dragHandle
                            width: 24
                            height: 40
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            color: "transparent"

                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                drag.target: selectorItem
                                drag.axis: Drag.YAxis
                                drag.minimumY: 0
                                drag.maximumY: selectorColumn.height - 40
                                drag.onActiveChanged: {
                                    if (drag.active) {
                                        root.dragFromIndex = modelData.index;
                                        root.isDragging = true;
                                    } else {
                                        root.isDragging = false;
                                        root.dragFromIndex = -1;
                                    }
                                }
                            }
                        }

                        // Widget selector button (right side)
                        Button {
                            id: selectorBtn
                            width: parent.width - 24
                            height: 40
                            anchors.right: parent.right
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
                                    saveWidgetSettings();
                                }
                            }
                        }

                        // Drop target for reordering
                        DropArea {
                            id: dropArea
                            anchors.fill: parent
                            onEntered: {
                                if (root.isDragging && root.dragFromIndex !== modelData.index) {
                                    const fromIdx = root.dragFromIndex;
                                    const toIdx = modelData.index;
                                    const updated = root.enabledWidgets.slice();
                                    const [moved] = updated.splice(fromIdx, 1);
                                    updated.splice(toIdx, 0, moved);
                                    root.enabledWidgets = updated;
                                    root.dragFromIndex = toIdx;
                                    saveWidgetSettings();
                                }
                            }
                            keys: ["text/plain"]
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
                            case "Crypto": return cryptoWidget;
                            case "Media": return mediaWidget;
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

    function loadWidgetSettings() {
        try {
            const text = root._settingsFile.text();
            if (text !== "" && text.trim().startsWith("{")) {
                const settings = JSON.parse(text);
                if (settings.rightPanel && settings.rightPanel.widgets) {
                    const savedWidgets = settings.rightPanel.widgets;
                    const updated = root.enabledWidgets.map(w => {
                        const saved = savedWidgets.find(s => s.name === w.name);
                        return saved ? Object.assign({}, w, { enabled: saved.enabled }) : w;
                    });
                    root.enabledWidgets = updated;
                }
            }
        } catch (e) {
            console.warn("[RightPanel] Failed to load widget settings:", e);
        }
    }

    function saveWidgetSettings() {
        try {
            const text = root._settingsFile.text();
            let settings = {};
            if (text !== "" && text.trim().startsWith("{")) {
                settings = JSON.parse(text);
            }
            if (!settings.rightPanel) settings.rightPanel = {};
            settings.rightPanel.widgets = root.enabledWidgets.map(w => ({ name: w.name, icon: w.icon, enabled: w.enabled }));
            root._settingsFile.setText(JSON.stringify(settings, null, 2));
        } catch (e) {
            console.warn("[RightPanel] Failed to save widget settings:", e);
        }
    }

    // Placeholder components for each widget - use actual widget implementations
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
        CalendarWidget {}
    }
    Component {
        id: cryptoWidget
        CryptoWidget {}
    }
    Component {
        id: mediaWidget
        MediaWidget {}
    }
    Component {
        id: notificationHistoryWidget
        NotificationHistoryWidget {}
    }
    Component {
        id: scriptTimerWidget
        ScriptTimerWidget {}
    }
    Component {
        id: systemResourcesWidget
        SystemResourcesWidget {}
    }
    Component {
        id: waifuWidget
        WaifuWidget {}
    }
}