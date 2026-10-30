import QtQuick
import QtQuick.Controls
import Quickshell.Services.UPower
import qs.theme
import qs.services
import qs.widgets.shared

// Quick-settings body: volume + connectivity left, actions/brightness/power right. Lives in
// ControlCard inside the center pill (the bump grows around it); closes via BarState.deactivate.
Item {
    id: body

    property string monitorName: ""
    readonly property string effectiveMonitor: body.monitorName || Registry.monitorName
    readonly property real monitorBrightness: Brightness.screenFor(body.effectiveMonitor)

    width: 680
    height: contentRow.height

    // ---- dynamic brightness icon (3-level thresholds) ----
    readonly property string brightnessIcon: {
        const bri = body.monitorBrightness;
        if (bri > 0.75)
            return "\u{F00E0}";       // full (󰃠)
        if (bri > 0.5)
            return "\u{F00DF}";        // medium (󰃟)
        return "\u{F00DE}";                        // low (󰃞)
    }

    // DND ping: highlight the DND button ~600ms when a notification arrives while DND is active
    // (AppButton `checked` drives it, so the flag lives here instead of on a Rectangle).
    property bool dndPing: false
    Connections {
        target: Notifications
        function onNotified(notification, monitorName) {
            if (monitorName !== body.effectiveMonitor)
                return;
            if (Settings.notifDnd)
                body.dndPing = true;
            if (dndPingTimer.running)
                dndPingTimer.restart();
            else
                dndPingTimer.start();
        }
    }
    Connections {
        target: Settings
        function onNotifDndChanged() {
            if (!Settings.notifDnd)
                body.dndPing = false;
        }
    }
    Timer {
        id: dndPingTimer
        interval: 600
        onTriggered: body.dndPing = false
    }

    // ---- power profiles (native UPower service; PpdState gates visibility) ----
    // PowerProfiles.profile is reactive + settable; without PPD the section hides (probed at start).
    readonly property int powerIndex: {
        if (PowerProfiles.profile === PowerProfile.Performance)
            return 2;
        if (PowerProfiles.profile === PowerProfile.PowerSaver)
            return 0;
        return 1;
    }
    readonly property string powerLabel: {
        if (PowerProfiles.profile === PowerProfile.Performance)
            return "Performance";
        if (PowerProfiles.profile === PowerProfile.PowerSaver)
            return "Power Saver";
        return "Balanced";
    }
    // True while a slider drag is in progress. ControlCard binds the hover pin's holdOpen: hovered
    // drops while a button is pressed, so a drag would otherwise arm the leave timer.
    readonly property bool adjusting: volSection.adjusting || brightSlider.pressed
    // True while a device ComboBox popup is open: the popup renders in the Overlay, outside the
    // island's HoverHandler, so hovering it reads as "left" and folds the island mid-pick.
    readonly property bool popupOpen: volSection.popupCount > 0

    // ---- content: two columns ----
    // Left: volume + connectivity sections (own files) + brightness + power. Right: action grid.
    Row {
        id: contentRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        // No outer margin: the bar's Theme.islandPad is the only inset
        // between the pill edge and content (this row used to add 16).
        spacing: Theme.spacing

        // ===== Left column: sections =====
        Column {
            id: leftCol
            width: (parent.width - parent.spacing) / 2
            spacing: Theme.spacing

            VolumeSection {
                id: volSection
                width: parent.width
                monitorName: body.effectiveMonitor
            }

            ConnectivitySection {
                width: parent.width
            }

            // ===== Brightness =====
            Column {
                width: parent.width
                spacing: Theme.spacing
                visible: Brightness.hasBacklightFor(body.effectiveMonitor)
                Row {
                    width: parent.width
                    spacing: Theme.spacing
                    Text {
                        text: body.brightnessIcon
                        color: Theme.fg
                        font.family: "JetBrainsMono NFP"
                        font.pixelSize: Theme.fs(1.5)
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        text: "Brightness"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
                AppSlider {
                    id: brightSlider
                    width: parent.width
                    from: 0
                    to: 1
                    stepSize: 0.01
                    value: body.monitorBrightness
                    onMoved: Brightness.setScreen(brightSlider.value, body.effectiveMonitor)
                }
            }

            // ===== Power profile (power-profiles-daemon, native UPower service) =====
            Column {
                width: parent.width
                spacing: Theme.spacing
                visible: PpdState.available
                Row {
                    width: parent.width
                    spacing: Theme.spacing
                    Text {
                        text: "󰓅"
                        color: Theme.fg
                        font.family: "JetBrainsMono NFP"
                        font.pixelSize: Theme.fs(1.5)
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        text: "Power"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        text: body.powerLabel
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                AppSegmentedControl {
                    width: parent.width
                    height: implicitHeight
                    stretchCells: true
                    pixelSize: Theme.fontSize - 1
                    model: [
                        {
                            value: PowerProfile.PowerSaver,
                            label: "Power Saver",
                            tooltip: "Limit performance to save power"
                        },
                        {
                            value: PowerProfile.Balanced,
                            label: "Balanced",
                            tooltip: "Balance performance and power"
                        },
                        {
                            value: PowerProfile.Performance,
                            label: "Performance",
                            tooltip: PowerProfiles.hasPerformanceProfile ? "Maximize performance" : "Performance not available on this system",
                            enabled: PowerProfiles.hasPerformanceProfile
                        }
                    ]
                    currentIndex: body.powerIndex
                    onActivated: (i, v) => PowerProfiles.profile = v
                }
            }
        }

        // ===== Right column: action grid =====
        Column {
            id: rightCol
            width: (parent.width - parent.spacing) / 2
            spacing: Theme.spacing

            // ===== Action buttons (shared AppButton cells, 2x2) =====
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: Theme.spacing
                rowSpacing: Theme.spacing
                // Theme toggle
                AppButton {
                    width: (parent.width - parent.columnSpacing) / 2
                    height: 46
                    cornerRadius: Theme.radius
                    idleBg: Theme.surface
                    icon: GlobalTheme.currentTheme ? "\uf185" : "\uf186"
                    pixelSize: Theme.fontSize + 2
                    tooltipText: GlobalTheme.currentTheme ? "Switch to Light Theme" : "Switch to Dark Theme"
                    onClicked: GlobalTheme.setTheme(!GlobalTheme.currentTheme)
                }
                // DND toggle
                AppButton {
                    width: (parent.width - parent.columnSpacing) / 2
                    height: 46
                    cornerRadius: Theme.radius
                    idleBg: Theme.surface
                    icon: Settings.notifDnd ? "\uf1f6" : "\uf0f3"
                    pixelSize: Theme.fontSize + 2
                    toggle: true
                    checked: Settings.notifDnd || body.dndPing
                    tooltipText: Settings.notifDnd ? "Disable Do Not Disturb" : "Enable Do Not Disturb"
                    onClicked: Settings.updateSetting("notifications.dnd", !Settings.notifDnd)
                }
                // Game Mode: always applies the Hyprland preset; gamemoded and
                // powerprofilesctl are optional integrations.
                AppButton {
                    width: (parent.width - parent.columnSpacing) / 2
                    height: 46
                    cornerRadius: Theme.radius
                    idleBg: Theme.surface
                    icon: "\u{F11B}"
                    pixelSize: Theme.fontSize + 2
                    toggle: true
                    checked: Settings.gameModeEnabled
                    tooltipText: Settings.gameModeEnabled ? "Disable Game Mode" : "Enable Game Mode"
                    onClicked: Settings.applyGameMode(!Settings.gameModeEnabled)
                }
                // Blue light filter (hyprsunset). Temperature lives in
                // Settings.blueLightTemperature (settings key blueLight.temperature).
                AppButton {
                    width: (parent.width - parent.columnSpacing) / 2
                    height: 46
                    cornerRadius: Theme.radius
                    idleBg: Theme.surface
                    icon: "\uf0eb"
                    pixelSize: Theme.fontSize + 2
                    toggle: true
                    checked: Settings.blueLightEnabled
                    tooltipText: (Settings.blueLightEnabled ? "Disable Blue Light Filter" : "Enable Blue Light Filter (" + Settings.blueLightTemperature + "K)")
                        + (Settings.blueLightAuto ? "\nAuto: " + Settings.blueLightStart + " \u2013 " + Settings.blueLightEnd : "")
                    onClicked: Settings.applyBlueLight(!Settings.blueLightEnabled)
                }
                // Keyboard layout — shows the current layout code, click cycles
                AppButton {
                    width: (parent.width - parent.columnSpacing) / 2
                    height: 46
                    cornerRadius: Theme.radius
                    idleBg: Theme.surface
                    text: KeyboardLayout.layout
                    visible: KeyboardLayout.layout !== ""
                    pixelSize: Theme.fontSize + 2
                    tooltipText: (KeyboardLayout.layoutName || "Keyboard Layout") + "\nClick to switch layout"
                    onClicked: KeyboardLayout.nextLayout()
                }
            }
        }
    }
}
