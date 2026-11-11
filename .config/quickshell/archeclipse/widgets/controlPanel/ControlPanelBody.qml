import QtQuick
import QtQuick.Controls
import Quickshell.Services.UPower
import qs.theme
import qs.services
import qs.widgets.shared

// Quick-settings body. Layout reads top-down on one rhythm: live sections (volume beside
// connectivity), then a single labelled strip of quick actions, then the two system sliders side
// by side. No dividers: groups are separated by space, and every block sits on the same plate.
Item {
    id: body

    property string monitorName: ""
    readonly property string effectiveMonitor: body.monitorName || Registry.monitorName
    readonly property real monitorBrightness: Brightness.screenFor(body.effectiveMonitor)

    width: 700
    height: mainCol.height

    // ---- dynamic brightness icon (3-level thresholds) ----
    readonly property string brightnessIcon: {
        const bri = body.monitorBrightness;
        if (bri > 0.75)
            return Icons.brightnessHigh;
        if (bri > 0.5)
            return Icons.brightnessMedium;
        return Icons.brightnessLow;
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

    component GroupLabel: Text {
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeCaption
        font.weight: Font.DemiBold
        font.letterSpacing: 1.1
        color: Theme.muted
    }

    readonly property int actionCount: KeyboardLayout.layout !== "" ? 5 : 4
    readonly property real actionWidth: (parent ? body.width - Theme.spaceSm * (body.actionCount - 1) : 0) / body.actionCount

    Column {
        id: mainCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.spaceMd

        // ===== Live sections: the two things you check, side by side =====
        Row {
            id: sectionRow
            width: parent.width
            spacing: Theme.spaceMd

            VolumeSection {
                id: volSection
                width: Math.round((parent.width - parent.spacing) * 0.56)
                monitorName: body.effectiveMonitor
            }

            ConnectivitySection {
                width: parent.width - volSection.width - sectionRow.spacing
            }
        }

        // ===== Quick actions: one strip, labelled, icon + label per tile =====
        Column {
            width: parent.width
            spacing: Theme.spaceSm

            GroupLabel {
                text: "QUICK ACTIONS"
            }

            Row {
                width: parent.width
                spacing: Theme.spaceSm

                AppButton {
                    width: body.actionWidth
                    height: 46
                    cornerRadius: Theme.radius
                    idleBg: Theme.surfaceRaised
                    hoverBg: Theme.surfaceOverlay
                    icon: GlobalTheme.currentTheme ? Icons.sun : Icons.moon
                    text: "Theme"
                    pixelSize: Theme.typeLabel
                    contentSpacing: Theme.spaceSm
                    tooltipText: GlobalTheme.currentTheme ? "Switch to Light Theme" : "Switch to Dark Theme"
                    onClicked: GlobalTheme.setTheme(!GlobalTheme.currentTheme)
                }
                AppButton {
                    width: body.actionWidth
                    height: 46
                    cornerRadius: Theme.radius
                    idleBg: Theme.surfaceRaised
                    hoverBg: Theme.surfaceOverlay
                    icon: Settings.notifDnd ? Icons.bellOff : Icons.bell
                    text: "DND"
                    pixelSize: Theme.typeLabel
                    contentSpacing: Theme.spaceSm
                    toggle: true
                    checked: Settings.notifDnd || body.dndPing
                    tooltipText: Settings.notifDnd ? "Disable Do Not Disturb" : "Enable Do Not Disturb"
                    onClicked: Settings.updateSetting("notifications.dnd", !Settings.notifDnd)
                }
                // Game Mode: always applies the Hyprland preset; gamemoded and
                // powerprofilesctl are optional integrations.
                AppButton {
                    width: body.actionWidth
                    height: 46
                    cornerRadius: Theme.radius
                    idleBg: Theme.surfaceRaised
                    hoverBg: Theme.surfaceOverlay
                    icon: Icons.game
                    text: "Game"
                    pixelSize: Theme.typeLabel
                    contentSpacing: Theme.spaceSm
                    toggle: true
                    checked: Settings.gameModeEnabled
                    tooltipText: Settings.gameModeEnabled ? "Disable Game Mode" : "Enable Game Mode"
                    onClicked: Settings.applyGameMode(!Settings.gameModeEnabled)
                }
                // Blue light filter (hyprsunset). Temperature lives in
                // Settings.blueLightTemperature (settings key blueLight.temperature).
                AppButton {
                    width: body.actionWidth
                    height: 46
                    cornerRadius: Theme.radius
                    idleBg: Theme.surfaceRaised
                    hoverBg: Theme.surfaceOverlay
                    icon: Icons.lightbulb
                    text: "Night"
                    pixelSize: Theme.typeLabel
                    contentSpacing: Theme.spaceSm
                    toggle: true
                    checked: Settings.blueLightEnabled
                    tooltipText: (Settings.blueLightEnabled ? "Disable Blue Light Filter" : "Enable Blue Light Filter (" + Settings.blueLightTemperature + "K)")
                        + (Settings.blueLightAuto ? "\nAuto: " + Settings.blueLightStart + " \u2013 " + Settings.blueLightEnd : "")
                    onClicked: Settings.applyBlueLight(!Settings.blueLightEnabled)
                }
                // Keyboard layout — shows the current layout code, click cycles.
                AppButton {
                    width: body.actionWidth
                    height: 46
                    cornerRadius: Theme.radius
                    idleBg: Theme.surfaceRaised
                    hoverBg: Theme.surfaceOverlay
                    icon: Icons.keyboard
                    text: KeyboardLayout.layout
                    visible: KeyboardLayout.layout !== ""
                    pixelSize: Theme.typeLabel
                    contentSpacing: Theme.spaceSm
                    tooltipText: (KeyboardLayout.layoutName || "Keyboard Layout") + "\nClick to switch layout"
                    onClicked: KeyboardLayout.nextLayout()
                }
            }
        }

        // ===== System: display and power are peers, one card each =====
        Row {
            width: parent.width
            spacing: Theme.spaceMd

            Card {
                id: brightCard
                width: parent.width - (powerCard.visible ? powerCard.width + parent.spacing : 0)
                height: contentMargins * 2 + brightRow.height + contentSpacing + brightSlider.height
                contentMargins: Theme.pad
                contentSpacing: Theme.spaceSm

                Row {
                    id: brightRow
                    width: parent.width
                    spacing: Theme.spaceSm
                    Text {
                        text: body.brightnessIcon
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.typeSubtitle
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        text: "Brightness"
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.typeLabel
                        verticalAlignment: Text.AlignVCenter
                    }
                    Item {
                        width: Math.max(0, parent.width - 150)
                        height: 1
                    }
                    Text {
                        text: Math.round(body.monitorBrightness * 100) + "%"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.typeSubtitle
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                        font.preferShaping: false
                    }
                }
                AppSlider {
                    id: brightSlider
                    width: parent.width
                    from: 0
                    to: 1
                    stepSize: 0.01
                    // Full brightness is the reset point for the panel's display control.
                    defaultValue: 1.0
                    value: body.monitorBrightness
                    visible: Brightness.hasBacklightFor(body.effectiveMonitor)
                    onMoved: Brightness.setScreen(brightSlider.value, body.effectiveMonitor)
                }
            }

            // Power profile (power-profiles-daemon, native UPower service)
            Card {
                id: powerCard
                width: Math.round((parent.width - parent.spacing) * 0.44)
                height: contentMargins * 2 + powerRow.height + contentSpacing + powerSegment.height
                contentMargins: Theme.pad
                contentSpacing: Theme.spaceSm
                visible: PpdState.available

                Row {
                    id: powerRow
                    width: parent.width
                    spacing: Theme.spaceSm
                    Text {
                        text: Icons.speed
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.typeSubtitle
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        text: "Power"
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.typeLabel
                        verticalAlignment: Text.AlignVCenter
                    }
                    Item {
                        width: Math.max(0, parent.width - 150)
                        height: 1
                    }
                    Text {
                        text: body.powerLabel
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.typeLabel
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                AppSegmentedControl {
                    id: powerSegment
                    width: parent.width
                    height: implicitHeight
                    stretchCells: true
                    pixelSize: Theme.typeLabel
                    model: [
                        {
                            value: PowerProfile.PowerSaver,
                            label: "Saver",
                            tooltip: "Limit performance to save power"
                        },
                        {
                            value: PowerProfile.Balanced,
                            label: "Balanced",
                            tooltip: "Balance performance and power"
                        },
                        {
                            value: PowerProfile.Performance,
                            label: "Perf",
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
