import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme
import qs.widgets.shared
import qs.services

// Settings Widget — shell settings panel
// Sections: Bar (layout reorder + toggles), Panels, Theme, Interface,
// Always-On Widget, KeyStrokeVisualizer, User Agents, Api Keys, File Manager, Hyprland,
// Apply/Reset buttons
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    // Replayable staggered section reveal (CustomScripts/KeyBinds parity):
    // StackLayout builds all tabs once at startup (hidden), so
    // creation-time fades would fire unseen and the tab switch would only
    // play the container-wide fade. Instead a counter steps 0→sectionCount
    // each time this tab becomes visible and sections key their opacity
    // off their index.
    property int revealCount: 0
    property int sectionCount: 11
    Timer {
        id: revealTimer
        interval: 60
        repeat: true
        onTriggered: {
            if (root.revealCount >= root.sectionCount)
                revealTimer.stop();
            else
                root.revealCount++;
        }
    }
    function playReveal() {
        root.revealCount = 0;
        revealTimer.restart();
    }
    onVisibleChanged: {
        if (visible) {
            root.playReveal();
            root.handlePendingTarget();
        }
    }

    // Cross-widget deep link (see Registry.selectLeftTab's `target` arg):
    // scrolls the matching row into view and briefly flashes it. Currently
    // only wired to apiKeyRepeater rows (matched by their "provider.field"
    // path) — extend the search below if other sections gain targets.
    function handlePendingTarget() {
        if (Registry.pendingTarget === "")
            return;
        const key = Registry.pendingTarget;
        Registry.pendingTarget = "";
        // Rows aren't laid out yet on the very first frame a hidden tab
        // becomes visible; defer one tick so mapToItem/contentHeight are
        // accurate.
        Qt.callLater(() => root.scrollToAndHighlight(key));
    }
    Connections {
        target: Registry
        function onPendingTargetChanged() {
            if (root.visible)
                root.handlePendingTarget();
        }
    }

    function scrollToAndHighlight(key) {
        for (let i = 0; i < apiKeyRepeater.count; i++) {
            const item = apiKeyRepeater.itemAt(i);
            if (!item || item.objectName !== key)
                continue;
            const y = item.mapToItem(settingsCol, 0, 0).y;
            const maxY = Math.max(0, settingsCol.height - settingsScroll.height);
            scrollAnim.to = Math.min(Math.max(y - 24, 0), maxY);
            scrollAnim.restart();
            if (item.flash)
                item.flash();
            return;
        }
    }
    NumberAnimation {
        id: scrollAnim
        target: settingsScroll
        property: "contentY"
        duration: 350
        easing.type: Easing.OutCubic
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Label {
                text: "Settings"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
                Layout.fillWidth: true
            }
        }

        SmoothFlickable {
            id: settingsScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: settingsCol.height
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            Column {
                id: settingsCol
                spacing: Theme.sectionSpacing
                width: settingsScroll.width

                // ============ BAR SETTINGS ============
                // NOTE: bar layout (drag-reorder), smart-hide and full-width
                // are intentionally not
                // exposed here: the bar always shows all sections in a
                // centered pill, and an unlocked bar always auto-hides until
                // the screen edge is hovered. Lock Bar below is the only
                // visibility switch.
                Rectangle {
                    width: parent.width
                    implicitHeight: barSec.implicitHeight + 20
                    opacity: root.revealCount > 0 ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    Column {
                        id: barSec
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Label {
                            text: "Bar"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }

                        Column {
                            width: parent.width
                            spacing: 4
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Orientation"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppComboBox {
                                    model: ["Top", "Bottom"]
                                    currentIndex: Settings.barOrientation ? 0 : 1
                                    onActivated: Settings.barOrientation = (index === 0)
                                    Layout.preferredWidth: 160
                                }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Lock Bar"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppCheckBox {
                                    checked: Settings.barLock
                                    onToggled: Settings.barLock = checked
                                }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Always Expanded"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppCheckBox {
                                    checked: Settings.barDefault
                                    onToggled: Settings.barDefault = checked
                                }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Workspace Numbers"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppCheckBox {
                                    checked: Settings.workspaceNumbers
                                    onToggled: Settings.workspaceNumbers = checked
                                }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Reveal-In Pressure"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppSpinBox {
                                    from: 0
                                    to: 5000
                                    value: Settings.revealInPressure
                                    Layout.preferredWidth: 160
                                    onValueChanged: {
                                        if (value === Settings.revealInPressure)
                                            return;
                                        Settings.revealInPressure = value;
                                    }
                                }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Reveal-Out Pressure"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppSpinBox {
                                    from: 0
                                    to: 5000
                                    value: Settings.revealOutPressure
                                    Layout.preferredWidth: 160
                                    onValueChanged: {
                                        if (value === Settings.revealOutPressure)
                                            return;
                                        Settings.revealOutPressure = value;
                                    }
                                }
                            }
                        }
                    }
                }

                // ============ PANEL SETTINGS ============
                Rectangle {
                    width: parent.width
                    implicitHeight: panelSec.implicitHeight + 20
                    opacity: root.revealCount > 1 ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    Column {
                        id: panelSec
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Label {
                            text: "Panels"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }

                        Column {
                            width: parent.width
                            spacing: 4
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Left Panel Width"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppSpinBox {
                                    from: 200
                                    to: 800
                                    value: Settings.leftPanelWidth
                                    Layout.preferredWidth: 160
                                    onValueChanged: {
                                        if (value === Settings.leftPanelWidth)
                                            return;
                                        Settings.leftPanelWidth = value;
                                    }
                                }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Right Panel Width"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppSpinBox {
                                    from: 200
                                    to: 800
                                    value: Settings.rightPanelWidth
                                    Layout.preferredWidth: 160
                                    onValueChanged: {
                                        if (value === Settings.rightPanelWidth)
                                            return;
                                        Settings.rightPanelWidth = value;
                                    }
                                }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Left Panel Hot Zone"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppCheckBox {
                                    checked: Settings.leftPanelHotZone
                                    onToggled: Settings.leftPanelHotZone = checked
                                }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Right Panel Hot Zone"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppCheckBox {
                                    checked: Settings.rightPanelHotZone
                                    onToggled: Settings.rightPanelHotZone = checked
                                }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Left Hot Zone Size"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppSpinBox {
                                    from: 1
                                    to: 50
                                    value: Settings.leftPanelHotZoneSize
                                    Layout.preferredWidth: 160
                                    onValueChanged: {
                                        if (value === Settings.leftPanelHotZoneSize)
                                            return;
                                        Settings.leftPanelHotZoneSize = value;
                                    }
                                }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Right Hot Zone Size"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppSpinBox {
                                    from: 1
                                    to: 50
                                    value: Settings.rightPanelHotZoneSize
                                    Layout.preferredWidth: 160
                                    onValueChanged: {
                                        if (value === Settings.rightPanelHotZoneSize)
                                            return;
                                        Settings.rightPanelHotZoneSize = value;
                                    }
                                }
                            }
                            AppButton {
                                text: "Preview Hot Zones"
                                onClicked: root.previewHotZones()
                            }
                        }
                    }
                }

                // ============ THEME SETTINGS ============
                Rectangle {
                    width: parent.width
                    implicitHeight: themeSec.implicitHeight + 20
                    opacity: root.revealCount > 2 ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    Column {
                        id: themeSec
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Label {
                            text: "Theme"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }

                        Column {
                            width: parent.width
                            spacing: 4
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Dynamic Theme Colors"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppCheckBox {
                                    checked: Settings.dynamicThemeColors
                                    onToggled: {
                                        Settings.dynamicThemeColors = checked;
                                        root.setThemeFlagInConf("autocolor", checked);
                                    }
                                }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Dynamic Theme Variants"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppCheckBox {
                                    checked: Settings.dynamicThemeVariants
                                    onToggled: {
                                        Settings.dynamicThemeVariants = checked;
                                        root.setThemeFlagInConf("autovariant", checked);
                                    }
                                }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Blur"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppCheckBox {
                                    checked: Settings.barBlur
                                    onToggled: Settings.barBlur = checked
                                }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Blur Size"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppSpinBox {
                                    from: 1
                                    to: 20
                                    value: Settings.barBlurSize
                                    Layout.preferredWidth: 160
                                    onValueChanged: {
                                        if (value === Settings.barBlurSize)
                                            return;
                                        Settings.barBlurSize = value;
                                    }
                                }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Blur Passes"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppSpinBox {
                                    from: 1
                                    to: 10
                                    value: Settings.barBlurPasses
                                    Layout.preferredWidth: 160
                                    onValueChanged: {
                                        if (value === Settings.barBlurPasses)
                                            return;
                                        Settings.barBlurPasses = value;
                                    }
                                }
                            }
                        }
                    }
                }

                // ============ INTERFACE ============
                Rectangle {
                    width: parent.width
                    implicitHeight: ifaceSec.implicitHeight + 20
                    opacity: root.revealCount > 3 ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    Column {
                        id: ifaceSec
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Label {
                            text: "Interface"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }

                        Column {
                            width: parent.width
                            spacing: 4
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Opacity"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppSlider {
                                    from: 0
                                    to: 1
                                    value: Settings.uiOpacity
                                    stepSize: 0.01
                                    Layout.preferredWidth: 150
                                    onValueChanged: {
                                        if (value === Settings.uiOpacity)
                                            return;
                                        Settings.uiOpacity = value;
                                    }
                                }
                                Label {
                                    text: Settings.uiOpacity.toFixed(2)
                                    color: Theme.fgDim
                                    Layout.preferredWidth: 34
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Scale"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppSpinBox {
                                    from: 10
                                    to: 30
                                    value: Settings.uiScale
                                    Layout.preferredWidth: 160
                                    onValueChanged: {
                                        if (value === Settings.uiScale)
                                            return;
                                        Settings.uiScale = value;
                                    }
                                }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Font Size"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppSpinBox {
                                    from: 10
                                    to: 30
                                    value: Settings.uiFontSize
                                    Layout.preferredWidth: 160
                                    onValueChanged: {
                                        if (value === Settings.uiFontSize)
                                            return;
                                        Settings.uiFontSize = value;
                                    }
                                }
                            }
                        }
                    }
                }

                // ============ ALWAYS-ON WIDGET ============
                Rectangle {
                    width: parent.width
                    implicitHeight: aowSec.implicitHeight + 20
                    opacity: root.revealCount > 4 ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    Column {
                        id: aowSec
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Label {
                            text: "Always-On Widget"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }
                        RowLayout {
                            width: parent.width
                            spacing: 8
                            Label {
                                text: "Visible"
                                color: Theme.fg
                                Layout.fillWidth: true
                            }
                            AppCheckBox {
                                checked: Settings.alwaysOnWidgetVisibility
                                onToggled: Settings.alwaysOnWidgetVisibility = checked
                            }
                        }
                    }
                }

                // ============ KEYSTROKE VISUALIZER ============
                Rectangle {
                    width: parent.width
                    implicitHeight: ksvSec.implicitHeight + 20
                    opacity: root.revealCount > 5 ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    Column {
                        id: ksvSec
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Label {
                            text: "KeyStroke Visualizer"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }
                        RowLayout {
                            width: parent.width
                            spacing: 8
                            Label {
                                text: "Visible"
                                color: Theme.fg
                                Layout.fillWidth: true
                            }
                            AppCheckBox {
                                checked: Settings.keyStrokeVisualizerVisibility
                                onToggled: {
                                    Settings.keyStrokeVisualizerVisibility = checked;
                                    if (checked)
                                        root.addUserToInputGroup();
                                }
                            }
                        }
                        RowLayout {
                            width: parent.width
                            spacing: 8
                            Label {
                                text: "Anchor"
                                color: Theme.fg
                                Layout.fillWidth: true
                            }
                            AppComboBox {
                                model: ["Bottom Left", "Bottom", "Bottom Right"]
                                currentIndex: (Settings.keyStrokeVisualizerAnchor.length === 2 && Settings.keyStrokeVisualizerAnchor[1] === "left") ? 0 : (Settings.keyStrokeVisualizerAnchor.length === 1) ? 1 : 2
                                Layout.preferredWidth: 160
                                onActivated: {
                                    if (index === 0)
                                        Settings.keyStrokeVisualizerAnchor = ["bottom", "left"];
                                    else if (index === 1)
                                        Settings.keyStrokeVisualizerAnchor = ["bottom"];
                                    else
                                        Settings.keyStrokeVisualizerAnchor = ["bottom", "right"];
                                }
                            }
                        }
                    }
                }

                // ============ USER AGENTS ============
                Rectangle {
                    width: parent.width
                    implicitHeight: uaSec.implicitHeight + 20
                    opacity: root.revealCount > 6 ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    Column {
                        id: uaSec
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Label {
                            text: "User Agents"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }
                        Column {
                            width: parent.width
                            spacing: 4
                            Repeater {
                                model: [
                                    { key: "booru", label: "Booru" },
                                    { key: "mangaDex", label: "MangaDex" },
                                    { key: "mangaLib", label: "MangaLib" },
                                    { key: "waifu", label: "Waifu" },
                                    { key: "fastfetch", label: "Fastfetch" }
                                ]
                                delegate: Rectangle {
                                    width: parent.width
                                    height: 34
                                    color: Theme.bg
                                    radius: 4

                                    property bool reveal: false

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 6
                                        Label {
                                            text: modelData.label
                                            color: Theme.fg
                                            Layout.preferredWidth: 90
                                            elide: Text.ElideRight
                                        }
                                        AppTextField {
                                            id: uaField
                                            text: Settings.userAgent(modelData.key)
                                            placeholderText: "User-Agent"
                                            echoMode: parent.parent.reveal ? TextField.Normal : TextField.Password
                                            fillColor: "transparent"
                                            Layout.fillWidth: true
                                            onAccepted: {
                                                const u = JSON.parse(JSON.stringify(Settings.userAgents || {}));
                                                u[modelData.key] = uaField.text;
                                                Settings.userAgents = u;
                                                Settings.schedulePersist();
                                            }
                                        }
                                        AppButton {
                                            text: parent.parent.reveal ? "hide" : "show"
                                            Layout.preferredWidth: 44
                                            Layout.preferredHeight: 24
                                            visible: uaField.text !== ""
                                            onClicked: parent.parent.reveal = !parent.parent.reveal
                                        }
                                        AppButton {
                                            text: "copy"
                                            Layout.preferredWidth: 44
                                            Layout.preferredHeight: 24
                                            visible: uaField.text !== ""
                                            onClicked: root.copyText(uaField.text)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ============ API KEYS ============
                Rectangle {
                    width: parent.width
                    implicitHeight: apiSec.implicitHeight + 20
                    opacity: root.revealCount > 7 ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    Column {
                        id: apiSec
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Label {
                            text: "API Keys"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }
                        Column {
                            width: parent.width
                            spacing: 4
                            Repeater {
                                id: apiKeyRepeater
                                model: [
                                    {
                                        path: "openrouter.user",
                                        label: "OpenRouter User"
                                    },
                                    {
                                        path: "openrouter.key",
                                        label: "OpenRouter API Key"
                                    },
                                    {
                                        path: "danbooru.user",
                                        label: "Danbooru User"
                                    },
                                    {
                                        path: "danbooru.key",
                                        label: "Danbooru Key"
                                    },
                                    {
                                        path: "gelbooru.user",
                                        label: "Gelbooru User"
                                    },
                                    {
                                        path: "gelbooru.key",
                                        label: "Gelbooru Key"
                                    },
                                    {
                                        path: "safebooru.user",
                                        label: "Safebooru User"
                                    },
                                    {
                                        path: "safebooru.key",
                                        label: "Safebooru Key"
                                    },
                                    {
                                        path: "wallhaven.key",
                                        label: "Wallhaven Key (optional, unlocks NSFW)"
                                    }
                                ]
                                delegate: Rectangle {
                                    id: keyRow
                                    // NOTE: Repeater has no width — size off the
                                    // section Column instead.
                                    width: parent.width
                                    height: 34
                                    color: Theme.bg
                                    radius: 4
                                    objectName: modelData.path

                                    property bool reveal: false

                                    border.color: Theme.accent
                                    border.width: 0
                                    function flash() {
                                        flashAnim.restart();
                                    }
                                    SequentialAnimation {
                                        id: flashAnim
                                        loops: 2
                                        NumberAnimation {
                                            target: keyRow
                                            property: "border.width"
                                            from: 0
                                            to: 2
                                            duration: 200
                                            easing.type: Easing.OutCubic
                                        }
                                        NumberAnimation {
                                            target: keyRow
                                            property: "border.width"
                                            from: 2
                                            to: 0
                                            duration: 500
                                            easing.type: Easing.InCubic
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 6
                                        Label {
                                            id: apiKeyLabel
                                            text: modelData.label
                                            color: Theme.fg
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        HoverHandler {
                                            id: apiKeyHoverHandler
                                            cursorShape: Qt.ArrowCursor
                                        }

                                        AppTooltip {
                                            visible: apiKeyHoverHandler.hovered && apiKeyLabel.truncated
                                            text: apiKeyLabel.text
                                        }
                                        AppTextField {
                                            id: keyField
                                            text: root.getNested(Settings.apiKeys, modelData.path)
                                            placeholderText: "Enter " + modelData.label
                                            echoMode: parent.parent.reveal ? TextField.Normal : TextField.Password
                                            fillColor: "transparent"
                                            Layout.preferredWidth: 160
                                            onAccepted: {
                                                root.setNestedValue("apiKeys", modelData.path, keyField.text, true);
                                                // Notify masked value on save (secret)
                                                Notifications.notify({
                                                    summary: modelData.label,
                                                    body: "Changed to ••••••••"
                                                });
                                            }
                                        }
                                        AppButton {
                                            text: parent.parent.reveal ? "hide" : "show"
                                            Layout.preferredWidth: 44
                                            Layout.preferredHeight: 24
                                            visible: keyField.text !== ""
                                            onClicked: parent.parent.reveal = !parent.parent.reveal
                                        }
                                        AppButton {
                                            text: "copy"
                                            Layout.preferredWidth: 44
                                            Layout.preferredHeight: 24
                                            onClicked: root.copyText(keyField.text)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ============ FILE MANAGER ============
                Rectangle {
                    width: parent.width
                    implicitHeight: fmSec.implicitHeight + 20
                    opacity: root.revealCount > 8 ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    Column {
                        id: fmSec
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Label {
                            text: "File Manager"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }
                        Column {
                            width: parent.width
                            spacing: 4
                            Repeater {
                                id: fmRepeater
                                model: root.fileManagerOptions.length ? root.fileManagerOptions : root.allFileManagers
                                delegate: RowLayout {
                                    width: parent.width
                                    spacing: 8
                                    Label {
                                        id: fmLabel
                                        text: modelData.name
                                        color: Theme.fg
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight

                                        HoverHandler {
                                            id: fmHoverHandler
                                            cursorShape: Qt.ArrowCursor
                                        }

                                        AppTooltip {
                                            visible: fmHoverHandler.hovered && fmLabel.truncated
                                            text: fmLabel.text
                                        }
                                    }
                                    AppCheckBox {
                                        checked: Settings.fileManager === modelData.id
                                        onToggled: {
                                            if (checked) {
                                                Settings.fileManager = modelData.id;
                                                // Notify "Changed to <name>"
                                                Notifications.notify({
                                                    summary: "File Manager",
                                                    body: "Changed to " + modelData.name
                                                });
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ============ HYPRLAND ============
                Rectangle {
                    width: parent.width
                    implicitHeight: hyprSec.implicitHeight + 20
                    opacity: root.revealCount > 9 ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    Column {
                        id: hyprSec
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Label {
                            text: "Hyprland"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }
                        Column {
                            width: parent.width
                            spacing: 6

                            // Game Mode
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Game Mode"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppCheckBox {
                                    checked: Settings.gameModeEnabled
                                    onToggled: Settings.applyGameMode(checked)
                                }
                            }

                            // Decoration: Rounding
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    id: hypRLabel
                                    text: "Decoration: Rounding"
                                    Layout.preferredWidth: 170
                                    color: Theme.fg
                                    elide: Text.ElideRight

                                    HoverHandler {
                                        id: hypRHover
                                        cursorShape: Qt.ArrowCursor
                                    }

                                    AppTooltip {
                                        visible: hypRHover.hovered && hypRLabel.truncated
                                        text: hypRLabel.text
                                    }
                                }
                                AppSlider {
                                    id: hypRounding
                                    from: 0
                                    to: 50
                                    value: root.hyprGet("decoration.rounding")
                                    Layout.fillWidth: true
                                    onValueChanged: {
                                        const v = Math.round(value);
                                        if (v === root.hyprGet("decoration.rounding"))
                                            return;
                                        root.hyprSet("decoration.rounding", v);
                                        root.applyHyprlandSettingLive("decoration.rounding", v);
                                    }
                                }
                                Label {
                                    text: root.hyprGet("decoration.rounding")
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // Decoration: Blur Enabled
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Decoration: Blur Enabled"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppCheckBox {
                                    checked: root.hyprGet("decoration.blur.enabled")
                                    onToggled: {
                                        root.hyprSet("decoration.blur.enabled", checked);
                                        root.applyHyprlandSettingLive("decoration.blur.enabled", checked);
                                    }
                                }
                            }
                            // Decoration: Blur Size
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    id: hypBSLabel
                                    text: "Decoration: Blur Size"
                                    Layout.preferredWidth: 170
                                    color: Theme.fg
                                    elide: Text.ElideRight

                                    HoverHandler {
                                        id: hypBSHover
                                        cursorShape: Qt.ArrowCursor
                                    }

                                    AppTooltip {
                                        visible: hypBSHover.hovered && hypBSLabel.truncated
                                        text: hypBSLabel.text
                                    }
                                }
                                AppSlider {
                                    from: 0
                                    to: 10
                                    value: root.hyprGet("decoration.blur.size")
                                    Layout.fillWidth: true
                                    onValueChanged: {
                                        const v = Math.round(value);
                                        if (v === root.hyprGet("decoration.blur.size"))
                                            return;
                                        root.hyprSet("decoration.blur.size", v);
                                        root.applyHyprlandSettingLive("decoration.blur.size", v);
                                    }
                                }
                                Label {
                                    text: root.hyprGet("decoration.blur.size")
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // Decoration: Blur Passes
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    id: hypBPLabel
                                    text: "Decoration: Blur Passes"
                                    Layout.preferredWidth: 170
                                    color: Theme.fg
                                    elide: Text.ElideRight

                                    HoverHandler {
                                        id: hypBPHover
                                        cursorShape: Qt.ArrowCursor
                                    }

                                    AppTooltip {
                                        visible: hypBPHover.hovered && hypBPLabel.truncated
                                        text: hypBPLabel.text
                                    }
                                }
                                AppSlider {
                                    from: 0
                                    to: 10
                                    value: root.hyprGet("decoration.blur.passes")
                                    Layout.fillWidth: true
                                    onValueChanged: {
                                        const v = Math.round(value);
                                        if (v === root.hyprGet("decoration.blur.passes"))
                                            return;
                                        root.hyprSet("decoration.blur.passes", v);
                                        root.applyHyprlandSettingLive("decoration.blur.passes", v);
                                    }
                                }
                                Label {
                                    text: root.hyprGet("decoration.blur.passes")
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // Decoration: Blur Xray
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Decoration: Blur Xray"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppCheckBox {
                                    checked: root.hyprGet("decoration.blur.xray")
                                    onToggled: {
                                        root.hyprSet("decoration.blur.xray", checked);
                                        root.applyHyprlandSettingLive("decoration.blur.xray", checked);
                                    }
                                }
                            }
                            // Decoration: Shadow Enabled
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Decoration: Shadow Enabled"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppCheckBox {
                                    checked: root.hyprGet("decoration.shadow.enabled")
                                    onToggled: {
                                        root.hyprSet("decoration.shadow.enabled", checked);
                                        root.applyHyprlandSettingLive("decoration.shadow.enabled", checked);
                                    }
                                }
                            }
                            // Decoration: Shadow Range
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    id: hypSRLabel
                                    text: "Decoration: Shadow Range"
                                    Layout.preferredWidth: 170
                                    color: Theme.fg
                                    elide: Text.ElideRight

                                    HoverHandler {
                                        id: hypSRHover
                                        cursorShape: Qt.ArrowCursor
                                    }

                                    AppTooltip {
                                        visible: hypSRHover.hovered && hypSRLabel.truncated
                                        text: hypSRLabel.text
                                    }
                                }
                                AppSlider {
                                    from: 0
                                    to: 20
                                    value: root.hyprGet("decoration.shadow.range")
                                    Layout.fillWidth: true
                                    onValueChanged: {
                                        const v = Math.round(value);
                                        if (v === root.hyprGet("decoration.shadow.range"))
                                            return;
                                        root.hyprSet("decoration.shadow.range", v);
                                        root.applyHyprlandSettingLive("decoration.shadow.range", v);
                                    }
                                }
                                Label {
                                    text: root.hyprGet("decoration.shadow.range")
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // Decoration: Shadow Render Power
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    id: hypSRPLabel
                                    text: "Shadow Render Power"
                                    Layout.preferredWidth: 170
                                    color: Theme.fg
                                    elide: Text.ElideRight

                                    HoverHandler {
                                        id: hypSRPHover
                                        cursorShape: Qt.ArrowCursor
                                    }

                                    AppTooltip {
                                        visible: hypSRPHover.hovered && hypSRPLabel.truncated
                                        text: hypSRPLabel.text
                                    }
                                }
                                AppSlider {
                                    from: 0
                                    to: 20
                                    value: root.hyprGet("decoration.shadow.render_power")
                                    Layout.fillWidth: true
                                    onValueChanged: {
                                        const v = Math.round(value);
                                        if (v === root.hyprGet("decoration.shadow.render_power"))
                                            return;
                                        root.hyprSet("decoration.shadow.render_power", v);
                                        root.applyHyprlandSettingLive("decoration.shadow.render_power", v);
                                    }
                                }
                                Label {
                                    text: root.hyprGet("decoration.shadow.render_power")
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // General: Border Size
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    id: hypBSzLabel
                                    text: "General: Border Size"
                                    Layout.preferredWidth: 170
                                    color: Theme.fg
                                    elide: Text.ElideRight

                                    HoverHandler {
                                        id: hypBSzHover
                                        cursorShape: Qt.ArrowCursor
                                    }

                                    AppTooltip {
                                        visible: hypBSzHover.hovered && hypBSzLabel.truncated
                                        text: hypBSzLabel.text
                                    }
                                }
                                AppSlider {
                                    from: 0
                                    to: 10
                                    value: root.hyprGet("general.border_size")
                                    Layout.fillWidth: true
                                    onValueChanged: {
                                        const v = Math.round(value);
                                        if (v === root.hyprGet("general.border_size"))
                                            return;
                                        root.hyprSet("general.border_size", v);
                                        root.applyHyprlandSettingLive("general.border_size", v);
                                    }
                                }
                                Label {
                                    text: root.hyprGet("general.border_size")
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // General: Gaps In
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    id: hypGILabel
                                    text: "General: Gaps In"
                                    Layout.preferredWidth: 170
                                    color: Theme.fg
                                    elide: Text.ElideRight

                                    HoverHandler {
                                        id: hypGIHover
                                        cursorShape: Qt.ArrowCursor
                                    }

                                    AppTooltip {
                                        visible: hypGIHover.hovered && hypGILabel.truncated
                                        text: hypGILabel.text
                                    }
                                }
                                AppSlider {
                                    from: 0
                                    to: 20
                                    value: root.hyprGet("general.gaps_in")
                                    Layout.fillWidth: true
                                    onValueChanged: {
                                        const v = Math.round(value);
                                        if (v === root.hyprGet("general.gaps_in"))
                                            return;
                                        root.hyprSet("general.gaps_in", v);
                                        root.applyHyprlandSettingLive("general.gaps_in", v);
                                    }
                                }
                                Label {
                                    text: root.hyprGet("general.gaps_in")
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // General: Gaps Out
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    id: hypGOLabel
                                    text: "General: Gaps Out"
                                    Layout.preferredWidth: 170
                                    color: Theme.fg
                                    elide: Text.ElideRight

                                    HoverHandler {
                                        id: hypGOHover
                                        cursorShape: Qt.ArrowCursor
                                    }

                                    AppTooltip {
                                        visible: hypGOHover.hovered && hypGOLabel.truncated
                                        text: hypGOLabel.text
                                    }
                                }
                                AppSlider {
                                    from: 0
                                    to: 40
                                    value: root.hyprGet("general.gaps_out")
                                    Layout.fillWidth: true
                                    onValueChanged: {
                                        const v = Math.round(value);
                                        if (v === root.hyprGet("general.gaps_out"))
                                            return;
                                        root.hyprSet("general.gaps_out", v);
                                        root.applyHyprlandSettingLive("general.gaps_out", v);
                                    }
                                }
                                Label {
                                    text: root.hyprGet("general.gaps_out")
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // Decoration: Active Opacity (float)
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    id: hypAOLabel
                                    text: "Decoration: Active Opacity"
                                    Layout.preferredWidth: 170
                                    color: Theme.fg
                                    elide: Text.ElideRight

                                    HoverHandler {
                                        id: hypAOHover
                                        cursorShape: Qt.ArrowCursor
                                    }

                                    AppTooltip {
                                        visible: hypAOHover.hovered && hypAOLabel.truncated
                                        text: hypAOLabel.text
                                    }
                                }
                                AppSlider {
                                    from: 0
                                    to: 1
                                    stepSize: 0.01
                                    value: root.hyprGet("decoration.active_opacity")
                                    Layout.fillWidth: true
                                    onValueChanged: {
                                        const v = parseFloat(value.toFixed(2));
                                        if (v === root.hyprGet("decoration.active_opacity"))
                                            return;
                                        root.hyprSet("decoration.active_opacity", v);
                                        root.applyHyprlandSettingLive("decoration.active_opacity", v);
                                    }
                                }
                                Label {
                                    text: Number(root.hyprGet("decoration.active_opacity")).toFixed(2)
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // Decoration: Inactive Opacity (float)
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    id: hypIOLabel
                                    text: "Decoration: Inactive Opacity"
                                    Layout.preferredWidth: 170
                                    color: Theme.fg
                                    elide: Text.ElideRight

                                    HoverHandler {
                                        id: hypIOHover
                                        cursorShape: Qt.ArrowCursor
                                    }

                                    AppTooltip {
                                        visible: hypIOHover.hovered && hypIOLabel.truncated
                                        text: hypIOLabel.text
                                    }
                                }
                                AppSlider {
                                    from: 0
                                    to: 1
                                    stepSize: 0.01
                                    value: root.hyprGet("decoration.inactive_opacity")
                                    Layout.fillWidth: true
                                    onValueChanged: {
                                        const v = parseFloat(value.toFixed(2));
                                        if (v === root.hyprGet("decoration.inactive_opacity"))
                                            return;
                                        root.hyprSet("decoration.inactive_opacity", v);
                                        root.applyHyprlandSettingLive("decoration.inactive_opacity", v);
                                    }
                                }
                                Label {
                                    text: Number(root.hyprGet("decoration.inactive_opacity")).toFixed(2)
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }

                            // Apply / Reset
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                AppButton {
                                    text: "Apply Hyprland Settings"
                                    Layout.fillWidth: true
                                    onClicked: root.applyHyprlandSettings()
                                }
                                AppButton {
                                    text: "Reset to Default"
                                    Layout.fillWidth: true
                                    onClicked: root.resetToDefaults()
                                }
                            }
                        }
                    }
                }

                // ============ LOCKSCREEN ============
                Rectangle {
                    width: parent.width
                    implicitHeight: lockSec.implicitHeight + 20
                    opacity: root.revealCount > 10 ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    Column {
                        id: lockSec
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Label {
                            text: "Lockscreen"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }
                        Column {
                            width: parent.width
                            spacing: 4
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Label {
                                    text: "Grace Period (seconds)"
                                    color: Theme.fg
                                    Layout.fillWidth: true
                                }
                                AppSpinBox {
                                    from: 0
                                    to: 120
                                    value: Settings.lockGraceSeconds
                                    Layout.preferredWidth: 160
                                    onValueChanged: {
                                        if (value === Settings.lockGraceSeconds)
                                            return;
                                        Settings.lockGraceSeconds = value;
                                    }
                                }
                            }
                            Label {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Esc dismisses the lock without a password within this window after locking."
                                color: Theme.fgDim
                                font.pixelSize: Theme.fontSize - 1
                            }
                        }
                    }
                }
            }
        }
    }

    // ------- helpers -------

    readonly property var allFileManagers: [
        {
            id: "nautilus",
            name: "Nautilus (GNOME)",
            command: "nautilus"
        },
        {
            id: "thunar",
            name: "Thunar (XFCE)",
            command: "thunar"
        },
        {
            id: "dolphin",
            name: "Dolphin (KDE)",
            command: "dolphin"
        },
        {
            id: "nemo",
            name: "Nemo (Cinnamon)",
            command: "nemo"
        },
        {
            id: "pcmanfm",
            name: "PCManFM",
            command: "pcmanfm"
        },
        {
            id: "ranger",
            name: "Ranger (Terminal)",
            command: "kitty ranger"
        }
    ]

    property var fileManagerOptions: Settings.fileManagerOptions || []
    property var installedFileManagers: []

    // Detect installed file managers via `command -v`
    function detectFileManagers() {
        const found = [];
        for (let i = 0; i < root.allFileManagers.length; i++) {
            const fm = root.allFileManagers[i];
            const bin = fm.command.split(" ")[0];
            const proc = Qt.createQmlObject('import Quickshell.Io; Process { command: ["bash", "-c", "command -v ' + bin + ' >/dev/null 2>&1 && echo yes || echo no"]; running: true; stdout: StdioCollector {} }', root);
            proc.stdout.onStreamFinished.connect(function (fmref, binref) {
                return function () {
                    const r = proc.stdout.text.trim();
                    if (r === "yes")
                        found.push(fmref);
                    proc.destroy();
                };
            }(fm, bin));
        }
        // Set after a short delay to let all processes finish
        Qt.callLater(function () {
            // prefer Settings-selected fm in list
            root.installedFileManagers = found;
            root.fileManagerOptions = found;
        });
    }

    Component.onCompleted: {
        root.detectFileManagers();
        if (visible)
            root.playReveal();
    }

    // Get a nested value from Settings.hyprland by dotted path (e.g. "decoration.rounding")
    function hyprGet(path) {
        const keys = path.split(".");
        let o = Settings.hyprland;
        for (const k of keys) {
            if (o == null)
                return 0;
            o = o[k];
        }
        return (o == null) ? 0 : o;
    }

    // Set a nested value in Settings.hyprland by dotted path. Reassigns a
    // fresh object so bindings (hyprGet call sites) re-evaluate — plain
    // in-place mutation would leave sliders stale after Reset.
    function hyprSet(path, value) {
        const keys = path.split(".");
        const h = JSON.parse(JSON.stringify(Settings.hyprland || {}));
        let o = h;
        for (let i = 0; i < keys.length - 1; i++) {
            if (o[keys[i]] == null || typeof o[keys[i]] !== "object")
                o[keys[i]] = {};
            o = o[keys[i]];
        }
        o[keys[keys.length - 1]] = value;
        Settings.hyprland = h;
        // notify Settings so it can re-read; schedule persist to save the nested object
        Settings.schedulePersist();
    }

    // Lua value/key builders:
    // nested tables — hl.config({ decoration = { rounding = 16 } }).
    // The old QS flat form hl.config({ decoration:rounding = 16 }) is
    // invalid Lua and hyprland silently ignores those files.
    function luaValue(v) {
        if (typeof v === "boolean")
            return v ? "true" : "false";
        if (typeof v === "number")
            return String(v);
        if (Array.isArray(v))
            return "{ " + v.map(x => root.luaValue(x)).join(", ") + " }";
        return "\"" + String(v).replace(/\\/g, "\\\\").replace(/\"/g, "\\\"") + "\"";
    }
    function luaKey(k) {
        return /^[A-Za-z_][A-Za-z0-9_]*$/.test(k) ? k : "[\"" + k + "\"]";
    }
    function buildLuaConfig(fullKey, value) {
        const parts = fullKey.split(":");
        let expr = root.luaValue(value);
        for (let i = parts.length - 1; i >= 0; i--)
            expr = "{ " + root.luaKey(parts[i]) + " = " + expr + " }";
        return "hl.config(" + expr + ")";
    }

    // Get nested value from an object by dotted path. Unwraps
    // credential objects ({value: ...}) to plain strings for display.
    function getNested(obj, path) {
        if (!path || !obj)
            return "";
        const keys = path.split(".");
        let o = obj;
        for (const k of keys) {
            if (o == null)
                return "";
            o = o[k];
        }
        if (o == null)
            return "";
        if (typeof o === "object")
            return (o.value ?? "");
        return o;
    }

    // Set nested value by dotted path. persistIfSetting == true for apiKeys group.
    // Preserves credential objects (writes .value, keeps shape on disk).
    function setNestedValue(propRoot, path, value, persist) {
        // propRoot is a Settings property name; navigate from Settings
        const keys = path.split(".");
        let o = Settings[propRoot];
        if (o == null)
            o = {};
        for (let i = 0; i < keys.length - 1; i++) {
            if (o[keys[i]] == null)
                o[keys[i]] = {};
            o = o[keys[i]];
        }
        const leaf = keys[keys.length - 1];
        if (o[leaf] != null && typeof o[leaf] === "object" && "value" in o[leaf])
            o[leaf].value = value;
        else
            o[leaf] = value;
        Settings[propRoot] = JSON.parse(JSON.stringify(Settings[propRoot]));
        if (persist)
            Settings.schedulePersist();
    }

    function copyText(t) {
        Qt.callLater(function () {
            Quickshell.execDetached(["wl-copy", t]);
        });
    }

    // Write autocolor/autovariant flag into hypr theme conf
    function setThemeFlagInConf(flag, enabled) {
        const confPath = "$HOME/.config/hypr/" + root.themeConfName;
        const val = enabled ? "true" : "false";
        Qt.callLater(function () {
            Quickshell.execDetached(["bash", "-c", `if [[ -f "${confPath}" ]]; then
                  sed -i 's/^${flag}=.*/${flag}=${val}/' "${confPath}"
                  grep -q '^${flag}=' "${confPath}" || printf '%s\\n' '${flag}=${val}' >> "${confPath}"
                else
                  printf '%s\\n' '${flag}=${val}' > "${confPath}"
                fi`]);
        });
    }

    property string themeConfName: "theme/theme.conf"

    function previewHotZones() {
        Qt.callLater(function () {
            Quickshell.execDetached(["hyprctl", "notify", "3", "3000", "rgb(ff9800)", "Hot zones highlighted"]);
        });
    }

    // Apply single Hyprland setting immediately (live): nested-table lua
    // file per key (`${fullKey}.lua`) + instant
    // `hyprctl keyword`.
    function applyHyprlandSettingLive(fullKey, value) {
        const keyword = fullKey.replace(/\./g, ":");
        const luaConfig = root.buildLuaConfig(keyword, value);
        try {
            Quickshell.execDetached(["bash", "-c", `mkdir -p $HOME/.config/hypr/config/custom && ` + `cat > $HOME/.config/hypr/config/custom/${keyword}.lua <<'EOF'\n${luaConfig}\nEOF\n` + `hyprctl keyword ${keyword} ${value}`]);
        } catch (e) {
            console.warn("[Settings] apply live:", e);
        }
    }

    // Add user to input group (for KeyStrokeVisualizer). Declarative
    // chained Processes + Timer (no
    // setTimeout — doesn't exist in QML; no createQmlObject string escaping).
    // Exit via Hyprland.dispatch("hl.dsp.exit()").
    property string _inputUser: ""
    property Timer _inputExitTimer: Timer {
        interval: 5000
        repeat: false
        running: false
        onTriggered: Hyprland.dispatch("hl.dsp.exit()")
    }
    Component {
        id: inputCheckProc
        Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    const r = text.trim();
                    if (r !== "yes" && r !== "") {
                        root._inputUser = r;
                        Notifications.notify({
                            summary: "Key Stroke Visualizer",
                            body: "Adding " + r + " to 'input' group for keystroke detection.\n You may be prompted for your password."
                        });
                        const p = inputAddProc.createObject(root);
                        p.command = ["pkexec", "usermod", "-aG", "input", r];
                        p.running = true;
                    }
                }
            }
        }
    }
    Component {
        id: inputAddProc
        Process {
            onExited: code => {
                if (code === 0) {
                    Notifications.notify({
                        summary: "Key Stroke Visualizer",
                        body: "Will be Logging out to apply changes. in 5 seconds..."
                    });
                    root._inputExitTimer.restart();
                } else {
                    Notifications.notify({
                        summary: "Error",
                        body: "Failed to add user to input group"
                    });
                }
            }
        }
    }
    function addUserToInputGroup() {
        const p = inputCheckProc.createObject(root);
        p.command = ["bash", "-c", "groups $USER | grep -q '\\binput\\b' && echo 'yes' || echo $USER"];
        p.running = true;
    }

    function applyHyprlandSettings() {
        // Write one nested-table lua file per leaf (recursive
        // recursion) + reload. JSON.stringify of the whole object is NOT
        // valid lua (keys need `=`, nesting needs tables).
        try {
            const leaves = [];
            const walk = (o, prefix) => {
                for (const k of Object.keys(o)) {
                    const v = o[k];
                    const full = prefix ? prefix + "." + k : k;
                    if (v !== null && typeof v === "object" && !Array.isArray(v))
                        walk(v, full);
                    else
                        leaves.push([full, v]);
                }
            };
            walk(Settings.hyprland || {}, "");
            let script = "mkdir -p $HOME/.config/hypr/config/custom";
            for (const [full, v] of leaves) {
                const keyword = full.replace(/\./g, ":");
                const lua = root.buildLuaConfig(keyword, v);
                script += ` && cat > $HOME/.config/hypr/config/custom/${keyword}.lua <<'EOF'\n${lua}\nEOF\n`;
            }
            script += " && hyprctl reload";
            Quickshell.execDetached(["bash", "-c", script]);
        } catch (e) {
            console.warn("[Settings] apply hyprland:", e);
        }
    }

    function resetToDefaults() {
        Settings.barLock = true;
        Settings.barSmartHide = false;
        Settings.barDefault = true;
        Settings.barFullWidth = false;
        Settings.revealInPressure = 250;
        Settings.revealOutPressure = 1000;
        Settings.barOrientation = true;
        Settings.workspaceNumbers = false;
        Settings.barLayout = {
            workspaces: true,
            information: true,
            utilities: true
        };
        Settings.barLayoutOrder = ["workspaces", "information", "utilities"];
        Settings.leftPanelWidth = 400;
        Settings.rightPanelWidth = 250;
        Settings.leftPanelHotZone = true;
        Settings.rightPanelHotZone = true;
        Settings.leftPanelHotZoneSize = 5;
        Settings.rightPanelHotZoneSize = 5;
        Settings.dynamicThemeColors = true;
        Settings.dynamicThemeVariants = true;
        Settings.barBlur = true;
        Settings.barBlurSize = 4;
        Settings.barBlurPasses = 4;
        Settings.uiOpacity = 0.618;
        Settings.uiScale = 10;
        Settings.uiFontSize = 12;
        Settings.alwaysOnWidgetVisibility = true;
        Settings.keyStrokeVisualizerVisibility = false;
        Settings.keyStrokeVisualizerAnchor = ["bottom", "left"];
        Settings.fileManager = "nautilus";
        // Hyprland defaults
        root.hyprSet("general.border_size", 0);
        root.hyprSet("general.gaps_in", 7);
        root.hyprSet("general.gaps_out", 10);
        root.hyprSet("decoration.rounding", 16);
        root.hyprSet("decoration.active_opacity", 0.9);
        root.hyprSet("decoration.inactive_opacity", 0.8);
        root.hyprSet("decoration.blur.enabled", true);
        root.hyprSet("decoration.blur.size", 4);
        root.hyprSet("decoration.blur.passes", 4);
        root.hyprSet("decoration.blur.xray", false);
        root.hyprSet("decoration.shadow.enabled", true);
        root.hyprSet("decoration.shadow.range", 15);
        root.hyprSet("decoration.shadow.render_power", 3);
        Settings.schedulePersist();
    }
}
