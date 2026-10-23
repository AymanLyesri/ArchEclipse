import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.widgets.shared
import qs.services

// Settings Widget — shell settings panel
// Sections: Bar (layout reorder + toggles), Panels, Theme, Interface,
// Animations, User Agents, Api Keys, File Manager, Hyprland,
// Apply/Reset buttons
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""
    property string monitorName: ""

    // Replayable staggered section reveal (CustomScripts/KeyBinds parity):
    // StackLayout builds all tabs once at startup (hidden), so
    // creation-time fades would fire unseen and the tab switch would only
    // play the container-wide fade. Instead a counter steps 0→sectionCount
    // each time this tab becomes visible and sections key their opacity
    // off their index.
    property int revealCount: 0
    property int sectionCount: 10
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
        const key = Registry.takePendingTarget(root.monitorName);
        if (key === "")
            return;
        // Rows aren't laid out yet on the very first frame a hidden tab
        // becomes visible; defer one tick so mapToItem/contentHeight are
        // accurate.
        Qt.callLater(() => root.scrollToAndHighlight(key));
    }
    Connections {
        target: Registry
        function onPendingTargetsChanged() {
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
        duration: Theme.anim.fastSpatial
        easing.type: Easing.OutCubic
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing
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
                spacing: Theme.spacing
                width: settingsScroll.width
                bottomPadding: Theme.pad

                // ============ BAR SETTINGS ============
                // NOTE: smart-hide and full-width
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
                        anchors.margins: Theme.pad
                        spacing: Theme.spacing
                        Label {
                            text: "Bar"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacing
                            SettingRow {
                                text: "Orientation"
                                tip: "Top or bottom edge for the bar."
                                AppComboBox {
                                    model: ["Top", "Bottom"]
                                    currentIndex: Settings.barOrientation ? 0 : 1
                                    onActivated: Settings.barOrientation = (index === 0)
                                    Layout.preferredWidth: 160
                                }
                            }
                            SettingRow {
                                text: "Lock Bar"
                                tip: "Keep bar visible; when off it auto-hides."
                                AppToggle {
                                    checked: Settings.barLock
                                    onToggled: Settings.barLock = checked
                                }
                            }
                            SettingRow {
                                text: "Always Expanded"
                                tip: "Show full bar content instead of collapsed."
                                AppToggle {
                                    checked: Settings.barDefault
                                    onToggled: Settings.barDefault = checked
                                }
                            }
                            SettingRow {
                                text: "Reveal-In Pressure"
                                tip: "Cursor push needed to reveal a hidden bar."
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
                            SettingRow {
                                text: "Reveal-Out Pressure"
                                tip: "Cursor push needed to hide the bar."
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
                        anchors.margins: Theme.pad
                        spacing: Theme.spacing
                        Label {
                            text: "Panels"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacing
                            SettingRow {
                                text: "Left Panel Width"
                                tip: "Width of the left side panel on this monitor in px."
                                AppSpinBox {
                                    from: 200
                                    to: 1500
                                    value: Settings.panelWidthFor("left", root.monitorName)
                                    Layout.preferredWidth: 160
                                    onValueChanged: {
                                        if (value === Settings.panelWidthFor("left", root.monitorName))
                                            return;
                                        Settings.setPanelWidthFor("left", root.monitorName, value);
                                    }
                                }
                            }
                            SettingRow {
                                text: "Right Panel Width"
                                tip: "Width of the right side panel on this monitor in px."
                                AppSpinBox {
                                    from: 200
                                    to: 1500
                                    value: Settings.panelWidthFor("right", root.monitorName)
                                    Layout.preferredWidth: 160
                                    onValueChanged: {
                                        if (value === Settings.panelWidthFor("right", root.monitorName))
                                            return;
                                        Settings.setPanelWidthFor("right", root.monitorName, value);
                                    }
                                }
                            }
                            SettingRow {
                                text: "Left Panel Hot Zone"
                                tip: "Hover the left edge to open the left panel."
                                AppToggle {
                                    checked: Settings.leftPanelHotZone
                                    onToggled: Settings.leftPanelHotZone = checked
                                }
                            }
                            SettingRow {
                                text: "Right Panel Hot Zone"
                                tip: "Hover the right edge to open the right panel."
                                AppToggle {
                                    checked: Settings.rightPanelHotZone
                                    onToggled: Settings.rightPanelHotZone = checked
                                }
                            }
                            SettingRow {
                                text: "Left Hot Zone Size"
                                tip: "Hover strip width on the left edge in px."
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
                            SettingRow {
                                text: "Right Hot Zone Size"
                                tip: "Hover strip width on the right edge in px."
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
                                tooltipText: "Flash the edge hover areas on screen."
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
                        anchors.margins: Theme.pad
                        spacing: Theme.spacing
                        Label {
                            text: "Theme"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacing
                            SettingRow {
                                text: "Dynamic Theme Colors"
                                tip: "Recolor the theme from the wallpaper."
                                AppToggle {
                                    checked: Settings.dynamicThemeColors
                                    onToggled: {
                                        Settings.dynamicThemeColors = checked;
                                        root.setThemeFlagInConf("autocolor", checked);
                                    }
                                }
                            }
                            SettingRow {
                                text: "Dynamic Theme Variants"
                                tip: "Switch light/dark variant from wallpaper."
                                AppToggle {
                                    checked: Settings.dynamicThemeVariants
                                    onToggled: {
                                        Settings.dynamicThemeVariants = checked;
                                        root.setThemeFlagInConf("autovariant", checked);
                                    }
                                }
                            }
                            SettingRow {
                                text: "Blur"
                                tip: "Blur the background behind the bar."
                                AppToggle {
                                    checked: Settings.barBlur
                                    onToggled: Settings.barBlur = checked
                                }
                            }
                            SettingRow {
                                text: "Blur Size"
                                tip: "Blur radius; higher is softer."
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
                            SettingRow {
                                text: "Blur Passes"
                                tip: "Blur quality passes; higher costs GPU."
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
                        anchors.margins: Theme.pad
                        spacing: Theme.spacing
                        Label {
                            text: "Interface"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacing
                            SettingRow {
                                text: "Opacity"
                                tip: "Shell opacity; 1 is fully opaque."
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
                                    font.pixelSize: Theme.fontSize
                                    text: Settings.uiOpacity.toFixed(2)
                                    color: Theme.fgDim
                                    Layout.preferredWidth: 34
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                            SettingRow {
                                text: "Scale"
                                tip: "Global UI scale factor."
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
                            SettingRow {
                                text: "Font Size"
                                tip: "Base font size for shell text."
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

                // ============ ANIMATIONS ============
                Rectangle {
                    width: parent.width
                    implicitHeight: animSec.implicitHeight + 20
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
                        id: animSec
                        anchors.fill: parent
                        anchors.margins: Theme.pad
                        spacing: Theme.spacing
                        Label {
                            text: "Animations"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }

                        property var styleValues: ["Standard", "Emphasized", "ExpressiveFast", "ExpressiveDefault", "ExpressiveSlow"]
                        property var styleLabels: ["Standard (smooth)", "Emphasized (smooth)", "Bouncy Fast", "Bouncy Default", "Bouncy Slow"]

                        Column {
                            width: parent.width
                            spacing: Theme.spacing
                            SettingRow {
                                text: "Enabled"
                                tip: "Turn all shell animations on or off."
                                AppToggle {
                                    checked: Settings.animationsEnabled
                                    onToggled: Settings.animationsEnabled = checked
                                }
                            }
                            SettingRow {
                                text: "Speed"
                                tip: "Duration multiplier; lower is faster."
                                AppSlider {
                                    from: 0.2
                                    to: 2.0
                                    stepSize: 0.05
                                    value: Settings.animScale
                                    Layout.preferredWidth: 150
                                    onValueChanged: {
                                        const v = Math.round(value * 100) / 100;
                                        if (Math.abs(v - Settings.animScale) < 0.001)
                                            return;
                                        Settings.animScale = v;
                                    }
                                }
                                Label {
                                    font.pixelSize: Theme.fontSize
                                    text: Settings.animScale.toFixed(2) + "×"
                                    color: Theme.fgDim
                                    Layout.preferredWidth: 44
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                            Label {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Lower is faster (duration multiplier)."
                                color: Theme.fgDim
                                font.pixelSize: Theme.fontSize - 1
                            }
                            SettingRow {
                                text: "Island Style"
                                tip: "Motion style used by bar islands."
                                AppComboBox {
                                    model: animSec.styleLabels
                                    currentIndex: Math.max(0, animSec.styleValues.indexOf(Settings.islandAnimStyle))
                                    onActivated: Settings.islandAnimStyle = animSec.styleValues[index]
                                    Layout.preferredWidth: 160
                                }
                            }
                        }
                    }
                }

                // ============ USER AGENTS ============
                Rectangle {
                    width: parent.width
                    implicitHeight: uaSec.implicitHeight + 20
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
                        id: uaSec
                        anchors.fill: parent
                        anchors.margins: Theme.pad
                        spacing: Theme.spacing
                        Label {
                            text: "User Agents"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }
                        Column {
                            width: parent.width
                            spacing: Theme.spacing
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
                                    height: uaRow.implicitHeight
                                    color: "transparent"

                                    property bool reveal: false

                                    RowLayout {
                                        id: uaRow
                                        width: parent.width
                                        spacing: Theme.spacing
                                        SettingLabel {
                                            text: modelData.label
                                            tip: "Custom User-Agent sent with " + modelData.label + " requests."
                                            Layout.preferredWidth: 90
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
                                            tooltipText: "Show or hide the value"
                                            onClicked: parent.parent.reveal = !parent.parent.reveal
                                        }
                                        AppButton {
                                            text: "copy"
                                            Layout.preferredWidth: 44
                                            Layout.preferredHeight: 24
                                            visible: uaField.text !== ""
                                            tooltipText: "Copy the value to the clipboard"
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
                        id: apiSec
                        anchors.fill: parent
                        anchors.margins: Theme.pad
                        spacing: Theme.spacing
                        Label {
                            text: "API Keys"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }
                        Column {
                            width: parent.width
                            spacing: Theme.spacing
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
                                    height: keyRowLayout.implicitHeight
                                    color: "transparent"
                                    radius: Theme.radius
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
                                            duration: Theme.anim.small
                                            easing.type: Easing.OutCubic
                                        }
                                        NumberAnimation {
                                            target: keyRow
                                            property: "border.width"
                                            from: 2
                                            to: 0
                                            duration: Theme.anim.defaultSpatial
                                            easing.type: Easing.InCubic
                                        }
                                    }

                                    RowLayout {
                                        id: keyRowLayout
                                        width: parent.width
                                        spacing: Theme.spacing
                                        SettingLabel {
                                            text: modelData.label
                                            tip: root.apiKeyTip(modelData.path, modelData.label)
                                            Layout.fillWidth: true
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
                                            tooltipText: "Show or hide the key"
                                            onClicked: parent.parent.reveal = !parent.parent.reveal
                                        }
                                        AppButton {
                                            text: "copy"
                                            Layout.preferredWidth: 44
                                            Layout.preferredHeight: 24
                                            tooltipText: "Copy the key to the clipboard"
                                            onClicked: root.copyText(keyField.text)
                                        }
                                    }
                                }
                            }
                            // ChatBot reply notifications (replies stay in the
                            // tab unless this is on; errors always notify).
                            SettingRow {
                                text: "Notify on chatbot reply"
                                tip: "Pop a notification when the chatbot replies."
                                AppToggle {
                                    checked: Settings.chatBotNotify
                                    onToggled: Settings.chatBotNotify = checked
                                }
                            }
                        }
                    }
                }

                // ============ FILE MANAGER ============
                Rectangle {
                    width: parent.width
                    implicitHeight: fmSec.implicitHeight + 20
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
                        id: fmSec
                        anchors.fill: parent
                        anchors.margins: Theme.pad
                        spacing: Theme.spacing
                        Label {
                            text: "File Manager"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }
                        Column {
                            width: parent.width
                            spacing: Theme.spacing
                            Repeater {
                                id: fmRepeater
                                model: root.fileManagerOptions.length ? root.fileManagerOptions : root.allFileManagers
                                delegate: SettingRow {
                                    text: modelData.name
                                    tip: "Use " + modelData.name + " as the default file manager."
                                    AppToggle {
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
                        id: hyprSec
                        anchors.fill: parent
                        anchors.margins: Theme.pad
                        spacing: Theme.spacing
                        Label {
                            text: "Hyprland"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }
                        Column {
                            width: parent.width
                            spacing: Theme.spacing

                            // Game Mode
                            SettingRow {
                                text: "Game Mode"
                                tip: "Disable blur and animations for performance."
                                AppToggle {
                                    checked: Settings.gameModeEnabled
                                    onToggled: Settings.applyGameMode(checked)
                                }
                            }

                            // Blue light filter (hyprsunset)
                            SettingRow {
                                text: "Blue Light Filter"
                                tip: "Warm tint for eyes via hyprsunset."
                                AppToggle {
                                    checked: Settings.blueLightEnabled
                                    onToggled: Settings.applyBlueLight(checked)
                                }
                            }

                            // Blue light: temperature (Kelvin, lower = warmer)
                            SettingRow {
                                text: "Blue Light: Temperature (K)"
                                tip: "Tint warmth in Kelvin; lower is warmer."
                                AppSpinBox {
                                    from: 1000
                                    to: 6500
                                    stepSize: 100
                                    value: Settings.blueLightTemperature
                                    Layout.preferredWidth: 160
                                    onValueModified: Settings.blueLightTemperature = value
                                }
                            }

                            // Blue light: auto mode — toggle + "from – to" time in ONE row
                            // (the toggle drives the schedule; the times stay editable
                            // when it is off so they can be preset)
                            SettingRow {
                                text: "Blue Light: Auto Mode"
                                tip: "Run the blue-light filter on a schedule."
                                AppToggle {
                                    checked: Settings.blueLightAuto
                                    onToggled: Settings.blueLightAuto = checked
                                }
                                AppTextField {
                                    id: blStartField
                                    Layout.preferredWidth: 64
                                    Layout.preferredHeight: 30
                                    horizontalAlignment: Text.AlignHCenter
                                    leftPadding: 4
                                    rightPadding: 4
                                    maximumLength: 5
                                    inputMethodHints: Qt.ImhPreferNumbers
                                    validator: RegularExpressionValidator {
                                        regularExpression: /^\d{0,2}:?\d{0,2}$/
                                    }
                                    placeholderText: "21:00"
                                    text: Settings.blueLightStart
                                    opacity: Settings.blueLightAuto ? 1 : 0.5
                                    // "7:30" -> "07:30"; invalid input reverts to the saved value
                                    onEditingFinished: {
                                        Settings.blueLightStart = Settings.normalizeTime(text, Settings.blueLightStart);
                                        text = Qt.binding(() => Settings.blueLightStart);
                                    }
                                }
                                Label {
                                    text: "–"
                                    color: Theme.fg
                                    font.pixelSize: Theme.fontSize
                                }
                                AppTextField {
                                    id: blEndField
                                    Layout.preferredWidth: 64
                                    Layout.preferredHeight: 30
                                    horizontalAlignment: Text.AlignHCenter
                                    leftPadding: 4
                                    rightPadding: 4
                                    maximumLength: 5
                                    inputMethodHints: Qt.ImhPreferNumbers
                                    validator: RegularExpressionValidator {
                                        regularExpression: /^\d{0,2}:?\d{0,2}$/
                                    }
                                    placeholderText: "07:00"
                                    text: Settings.blueLightEnd
                                    opacity: Settings.blueLightAuto ? 1 : 0.5
                                    // "7:30" -> "07:30"; invalid input reverts to the saved value
                                    onEditingFinished: {
                                        Settings.blueLightEnd = Settings.normalizeTime(text, Settings.blueLightEnd);
                                        text = Qt.binding(() => Settings.blueLightEnd);
                                    }
                                }
                            }

                            // Blue light: schedule summary (shows wrap-around / typos)
                            Label {
                                width: parent.width
                                visible: Settings.blueLightAuto
                                text: Settings.blueLightHint()
                                wrapMode: Text.WordWrap
                                color: Theme.muted
                                font.pixelSize: Theme.fontSize - 2
                            }

                            // Decoration: Rounding
                            SettingRow {
                                text: "Decoration: Rounding"
                                tip: "Window corner radius in px."
                                labelWidth: 170
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
                                    font.pixelSize: Theme.fontSize
                                    text: root.hyprGet("decoration.rounding")
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // Decoration: Blur Enabled
                            SettingRow {
                                text: "Decoration: Blur Enabled"
                                tip: "Hyprland blur behind windows."
                                AppToggle {
                                    checked: root.hyprGet("decoration.blur.enabled")
                                    onToggled: {
                                        root.hyprSet("decoration.blur.enabled", checked);
                                        root.applyHyprlandSettingLive("decoration.blur.enabled", checked);
                                    }
                                }
                            }
                            // Decoration: Blur Size
                            SettingRow {
                                text: "Decoration: Blur Size"
                                tip: "Hyprland blur radius."
                                labelWidth: 170
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
                                    font.pixelSize: Theme.fontSize
                                    text: root.hyprGet("decoration.blur.size")
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // Decoration: Blur Passes
                            SettingRow {
                                text: "Decoration: Blur Passes"
                                tip: "Hyprland blur quality passes."
                                labelWidth: 170
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
                                    font.pixelSize: Theme.fontSize
                                    text: root.hyprGet("decoration.blur.passes")
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // Decoration: Blur Xray
                            SettingRow {
                                text: "Decoration: Blur Xray"
                                tip: "Blur behind windows even when fullscreen."
                                AppToggle {
                                    checked: root.hyprGet("decoration.blur.xray")
                                    onToggled: {
                                        root.hyprSet("decoration.blur.xray", checked);
                                        root.applyHyprlandSettingLive("decoration.blur.xray", checked);
                                    }
                                }
                            }
                            // Decoration: Shadow Enabled
                            SettingRow {
                                text: "Decoration: Shadow Enabled"
                                tip: "Draw Hyprland window shadows."
                                AppToggle {
                                    checked: root.hyprGet("decoration.shadow.enabled")
                                    onToggled: {
                                        root.hyprSet("decoration.shadow.enabled", checked);
                                        root.applyHyprlandSettingLive("decoration.shadow.enabled", checked);
                                    }
                                }
                            }
                            // Decoration: Shadow Range
                            SettingRow {
                                text: "Decoration: Shadow Range"
                                tip: "Shadow spread distance in px."
                                labelWidth: 170
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
                                    font.pixelSize: Theme.fontSize
                                    text: root.hyprGet("decoration.shadow.range")
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // Decoration: Shadow Render Power
                            SettingRow {
                                text: "Shadow Render Power"
                                tip: "Shadow softness and strength."
                                labelWidth: 170
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
                                    font.pixelSize: Theme.fontSize
                                    text: root.hyprGet("decoration.shadow.render_power")
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // General: Border Size
                            SettingRow {
                                text: "General: Border Size"
                                tip: "Window border thickness in px."
                                labelWidth: 170
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
                                    font.pixelSize: Theme.fontSize
                                    text: root.hyprGet("general.border_size")
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // General: Gaps In
                            SettingRow {
                                text: "General: Gaps In"
                                tip: "Gap between windows in px."
                                labelWidth: 170
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
                                    font.pixelSize: Theme.fontSize
                                    text: root.hyprGet("general.gaps_in")
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // General: Gaps Out
                            SettingRow {
                                text: "General: Gaps Out"
                                tip: "Gap between windows and screen edge."
                                labelWidth: 170
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
                                    font.pixelSize: Theme.fontSize
                                    text: root.hyprGet("general.gaps_out")
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // Decoration: Active Opacity (float)
                            SettingRow {
                                text: "Decoration: Active Opacity"
                                tip: "Opacity of the focused window."
                                labelWidth: 170
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
                                    font.pixelSize: Theme.fontSize
                                    text: Number(root.hyprGet("decoration.active_opacity")).toFixed(2)
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }
                            // Decoration: Inactive Opacity (float)
                            SettingRow {
                                text: "Decoration: Inactive Opacity"
                                tip: "Opacity of unfocused windows."
                                labelWidth: 170
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
                                    font.pixelSize: Theme.fontSize
                                    text: Number(root.hyprGet("decoration.inactive_opacity")).toFixed(2)
                                    Layout.preferredWidth: 30
                                    color: Theme.fgDim
                                }
                            }

                            // Apply / Reset
                            RowLayout {
                                width: parent.width
                                spacing: Theme.spacing
                                AppButton {
                                    text: "Apply Hyprland Settings"
                                    tooltipText: "Write settings to Hyprland and reload."
                                    Layout.fillWidth: true
                                    onClicked: root.applyHyprlandSettings()
                                }
                                AppButton {
                                    text: "Reset to Default"
                                    tooltipText: "Restore all settings to defaults."
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
                        id: lockSec
                        anchors.fill: parent
                        anchors.margins: Theme.pad
                        spacing: Theme.spacing
                        Label {
                            text: "Lockscreen"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.accent
                        }
                        Column {
                            width: parent.width
                            spacing: Theme.spacing
                            SettingRow {
                                text: "Grace Period (seconds)"
                                tip: "Time Esc unlocks without a password."
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
            command: "foot ranger"
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

    // Concise tooltip per API-key row (shown via SettingLabel).
    function apiKeyTip(path, label) {
        switch (path) {
        case "openrouter.user":
            return "Your OpenRouter account name.";
        case "openrouter.key":
            return "Key for chatbot AI models.";
        case "danbooru.user":
            return "Your Danbooru login name.";
        case "danbooru.key":
            return "Key for Danbooru favorites and uploads.";
        case "gelbooru.user":
            return "Your Gelbooru login name.";
        case "gelbooru.key":
            return "Key for Gelbooru favorites.";
        case "safebooru.user":
            return "Your Safebooru login name.";
        case "safebooru.key":
            return "Key for Safebooru favorites.";
        case "wallhaven.key":
            return "Optional key; unlocks NSFW wallpapers.";
        default:
            return "Stored locally; used for " + label + ".";
        }
    }

    function copyText(t) {
        Qt.callLater(function () {
            Quickshell.execDetached(["wl-copy", t]);
        });
    }

    // Write autocolor/autovariant flag into the coloreclipse conf
    // (~/.config/coloreclipse/theme.conf)
    function setThemeFlagInConf(flag, enabled) {
        const confPath = root.themeConfPath;
        const val = enabled ? "true" : "false";
        Qt.callLater(function () {
            Quickshell.execDetached(["bash", "-c", `mkdir -p "$(dirname "${confPath}")"
                  if [[ -f "${confPath}" ]]; then
                  sed -i 's/^${flag}=.*/${flag}=${val}/' "${confPath}"
                  grep -q '^${flag}=' "${confPath}" || printf '%s\\n' '${flag}=${val}' >> "${confPath}"
                else
                  printf '%s\\n' '${flag}=${val}' > "${confPath}"
                fi`]);
        });
    }

    property string themeConfPath: Quickshell.env("HOME") + "/.config/coloreclipse/theme.conf"

    function previewHotZones() {
        Qt.callLater(function () {
            Quickshell.execDetached(["hyprctl", "notify", "3", "3000", "rgb(ff9800)", "Hot zones highlighted"]);
        });
    }

    // Apply single Hyprland setting immediately (live): nested-table lua
    // file per key (`${fullKey}.lua`) + instant
    // `hyprctl eval` (hyprctl keyword is rejected on Lua-parser builds
    // 0.56+: "keyword can't work with non-legacy parsers").
    function applyHyprlandSettingLive(fullKey, value) {
        const keyword = fullKey.replace(/\./g, ":");
        const fileName = fullKey.replace(/\./g, "_");
        const luaConfig = root.buildLuaConfig(keyword, value);
        try {
            Quickshell.execDetached(["bash", "-c", `mkdir -p $HOME/.config/hypr/config/custom && ` + `cat > $HOME/.config/hypr/config/custom/${fileName}.lua <<'EOF'\n${luaConfig}\nEOF\n` + `hyprctl eval '${luaConfig}'`]);
        } catch (e) {
            console.warn("[Settings] apply live:", e);
        }
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
                script += ` && cat > $HOME/.config/hypr/config/custom/${full.replace(/\./g, "_")}.lua <<'EOF'\n${lua}\nEOF\n`;
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
        Settings.leftPanelWidth = 400;
        Settings.rightPanelWidth = 250;
        Settings.leftPanelByMonitor = ({});
        Settings.rightPanelByMonitor = ({});
        Settings.leftPanelHotZone = true;
        Settings.rightPanelHotZone = true;
        Settings.leftPanelHotZoneSize = 5;
        Settings.rightPanelHotZoneSize = 5;
        Settings.dynamicThemeColors = false;
        Settings.dynamicThemeVariants = false;
        Settings.barBlur = true;
        Settings.barBlurSize = 4;
        Settings.barBlurPasses = 4;
        Settings.uiOpacity = 0.618;
        Settings.uiScale = 10;
        Settings.uiFontSize = 12;
        Settings.animationsEnabled = true;
        Settings.animScale = 1.0;
        Settings.islandAnimStyle = "Emphasized";
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
