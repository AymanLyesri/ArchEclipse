import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme
import qs.services

// Settings Widget — full AGS parity port
// Sections: Bar (layout reorder + toggles), Panels, Theme, Interface,
// Always-On Widget, KeyStrokeVisualizer, Api Keys, File Manager, Hyprland,
// Apply/Reset buttons
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    Column {
        anchors.fill: parent
        spacing: 10

        Row {
            spacing: 8
            Label {
                text: "Settings"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
                Layout.fillWidth: true
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Column {
                spacing: 16
                width: parent.width

                // ============ BAR LAYOUT (drag-reorder) ============
                Column {
                    spacing: 8
                    Label { text: "Bar Layout (Drag to Reorder)"; font.pixelSize: Theme.fontSize + 2; font.bold: true; color: Theme.accent }

                    Repeater {
                        id: barLayoutRepeater
                        model: root.barLayoutModelList

                        Rectangle {
                            id: rowWrap
                            width: barLayoutRepeater.width
                            height: 34
                            radius: 4
                            color: Theme.buttonHoverBg
                            border.color: Theme.border
                            border.width: 1
                            property bool dragActive: false

                            // Drag source (AGS Gtk.DragSource). dragType is
                            // required — without it no drag events reach
                            // DropAreas. DropArea is a SIBLING of the
                            // MouseArea (stable while another row drags).
                            Drag.active: dragMa.drag.active
                            Drag.dragType: Drag.Automatic
                            Drag.hotSpot.x: width / 2
                            Drag.hotSpot.y: height / 2
                            Drag.mimeData: { "text/plain": String(index) }
                            Drag.onDragFinished: rowWrap.dragActive = false

                            MouseArea {
                                id: dragMa
                                anchors.fill: parent
                                drag.target: rowWrap
                                drag.smoothed: false
                                onPressed: rowWrap.dragActive = true
                                onReleased: { rowWrap.dragActive = false; rowWrap.Drag.drop() }

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 8
                                    CheckBox {
                                        id: layoutCheck
                                        anchors.verticalCenter: parent.verticalCenter
                                        checked: model.enabled
                                        onToggled: {
                                            const m = root.barLayoutModelList.slice()
                                            m[index] = Object.assign({}, m[index], { enabled: checked })
                                            root.barLayoutModelList = m
                                            root.applyBarLayout(m)
                                        }
                                    }
                                    Label {
                                        text: model.label + "  \u2630"
                                        color: Theme.fg
                                        font.pixelSize: Theme.fontSize
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }

                            // Drop target: reorder when another row is
                            // dropped here (self-drops ignored).
                            DropArea {
                                id: dropArea
                                anchors.fill: parent
                                keys: ["text/plain"]
                                onDropped: (drop) => {
                                    const fromIdx = Number(drop.mimeData.getDataAsString
                                        ? drop.mimeData.getDataAsString("text/plain")
                                        : drop.getDataAsString("text/plain"))
                                    if (fromIdx !== index) root.reorderBarLayout(fromIdx, index)
                                    drop.accept(Qt.MoveAction)
                                }
                            }

                            // Fallback reorder buttons (drag is finicky on
                            // touchpads; AGS parity is the drag path above).
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: 4
                                spacing: 2
                                Button {
                                    text: "\u{F106}"
                                    width: 24; height: 24
                                    enabled: index > 0
                                    onClicked: root.reorderBarLayout(index, index - 1)
                                    background: Rectangle { color: "transparent" }
                                    contentItem: Text { anchors.centerIn: parent; text: parent.text; color: Theme.fgDim; font.pixelSize: 10 }
                                }
                                Button {
                                    text: "\u{F107}"
                                    width: 24; height: 24
                                    enabled: index < root.barLayoutModelList.length - 1
                                    onClicked: root.reorderBarLayout(index, index + 1)
                                    background: Rectangle { color: "transparent" }
                                    contentItem: Text { anchors.centerIn: parent; text: parent.text; color: Theme.fgDim; font.pixelSize: 10 }
                                }
                            }
                        }
                    }
                }

                // ============ BAR SETTINGS ============
                Column {
                    spacing: 8
                    Label { text: "Bar"; font.pixelSize: Theme.fontSize + 2; font.bold: true; color: Theme.accent }

                    Column {
                        spacing: 4
                        Row {
                            spacing: 8
                            Label { text: "Orientation"; Layout.preferredWidth: 100; color: Theme.fg }
                            ComboBox {
                                model: ["Top", "Bottom"]
                                currentIndex: Settings.barOrientation ? 0 : 1
                                onActivated: Settings.barOrientation = (index === 0)
                                Layout.fillWidth: true
                            }
                        }
                        CheckBox { text: "Lock Bar"; checked: Settings.barLock; onToggled: Settings.barLock = checked }
                        CheckBox { text: "Smart Hide"; checked: Settings.barSmartHide; onToggled: Settings.barSmartHide = checked }
                        CheckBox { text: "Always Expanded"; checked: Settings.barExpanded; onToggled: Settings.barExpanded = checked }
                        CheckBox { text: "Full Width"; checked: Settings.barFullWidth; onToggled: Settings.barFullWidth = checked }
                        CheckBox { text: "Workspace Numbers"; checked: Settings.workspaceNumbers; onToggled: Settings.workspaceNumbers = checked }
                        Row {
                            spacing: 8
                            Label { text: "Reveal Pressure"; Layout.preferredWidth: 100; color: Theme.fg }
                            Slider { from: 1; to: 500; value: Settings.revealPressure; Layout.fillWidth: true; onValueChanged: Settings.revealPressure = value }
                        }
                    }
                }

                // ============ PANEL SETTINGS ============
                Column {
                    spacing: 8
                    Label { text: "Panels"; font.pixelSize: Theme.fontSize + 2; font.bold: true; color: Theme.accent }

                    Column {
                        spacing: 4
                        Row {
                            spacing: 8
                            Label { text: "Left Panel Width"; color: Theme.fg }
                            SpinBox {
                                from: 200; to: 800; value: Settings.leftPanelWidth
                                onValueChanged: Settings.leftPanelWidth = value
                            }
                        }
                        Row {
                            spacing: 8
                            Label { text: "Right Panel Width"; color: Theme.fg }
                            SpinBox {
                                from: 200; to: 800; value: Settings.rightPanelWidth
                                onValueChanged: Settings.rightPanelWidth = value
                            }
                        }
                        CheckBox { text: "Left Panel Hot Zone"; checked: Settings.leftPanelHotZone; onToggled: Settings.leftPanelHotZone = checked }
                        CheckBox { text: "Right Panel Hot Zone"; checked: Settings.rightPanelHotZone; onToggled: Settings.rightPanelHotZone = checked }
                        Row {
                            spacing: 8
                            Label { text: "Left Hot Zone Size"; Layout.preferredWidth: 100; color: Theme.fg }
                            SpinBox {
                                from: 1; to: 100; value: Settings.leftPanelHotZoneSize
                                onValueChanged: Settings.leftPanelHotZoneSize = value
                            }
                        }
                        Row {
                            spacing: 8
                            Label { text: "Right Hot Zone Size"; Layout.preferredWidth: 100; color: Theme.fg }
                            SpinBox {
                                from: 1; to: 100; value: Settings.rightPanelHotZoneSize
                                onValueChanged: Settings.rightPanelHotZoneSize = value
                            }
                        }
                        Button {
                            text: "Preview Hot Zones"
                            onClicked: root.previewHotZones()
                            background: Rectangle { color: Theme.accentBg; radius: 4; border.color: Theme.accent; border.width: 1 }
                            contentItem: Text { color: Theme.accent; font.pixelSize: Theme.fontSize; anchors.centerIn: parent }
                        }
                    }
                }

                // ============ THEME SETTINGS ============
                Column {
                    spacing: 8
                    Label { text: "Theme"; font.pixelSize: Theme.fontSize + 2; font.bold: true; color: Theme.accent }

                    Column {
                        spacing: 4
                        CheckBox { text: "Dynamic Theme Colors"; checked: Settings.dynamicThemeColors; onToggled: { Settings.dynamicThemeColors = checked; root.setThemeFlagInConf("autocolor", checked) } }
                        CheckBox { text: "Dynamic Theme Variants"; checked: Settings.dynamicThemeVariants; onToggled: { Settings.dynamicThemeVariants = checked; root.setThemeFlagInConf("autovariant", checked) } }
                        CheckBox { text: "Blur"; checked: Settings.barBlur; onToggled: Settings.barBlur = checked }
                        Row {
                            spacing: 8
                            Label { text: "Blur Size"; Layout.preferredWidth: 100; color: Theme.fg }
                            SpinBox {
                                from: 1; to: 20; value: Settings.barBlurSize
                                onValueChanged: Settings.barBlurSize = value
                            }
                        }
                        Row {
                            spacing: 8
                            Label { text: "Blur Passes"; Layout.preferredWidth: 100; color: Theme.fg }
                            SpinBox {
                                from: 1; to: 10; value: Settings.barBlurPasses
                                onValueChanged: Settings.barBlurPasses = value
                            }
                        }
                    }
                }

                // ============ INTERFACE ============
                Column {
                    spacing: 8
                    Label { text: "Interface"; font.pixelSize: Theme.fontSize + 2; font.bold: true; color: Theme.accent }

                    Column {
                        spacing: 4
                        Row {
                            spacing: 8
                            Label { text: "Opacity"; Layout.preferredWidth: 100; color: Theme.fg }
                            Slider {
                                from: 0; to: 1; value: Settings.uiOpacity; stepSize: 0.01; Layout.fillWidth: true
                                onValueChanged: Settings.uiOpacity = value
                            }
                        }
                        Row {
                            spacing: 8
                            Label { text: "Scale"; Layout.preferredWidth: 100; color: Theme.fg }
                            SpinBox {
                                from: 8; to: 20; value: Settings.uiScale; Layout.fillWidth: true
                                onValueChanged: Settings.uiScale = value
                            }
                        }
                        Row {
                            spacing: 8
                            Label { text: "Font Size"; Layout.preferredWidth: 100; color: Theme.fg }
                            SpinBox {
                                from: 10; to: 20; value: Settings.uiFontSize; Layout.fillWidth: true
                                onValueChanged: Settings.uiFontSize = value
                            }
                        }
                    }
                }

                // ============ ALWAYS-ON WIDGET ============
                Column {
                    spacing: 8
                    Label { text: "Always-On Widget"; font.pixelSize: Theme.fontSize + 2; font.bold: true; color: Theme.accent }
                    CheckBox { text: "Visible"; checked: Settings.alwaysOnWidgetVisibility; onToggled: Settings.alwaysOnWidgetVisibility = checked }
                }

                // ============ KEYSTROKE VISUALIZER ============
                Column {
                    spacing: 8
                    Label { text: "KeyStroke Visualizer"; font.pixelSize: Theme.fontSize + 2; font.bold: true; color: Theme.accent }
                    CheckBox { text: "Visible"; checked: Settings.keyStrokeVisualizerVisibility; onToggled: { Settings.keyStrokeVisualizerVisibility = checked; if (checked) root.addUserToInputGroup() } }
                    Row {
                        spacing: 8
                        Label { text: "Anchor"; Layout.preferredWidth: 100; color: Theme.fg }
                        ComboBox {
                            model: ["Bottom Left", "Bottom", "Bottom Right"]
                            currentIndex: (Settings.keyStrokeVisualizerAnchor.length === 2 && Settings.keyStrokeVisualizerAnchor[1] === "left") ? 0 : (Settings.keyStrokeVisualizerAnchor.length === 1) ? 1 : 2
                            onActivated: {
                                if (index === 0) Settings.keyStrokeVisualizerAnchor = ["bottom", "left"]
                                else if (index === 1) Settings.keyStrokeVisualizerAnchor = ["bottom"]
                                else Settings.keyStrokeVisualizerAnchor = ["bottom", "right"]
                            }
                        }
                    }
                }

                // ============ API KEYS ============
                Column {
                    spacing: 8
                    Label { text: "API Keys"; font.pixelSize: Theme.fontSize + 2; font.bold: true; color: Theme.accent }
                    Column {
                        spacing: 4
                        Repeater {
                            id: apiKeyRepeater
                            model: [
                                { path: "openrouter.user", label: "OpenRouter User" },
                                { path: "openrouter.key", label: "OpenRouter API Key" },
                                { path: "danbooru.user", label: "Danbooru User" },
                                { path: "danbooru.key", label: "Danbooru Key" },
                                { path: "gelbooru.user", label: "Gelbooru User" },
                                { path: "gelbooru.key", label: "Gelbooru Key" },
                                { path: "safebooru.user", label: "Safebooru User" },
                                { path: "safebooru.key", label: "Safebooru Key" }
                            ]
                            delegate: Rectangle {
                                width: apiKeyRepeater.width
                                height: 34
                                color: Theme.moduleBg
                                radius: 4
                                border.color: Theme.border
                                border.width: 1

                                property bool reveal: false

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 6
                                    Label { text: model.label; color: Theme.fg; Layout.preferredWidth: 140 }
                                    TextField {
                                        id: keyField
                                        text: root.getNested(Settings.apiKeys, model.path)
                                        placeholderText: "Enter " + model.label
                                        echoMode: parent.parent.reveal ? TextField.Normal : TextField.Password
                                        Layout.fillWidth: true
                                        onAccepted: {
                                            root.setNestedValue("apiKeys", model.path, keyField.text, true)
                                            // AGS notifies masked value on save (secret)
                                            Notifications.notify({ summary: model.label, body: "Changed to ••••••••" })
                                        }
                                        background: Rectangle { color: "transparent" }
                                    }
                                    Button {
                                        text: parent.parent.reveal ? "hide" : "show"
                                        width: 44; height: 24
                                        visible: keyField.text !== ""
                                        onClicked: parent.parent.reveal = !parent.parent.reveal
                                        background: Rectangle { color: Theme.accentBg; radius: 3 }
                                        contentItem: Text { anchors.centerIn: parent; color: Theme.accent; font.pixelSize: 10; text: parent.parent.reveal ? "hide" : "show" }
                                    }
                                    Button {
                                        text: "copy"
                                        width: 44; height: 24
                                        onClicked: root.copyText(keyField.text)
                                        background: Rectangle { color: Theme.accentBg; radius: 3 }
                                        contentItem: Text { anchors.centerIn: parent; color: Theme.accent; font.pixelSize: 10; text: "copy" }
                                    }
                                }
                            }
                        }
                    }
                }

                // ============ FILE MANAGER ============
                Column {
                    spacing: 8
                    Label { text: "File Manager"; font.pixelSize: Theme.fontSize + 2; font.bold: true; color: Theme.accent }
                    Column {
                        spacing: 4
                        Repeater {
                            id: fmRepeater
                            model: root.fileManagerOptions.length ? root.fileManagerOptions : root.allFileManagers
                            delegate: CheckBox {
                                text: modelData.name
                                checked: Settings.fileManager === modelData.id
                                onToggled: {
                                    if (checked) {
                                        Settings.fileManager = modelData.id
                                        // AGS notifies "Changed to <name>"
                                        Notifications.notify({ summary: "File Manager", body: "Changed to " + modelData.name })
                                    }
                                }
                            }
                        }
                    }
                }

                // ============ HYPRLAND ============
                Column {
                    spacing: 8
                    Label { text: "Hyprland"; font.pixelSize: Theme.fontSize + 2; font.bold: true; color: Theme.accent }
                    Column {
                        spacing: 6

                        // Decoration: Rounding
                        Row {
                            spacing: 8
                            Label { text: "Decoration: Rounding"; Layout.preferredWidth: 170; color: Theme.fg }
                            Slider {
                                id: hypRounding
                                from: 0; to: 50; value: root.hyprGet("decoration.rounding")
                                Layout.fillWidth: true
                                onValueChanged: { const v = Math.round(value); root.hyprSet("decoration.rounding", v) }
                            }
                            Label { text: root.hyprGet("decoration.rounding"); Layout.preferredWidth: 30; color: Theme.fgDim }
                        }
                        // Decoration: Blur Enabled
                        CheckBox {
                            text: "Decoration: Blur Enabled"
                            checked: root.hyprGet("decoration.blur.enabled")
                            onToggled: { root.hyprSet("decoration.blur.enabled", checked); root.applyHyprlandSettingLive("decoration.blur.enabled", checked) }
                        }
                        // Decoration: Blur Size
                        Row {
                            spacing: 8
                            Label { text: "Decoration: Blur Size"; Layout.preferredWidth: 170; color: Theme.fg }
                            Slider {
                                from: 0; to: 10; value: root.hyprGet("decoration.blur.size")
                                Layout.fillWidth: true
                                onValueChanged: { const v = Math.round(value); root.hyprSet("decoration.blur.size", v); root.applyHyprlandSettingLive("decoration.blur.size", v) }
                            }
                            Label { text: root.hyprGet("decoration.blur.size"); Layout.preferredWidth: 30; color: Theme.fgDim }
                        }
                        // Decoration: Blur Passes
                        Row {
                            spacing: 8
                            Label { text: "Decoration: Blur Passes"; Layout.preferredWidth: 170; color: Theme.fg }
                            Slider {
                                from: 0; to: 10; value: root.hyprGet("decoration.blur.passes")
                                Layout.fillWidth: true
                                onValueChanged: { const v = Math.round(value); root.hyprSet("decoration.blur.passes", v); root.applyHyprlandSettingLive("decoration.blur.passes", v) }
                            }
                            Label { text: root.hyprGet("decoration.blur.passes"); Layout.preferredWidth: 30; color: Theme.fgDim }
                        }
                        // Decoration: Blur Xray
                        CheckBox {
                            text: "Decoration: Blur Xray"
                            checked: root.hyprGet("decoration.blur.xray")
                            onToggled: { root.hyprSet("decoration.blur.xray", checked); root.applyHyprlandSettingLive("decoration.blur.xray", checked) }
                        }
                        // Decoration: Shadow Enabled
                        CheckBox {
                            text: "Decoration: Shadow Enabled"
                            checked: root.hyprGet("decoration.shadow.enabled")
                            onToggled: { root.hyprSet("decoration.shadow.enabled", checked); root.applyHyprlandSettingLive("decoration.shadow.enabled", checked) }
                        }
                        // Decoration: Shadow Range
                        Row {
                            spacing: 8
                            Label { text: "Decoration: Shadow Range"; Layout.preferredWidth: 170; color: Theme.fg }
                            Slider {
                                from: 0; to: 20; value: root.hyprGet("decoration.shadow.range")
                                Layout.fillWidth: true
                                onValueChanged: { const v = Math.round(value); root.hyprSet("decoration.shadow.range", v); root.applyHyprlandSettingLive("decoration.shadow.range", v) }
                            }
                            Label { text: root.hyprGet("decoration.shadow.range"); Layout.preferredWidth: 30; color: Theme.fgDim }
                        }
                        // Decoration: Shadow Render Power
                        Row {
                            spacing: 8
                            Label { text: "Shadow Render Power"; Layout.preferredWidth: 170; color: Theme.fg }
                            Slider {
                                from: 0; to: 20; value: root.hyprGet("decoration.shadow.render_power")
                                Layout.fillWidth: true
                                onValueChanged: { const v = Math.round(value); root.hyprSet("decoration.shadow.render_power", v); root.applyHyprlandSettingLive("decoration.shadow.render_power", v) }
                            }
                            Label { text: root.hyprGet("decoration.shadow.render_power"); Layout.preferredWidth: 30; color: Theme.fgDim }
                        }
                        // General: Border Size
                        Row {
                            spacing: 8
                            Label { text: "General: Border Size"; Layout.preferredWidth: 170; color: Theme.fg }
                            Slider {
                                from: 0; to: 10; value: root.hyprGet("general.border_size")
                                Layout.fillWidth: true
                                onValueChanged: { const v = Math.round(value); root.hyprSet("general.border_size", v); root.applyHyprlandSettingLive("general.border_size", v) }
                            }
                            Label { text: root.hyprGet("general.border_size"); Layout.preferredWidth: 30; color: Theme.fgDim }
                        }
                        // General: Gaps In
                        Row {
                            spacing: 8
                            Label { text: "General: Gaps In"; Layout.preferredWidth: 170; color: Theme.fg }
                            Slider {
                                from: 0; to: 20; value: root.hyprGet("general.gaps_in")
                                Layout.fillWidth: true
                                onValueChanged: { const v = Math.round(value); root.hyprSet("general.gaps_in", v); root.applyHyprlandSettingLive("general.gaps_in", v) }
                            }
                            Label { text: root.hyprGet("general.gaps_in"); Layout.preferredWidth: 30; color: Theme.fgDim }
                        }
                        // General: Gaps Out
                        Row {
                            spacing: 8
                            Label { text: "General: Gaps Out"; Layout.preferredWidth: 170; color: Theme.fg }
                            Slider {
                                from: 0; to: 40; value: root.hyprGet("general.gaps_out")
                                Layout.fillWidth: true
                                onValueChanged: { const v = Math.round(value); root.hyprSet("general.gaps_out", v); root.applyHyprlandSettingLive("general.gaps_out", v) }
                            }
                            Label { text: root.hyprGet("general.gaps_out"); Layout.preferredWidth: 30; color: Theme.fgDim }
                        }
                        // Decoration: Active Opacity (float)
                        Row {
                            spacing: 8
                            Label { text: "Decoration: Active Opacity"; Layout.preferredWidth: 170; color: Theme.fg }
                            Slider {
                                from: 0; to: 1; stepSize: 0.01; value: root.hyprGet("decoration.active_opacity")
                                Layout.fillWidth: true
                                onValueChanged: { const v = parseFloat(value.toFixed(2)); root.hyprSet("decoration.active_opacity", v); root.applyHyprlandSettingLive("decoration.active_opacity", v) }
                            }
                            Label { text: Number(root.hyprGet("decoration.active_opacity")).toFixed(2); Layout.preferredWidth: 30; color: Theme.fgDim }
                        }
                        // Decoration: Inactive Opacity (float)
                        Row {
                            spacing: 8
                            Label { text: "Decoration: Inactive Opacity"; Layout.preferredWidth: 170; color: Theme.fg }
                            Slider {
                                from: 0; to: 1; stepSize: 0.01; value: root.hyprGet("decoration.inactive_opacity")
                                Layout.fillWidth: true
                                onValueChanged: { const v = parseFloat(value.toFixed(2)); root.hyprSet("decoration.inactive_opacity", v); root.applyHyprlandSettingLive("decoration.inactive_opacity", v) }
                            }
                            Label { text: Number(root.hyprGet("decoration.inactive_opacity")).toFixed(2); Layout.preferredWidth: 30; color: Theme.fgDim }
                        }

                        // Apply / Reset
                        Row {
                            spacing: 8
                            Button {
                                text: "Apply Hyprland Settings"
                                onClicked: root.applyHyprlandSettings()
                                background: Rectangle { color: Theme.accentBg; radius: 4; border.color: Theme.accent; border.width: 1 }
                                contentItem: Text { color: Theme.accent; font.pixelSize: Theme.fontSize; anchors.centerIn: parent }
                            }
                            Button {
                                text: "Reset to Default"
                                onClicked: root.resetToDefaults()
                                background: Rectangle { color: Theme.dangerBg; radius: 4; border.color: Theme.danger; border.width: 1 }
                                contentItem: Text { color: Theme.danger; font.pixelSize: Theme.fontSize; anchors.centerIn: parent }
                            }
                        }
                    }
                }
            }
        }
    }

    // ------- helpers -------

    readonly property var allFileManagers: [
        { id: "nautilus", name: "Nautilus (GNOME)", command: "nautilus" },
        { id: "thunar", name: "Thunar (XFCE)", command: "thunar" },
        { id: "dolphin", name: "Dolphin (KDE)", command: "dolphin" },
        { id: "nemo", name: "Nemo (Cinnamon)", command: "nemo" },
        { id: "pcmanfm", name: "PCManFM", command: "pcmanfm" },
        { id: "ranger", name: "Ranger (Terminal)", command: "kitty ranger" }
    ]

    property var fileManagerOptions: Settings.fileManagerOptions || []
    property var installedFileManagers: []

    // Port of AGS detectFileManagers — check which FMs are installed via `command -v`
    function detectFileManagers() {
        const found = []
        for (let i = 0; i < root.allFileManagers.length; i++) {
            const fm = root.allFileManagers[i]
            const bin = fm.command.split(" ")[0]
            const proc = Qt.createQmlObject(
                'import Quickshell.Io; Process { command: ["bash", "-c", "command -v ' + bin + ' >/dev/null 2>&1 && echo yes || echo no"]; running: true; stdout: StdioCollector {} }',
                root
            )
            proc.stdout.onStreamFinished.connect(function(fmref, binref) {
                return function() {
                    const r = proc.stdout.text.trim()
                    if (r === "yes") found.push(fmref)
                    proc.destroy()
                }
            }(fm, bin))
        }
        // Set after a short delay to let all processes finish
        Qt.callLater(function(){
            // prefer Settings-selected fm in list
            root.installedFileManagers = found
            root.fileManagerOptions = found
        })
    }

    Component.onCompleted: root.detectFileManagers()
    // Bar-layout model follows Settings order (drag-reorder sequence).
    // Labels mirror AGS barWidgetSelectors names.
    property var barLayoutModelList: (Settings.barLayoutOrder || ["workspaces", "information", "utilities"]).map(n => ({
        name: n,
        enabled: (Settings.barLayout || {})[n] ?? true,
        label: n === "workspaces" ? "Workspaces" : n === "information" ? "Information" : "Utilities"
    }))
    Connections {
        target: Settings
        function onBarLayoutChanged() { root.refreshBarLayoutModel() }
        function onBarLayoutOrderChanged() { root.refreshBarLayoutModel() }
    }
    function refreshBarLayoutModel() {
        root.barLayoutModelList = (Settings.barLayoutOrder || ["workspaces", "information", "utilities"]).map(n => ({
            name: n,
            enabled: (Settings.barLayout || {})[n] ?? true,
            label: n === "workspaces" ? "Workspaces" : n === "information" ? "Information" : "Utilities"
        }))
    }

    // Get a nested value from Settings.hyprland by dotted path (e.g. "decoration.rounding")
    function hyprGet(path) {
        const keys = path.split(".")
        let o = Settings.hyprland
        for (const k of keys) { if (o == null) return 0; o = o[k] }
        return (o == null) ? 0 : o
    }

    // Set a nested value in Settings.hyprland by dotted path. Reassigns a
    // fresh object so bindings (hyprGet call sites) re-evaluate — plain
    // in-place mutation would leave sliders stale after Reset.
    function hyprSet(path, value) {
        const keys = path.split(".")
        const h = JSON.parse(JSON.stringify(Settings.hyprland || {}))
        let o = h
        for (let i = 0; i < keys.length - 1; i++) {
            if (o[keys[i]] == null || typeof o[keys[i]] !== "object") o[keys[i]] = {}
            o = o[keys[i]]
        }
        o[keys[keys.length - 1]] = value
        Settings.hyprland = h
        // notify Settings so it can re-read; schedule persist to save the nested object
        Settings.schedulePersist()
    }

    // Port of AGS toLuaValue/toLuaKey/buildLuaConfig (SettingsWidget.tsx):
    // nested tables — hl.config({ decoration = { rounding = 16 } }).
    // The old QS flat form hl.config({ decoration:rounding = 16 }) is
    // invalid Lua and hyprland silently ignores those files.
    function luaValue(v) {
        if (typeof v === "boolean") return v ? "true" : "false"
        if (typeof v === "number") return String(v)
        if (Array.isArray(v)) return "{ " + v.map(x => root.luaValue(x)).join(", ") + " }"
        return "\"" + String(v).replace(/\\/g, "\\\\").replace(/\"/g, "\\\"") + "\""
    }
    function luaKey(k) {
        return /^[A-Za-z_][A-Za-z0-9_]*$/.test(k) ? k : "[\"" + k + "\"]"
    }
    function buildLuaConfig(fullKey, value) {
        const parts = fullKey.split(":")
        let expr = root.luaValue(value)
        for (let i = parts.length - 1; i >= 0; i--)
            expr = "{ " + root.luaKey(parts[i]) + " = " + expr + " }"
        return "hl.config(" + expr + ")"
    }

    // Get nested value from an object by dotted path. Unwraps AGS
    // credential objects ({value: ...}) to plain strings for display.
    function getNested(obj, path) {
        if (!path || !obj) return "";
        const keys = path.split(".")
        let o = obj
        for (const k of keys) { if (o == null) return ""; o = o[k] }
        if (o == null) return ""
        if (typeof o === "object") return (o.value ?? "")
        return o
    }

    // Set nested value by dotted path. persistIfSetting == true for apiKeys group.
    // Preserves AGS credential objects (writes .value, keeps shape on disk).
    function setNestedValue(propRoot, path, value, persist) {
        // propRoot is a Settings property name; navigate from Settings
        const keys = path.split(".")
        let o = Settings[propRoot]
        if (o == null) o = {}
        for (let i = 0; i < keys.length - 1; i++) {
            if (o[keys[i]] == null) o[keys[i]] = {}
            o = o[keys[i]]
        }
        const leaf = keys[keys.length - 1]
        if (o[leaf] != null && typeof o[leaf] === "object" && "value" in o[leaf])
            o[leaf].value = value
        else
            o[leaf] = value
        Settings[propRoot] = JSON.parse(JSON.stringify(Settings[propRoot]))
        if (persist) Settings.schedulePersist()
    }

    function copyText(t) {
        Qt.callLater(function(){ Quickshell.execDetached(["wl-copy", t]) })
    }

    // Port of AGS setThemeFlagInConf — write autocolor/autovariant flag into hypr theme conf
    function setThemeFlagInConf(flag, enabled) {
        const confPath = "$HOME/.config/hypr/" + root.themeConfName
        const val = enabled ? "true" : "false"
        Qt.callLater(function(){
            Quickshell.execDetached(["bash", "-c",
                `if [[ -f "${confPath}" ]]; then
                  sed -i 's/^${flag}=.*/${flag}=${val}/' "${confPath}"
                  grep -q '^${flag}=' "${confPath}" || printf '%s\\n' '${flag}=${val}' >> "${confPath}"
                else
                  printf '%s\\n' '${flag}=${val}' > "${confPath}"
                fi`
            ])
        })
    }

    property string themeConfName: "theme/theme.conf"

    function previewHotZones() {
        Qt.callLater(function(){ Quickshell.execDetached(["hyprctl", "notify", "3", "3000", "rgb(ff9800)", "Hot zones highlighted"]) })
    }

    function applyBarLayout(newLayout) {
        // Name-based (not positional) so reorder + toggle compose; order
        // persisted via barLayoutOrder for the shared bar.layout array.
        const flags = Object.assign({}, Settings.barLayout || {})
        for (const item of newLayout) flags[item.name] = !!item.enabled
        Settings.barLayout = flags
        Settings.barLayoutOrder = newLayout.map(item => item.name)
        Settings.schedulePersist()
    }

    // Port of AGS moveItem + drag-drop reorder of bar layout
    function reorderBarLayout(from, to) {
        if (from < 0 || to < 0 || from >= root.barLayoutModelList.length || to >= root.barLayoutModelList.length || from === to) return
        const copy = root.barLayoutModelList.slice()
        const [item] = copy.splice(from, 1)
        copy.splice(to, 0, item)
        root.barLayoutModelList = copy
        root.applyBarLayout(copy)
    }

    // Apply single Hyprland setting immediately (live), mirroring AGS
    // applyHyprlandSetting: nested-table lua file per key (AGS filename
    // `${fullKey}.lua`, so both shells overwrite the same file) + instant
    // `hyprctl keyword`.
    function applyHyprlandSettingLive(fullKey, value) {
        const keyword = fullKey.replace(/\./g, ":")
        const luaConfig = root.buildLuaConfig(keyword, value)
        try {
            Quickshell.execDetached(["bash", "-c",
                `mkdir -p $HOME/.config/hypr/config/custom && ` +
                `cat > $HOME/.config/hypr/config/custom/${keyword}.lua <<'EOF'\n${luaConfig}\nEOF\n` +
                `hyprctl keyword ${keyword} ${value}`])
        } catch (e) { console.warn("[Settings] apply live:", e) }
    }

    // Add user to input group (for KeyStrokeVisualizer) — port of AGS
    // addUserToInputGroup. Declarative chained Processes + Timer (no
    // setTimeout — doesn't exist in QML; no createQmlObject string escaping).
    // Exit via Hyprland.dispatch("hl.dsp.exit()") matching AGS.
    property string _inputUser: ""
    property Timer _inputExitTimer: Timer {
        interval: 5000; repeat: false; running: false
        onTriggered: Hyprland.dispatch("hl.dsp.exit()")
    }
    Component { id: inputCheckProc; Process {
        stdout: StdioCollector { onStreamFinished: {
            const r = text.trim()
            if (r !== "yes" && r !== "") {
                root._inputUser = r
                Notifications.notify({ summary: "Key Stroke Visualizer", body: "Adding " + r + " to 'input' group for keystroke detection.\n You may be prompted for your password." })
                const p = inputAddProc.createObject(root)
                p.command = ["pkexec", "usermod", "-aG", "input", r]
                p.running = true
            }
        } }
    } }
    Component { id: inputAddProc; Process {
        onExited: (code) => {
            if (code === 0) {
                Notifications.notify({ summary: "Key Stroke Visualizer", body: "Will be Logging out to apply changes. in 5 seconds..." })
                root._inputExitTimer.restart()
            } else {
                Notifications.notify({ summary: "Error", body: "Failed to add user to input group" })
            }
        }
    } }
    function addUserToInputGroup() {
        const p = inputCheckProc.createObject(root)
        p.command = ["bash", "-c", "groups $USER | grep -q '\\binput\\b' && echo 'yes' || echo $USER"]
        p.running = true
    }

    function applyHyprlandSettings() {
        // Write one nested-table lua file per leaf (AGS applyHyprlandSettings
        // recursion) + reload. JSON.stringify of the whole object is NOT
        // valid lua (keys need `=`, nesting needs tables).
        try {
            const leaves = []
            const walk = (o, prefix) => {
                for (const k of Object.keys(o)) {
                    const v = o[k]
                    const full = prefix ? prefix + "." + k : k
                    if (v !== null && typeof v === "object" && !Array.isArray(v)) walk(v, full)
                    else leaves.push([full, v])
                }
            }
            walk(Settings.hyprland || {}, "")
            let script = "mkdir -p $HOME/.config/hypr/config/custom"
            for (const [full, v] of leaves) {
                const keyword = full.replace(/\./g, ":")
                const lua = root.buildLuaConfig(keyword, v)
                script += ` && cat > $HOME/.config/hypr/config/custom/${keyword}.lua <<'EOF'\n${lua}\nEOF\n`
            }
            script += " && hyprctl reload"
            Quickshell.execDetached(["bash", "-c", script])
        } catch (e) { console.warn("[Settings] apply hyprland:", e) }
    }

    function resetToDefaults() {
        Settings.barLock = true
        Settings.barSmartHide = false
        Settings.barExpanded = false
        Settings.barFullWidth = false
        Settings.revealPressure = 250
        Settings.barOrientation = true
        Settings.workspaceNumbers = false
        Settings.barLayout = { workspaces: true, information: true, utilities: true }
        Settings.barLayoutOrder = ["workspaces", "information", "utilities"]
        Settings.leftPanelWidth = 400
        Settings.rightPanelWidth = 250
        Settings.leftPanelHotZone = true
        Settings.rightPanelHotZone = true
        Settings.leftPanelHotZoneSize = 5
        Settings.rightPanelHotZoneSize = 5
        Settings.dynamicThemeColors = true
        Settings.dynamicThemeVariants = true
        Settings.barBlur = true
        Settings.barBlurSize = 4
        Settings.barBlurPasses = 3
        Settings.uiOpacity = 0.618
        Settings.uiScale = 10
        Settings.uiFontSize = 12
        Settings.alwaysOnWidgetVisibility = true
        Settings.keyStrokeVisualizerVisibility = false
        Settings.keyStrokeVisualizerAnchor = ["bottom", "left"]
        Settings.fileManager = ""
        // Hyprland defaults (AGS settings.constants.ts hyprland schema)
        root.hyprSet("general.border_size", 0)
        root.hyprSet("general.gaps_in", 7)
        root.hyprSet("general.gaps_out", 10)
        root.hyprSet("decoration.rounding", 16)
        root.hyprSet("decoration.active_opacity", 0.9)
        root.hyprSet("decoration.inactive_opacity", 0.8)
        root.hyprSet("decoration.blur.enabled", true)
        root.hyprSet("decoration.blur.size", 4)
        root.hyprSet("decoration.blur.passes", 4)
        root.hyprSet("decoration.blur.xray", false)
        root.hyprSet("decoration.shadow.enabled", true)
        root.hyprSet("decoration.shadow.range", 15)
        root.hyprSet("decoration.shadow.render_power", 3)
        Settings.schedulePersist()
    }
}
