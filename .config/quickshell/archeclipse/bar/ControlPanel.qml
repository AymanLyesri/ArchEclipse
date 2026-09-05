import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import qs.theme
import qs.services

// Port of ControlPanel.tsx — the vertical quick-settings sidebar:
//   [ Volume slider (dynamic icon) ]
//   [ Brightness slider (dynamic icon) ]
//   [ Theme | DND | UserPanel | AppLauncher | WallpaperSwitcher ]
// Toggled by the ControlPanelButton in the utilities row / expanded bar.
// All action buttons have tooltips with keyboard shortcuts (matching AGS).
PanelWindow {
    id: root

    required property ShellScreen screen
    anchors { top: true; bottom: true; right: true }
    exclusiveZone: -1
    visible: false
    aboveWindows: true
    implicitWidth: 300

    color: Theme.backgroundTransparent

    property string monitorName: (Hyprland.monitorFor(screen)?.name) ?? ""
    Component.onCompleted: Registry.register(`control-panel-${monitorName}`, root)
    Component.onDestruction: Registry.unregister(`control-panel-${monitorName}`)

    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ---- default sink for the volume slider ----
    readonly property PwNode controlSink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [controlSink] }

    // ---- dynamic volume icon (matches AGS AstalWp volumeIcon behavior) ----
    readonly property string volumeIcon: {
        const vol = controlSink?.audio?.volume ?? 0;
        if (vol <= 0) return "\u{F0456}";          // muted (󰑖)
        if (vol < 0.33) return "\u{F0458}";       // low (󰑘)
        if (vol < 0.66) return "\u{F0457}";       // medium (󰑗)
        return "\u{F0459}";                        // high (󰑙)
    }

    // ---- dynamic brightness icon (matches AGS 3-level thresholds) ----
    readonly property string brightnessIcon: {
        const bri = Brightness.screen;
        if (bri > 0.75) return "\u{F00E0}";       // full (󰃠)
        if (bri > 0.5) return "\u{F00DF}";        // medium (󰃟)
        return "\u{F00DE}";                        // low (󰃞)
    }

    // ---- esc dismiss ----
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.visible = false
    }

    // ---- content ----
    Column {
        width: parent.width
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // ===== Volume =====
        Column { width: parent.width; spacing: 6
            Row { width: parent.width; spacing: 8
                Text { text: root.volumeIcon; color: Theme.foreground; font.family: "JetBrainsMono NFP"; font.pixelSize: 18; verticalAlignment: Text.AlignVCenter }
                Text { text: "Volume"; color: Theme.foregroundSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
            }
            Slider {
                id: volSlider; width: parent.width
                from: 0; to: 1; stepSize: 0.01
                value: root.controlSink?.audio?.volume ?? 0
                onMoved: if (root.controlSink?.audio) root.controlSink.audio.volume = volSlider.value
            }
        }

        // ===== Brightness =====
        Column { width: parent.width; spacing: 6; visible: Brightness.hasBacklight
            Row { width: parent.width; spacing: 8
                Text { text: root.brightnessIcon; color: Theme.foreground; font.family: "JetBrainsMono NFP"; font.pixelSize: 18; verticalAlignment: Text.AlignVCenter }
                Text { text: "Brightness"; color: Theme.foregroundSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
            }
            Slider {
                id: brightSlider; width: parent.width
                from: 0; to: 1; stepSize: 0.01
                value: Brightness.screen
                onMoved: Brightness.setScreen(brightSlider.value)
            }
        }

        // ===== Action buttons =====
        Row { width: parent.width; spacing: 10
            // Theme toggle
            Rectangle { width: 46; height: 46; radius: Theme.radius
                color: tm.containsMouse ? Theme.buttonHoverBg : Theme.moduleBg
                ToolTip.visible: tm.containsMouse
                ToolTip.text: GlobalTheme.currentTheme ? "Switch to Light Theme" : "Switch to Dark Theme"
                ToolTip.delay: 600
                Text { anchors.centerIn: parent; text: GlobalTheme.currentTheme ? "\u{F07C5}" : "\u{F0D9C}"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 2 }
                MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: GlobalTheme.setTheme(!GlobalTheme.currentTheme) }
            }
            // DND toggle
            Rectangle { id: dndBtn; width: 46; height: 46; radius: Theme.radius
                color: (dndM.containsMouse || Settings.notifDnd || dndPing) ? Theme.buttonCheckedBg : Theme.moduleBg
                ToolTip.visible: dndM.containsMouse
                ToolTip.text: Settings.notifDnd ? "Enable Do Not Disturb" : "Disable Do Not Disturb"
                ToolTip.delay: 600
                Text { anchors.centerIn: parent; text: Settings.notifDnd ? "\u{F0436}" : "\u{F044E}"; color: Settings.notifDnd ? Theme.buttonCheckedFg : Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 2 }
                MouseArea { id: dndM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.notifDnd = !Settings.notifDnd }
                // AGS DndToggle: ping the button ~600ms when a notification
                // arrives while DND is active, reset when DND turns off
                property bool dndPing: false
                Connections {
                    target: Notifications
                    function onNotified() {
                        if (Settings.notifDnd) dndBtn.dndPing = true
                        if (dndPingTimer.running) dndPingTimer.restart()
                        else dndPingTimer.start()
                    }
                }
                Connections {
                    target: Settings
                    function onNotifDndChanged() { if (!Settings.notifDnd) dndBtn.dndPing = false }
                }
                Timer { id: dndPingTimer; interval: 600; onTriggered: dndBtn.dndPing = false }
            }
            // UserPanel (SUPER+ESC)
            Rectangle { width: 46; height: 46; radius: Theme.radius
                color: upM.containsMouse ? Theme.buttonHoverBg : Theme.moduleBg
                ToolTip.visible: upM.containsMouse
                ToolTip.text: "User Panel\n<b>SUPER + ESC</b>"
                ToolTip.delay: 600
                Text { anchors.centerIn: parent; text: "\u{F058C}"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 2 }
                MouseArea { id: upM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.visible = false; Registry.toggle(`user-panel-${root.monitorName}`) } }
            }
            // AppLauncher (SUPER)
            Rectangle { width: 46; height: 46; radius: Theme.radius
                color: alM.containsMouse ? Theme.buttonHoverBg : Theme.moduleBg
                ToolTip.visible: alM.containsMouse
                ToolTip.text: "App Launcher\n<b>SUPER</b>"
                ToolTip.delay: 600
                Text { anchors.centerIn: parent; text: "\u{F0580}"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 2 }
                MouseArea { id: alM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.visible = false; BarState.activate("search", 0) } }
            }
            // WallpaperSwitcher (SUPER+W)
            Rectangle { width: 46; height: 46; radius: Theme.radius
                color: wsM.containsMouse ? Theme.buttonHoverBg : Theme.moduleBg
                ToolTip.visible: wsM.containsMouse
                ToolTip.text: "Wallpaper Switcher\n<b>SUPER + W</b>"
                ToolTip.delay: 600
                Text { anchors.centerIn: parent; text: "\u{F0F82}"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 2 }
                MouseArea { id: wsM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.visible = false; Registry.toggle(`wallpaper-switcher-${root.monitorName}`) } }
            }
        }
    }
}
