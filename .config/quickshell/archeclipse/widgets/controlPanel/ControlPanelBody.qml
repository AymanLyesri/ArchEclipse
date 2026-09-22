import QtQuick
import QtQuick.Controls
import Quickshell.Services.UPower
import qs.theme
import qs.services
import qs.widgets.shared

// Quick-settings body: two columns — left holds the volume + connectivity
// sections (own files in this dir), right holds the action grid,
// brightness slider and power profile selector. Lives in the bar's dynamic
// island (ControlIsland) instead of a side window.
// Close behavior = BarState.deactivate("control").
Item {
    id: body

    property string monitorName: ""
    readonly property string effectiveMonitor: body.monitorName || Registry.monitorName

    width: 680
    height: contentRow.height + 32

    // ---- dynamic brightness icon (3-level thresholds) ----
    readonly property string brightnessIcon: {
        const bri = Brightness.screen;
        if (bri > 0.75)
            return "\u{F00E0}";       // full (󰃠)
        if (bri > 0.5)
            return "\u{F00DF}";        // medium (󰃟)
        return "\u{F00DE}";                        // low (󰃞)
    }

    // DND ping state: highlight the DND button ~600ms when a
    // notification arrives while DND is active (AppButton `checked` drives
    // the highlight, so the flag lives here instead of on a Rectangle).
    property bool dndPing: false
    Connections {
        target: Notifications
        function onNotified() {
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
    // PowerProfiles.profile is reactive + settable, so no polling needed for
    // the value itself. PpdState probes `powerprofilesctl get` once at
    // quickshell start — without PPD the section hides instead of showing
    // a dead control (e.g. PPD-less desktops).
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
    // True while the user is dragging a slider. ControlIsland binds the
    // hover-pin's holdOpen to this: HoverHandler.hovered drops while a button
    // is pressed, so a drag would otherwise read as "left" and arm the leave
    // timer mid-adjustment.
    readonly property bool adjusting: volSection.adjusting || brightSlider.pressed
    // True while a device ComboBox popup is open. The popup renders in the
    // Overlay (outside the island's HoverHandler bounds), so hovering its
    // options reads as "left" — without this the leave timer fires and the
    // whole island folds while the user is picking a device.
    readonly property bool popupOpen: volSection.popupCount > 0

    // ---- content: two columns ----
    // Left: volume + connectivity sections (own files).
    // Right: action grid + brightness + power profile.
    Row {
        id: contentRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 16

        // ===== Left column: sections =====
        Column {
            id: leftCol
            width: (parent.width - parent.spacing) / 2
            spacing: 16

            VolumeSection {
                id: volSection
                width: parent.width
            }

            ConnectivitySection {
                width: parent.width
            }
        }

        // ===== Right column: actions + brightness + power =====
        Column {
            id: rightCol
            width: (parent.width - parent.spacing) / 2
            spacing: 16

            // ===== Action buttons (shared AppButton cells, 2x2) =====
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 10
                rowSpacing: 10
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

            // ===== Brightness =====
            Column {
                width: parent.width
                spacing: 6
                visible: Brightness.hasBacklight
                Row {
                    width: parent.width
                    spacing: 8
                    Text {
                        text: body.brightnessIcon
                        color: Theme.fg
                        font.family: "JetBrainsMono NFP"
                        font.pixelSize: 18
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
                    value: Brightness.screen
                    onMoved: Brightness.setScreen(brightSlider.value)
                }
            }

            // ===== Power profile (power-profiles-daemon, native UPower service) =====
            Column {
                width: parent.width
                spacing: 6
                visible: PpdState.available
                Row {
                    width: parent.width
                    spacing: 8
                    Text {
                        text: "󰓅"
                        color: Theme.fg
                        font.family: "JetBrainsMono NFP"
                        font.pixelSize: 18
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
    }
}
