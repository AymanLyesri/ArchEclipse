import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.services
import qs.bar

// Port of UserPanel.tsx — full-screen overlay power grid:
// Logout | Shutdown / Sleep | Reboot, Esc closes.
// Center overlay shows UserProfileWidget { minimal: true } (AGS UserProfileMinimal).
PanelWindow {
    id: root

    required property ShellScreen screen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: Qt.rgba(0, 0, 0, 0.6)
    aboveWindows: true
    visible: false

    property string monitorName: (Hyprland.monitorFor(screen)?.name) ?? ""
    Component.onCompleted: Registry.register(`user-panel-${monitorName}`, root)
    Component.onDestruction: Registry.unregister(`user-panel-${monitorName}`)

    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.visible = false
    }

    Component {
        id: actionButton
        Rectangle {
            property string glyph: ""
            property string tip: ""
            property var onAct: null
            width: 150; height: 150; radius: Theme.radius
            color: ma.containsMouse ? Theme.buttonCheckedBg : Theme.moduleBg
            Behavior on color { ColorAnimation { duration: 150 } }
            Text {
                anchors.centerIn: parent
                text: parent.glyph
                color: ma.containsMouse ? Theme.buttonCheckedFg : Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 42
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (parent.onAct) parent.onAct() }
        }
    }

    // Center: minimal user profile overlay (AGS <UserProfileMinimal /> in overlay)
    UserProfileWidget {
        id: centerProfile
        anchors.centerIn: parent
        minimal: true
    }

    Grid {
        anchors.centerIn: parent
        columns: 2
        rows: 2
        spacing: 20

        Loader { sourceComponent: actionButton; onLoaded: { item.glyph = "\u{F087B}"; item.tip = "logout"; item.onAct = () => Hyprland.dispatch("hl.dsp.exit()") } }
        Loader { sourceComponent: actionButton; onLoaded: { item.glyph = "\u{F0425}"; item.tip = "shutdown"; item.onAct = () => Quickshell.execDetached(["shutdown", "now"]) } }
        Loader { sourceComponent: actionButton; onLoaded: { item.glyph = "\u{F0923}"; item.tip = "sleep"; item.onAct = () => { root.visible = false; Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/hyprlock.sh suspend"]) } } }
        Loader { sourceComponent: actionButton; onLoaded: { item.glyph = "\u{F0709}"; item.tip = "reboot"; item.onAct = () => Quickshell.execDetached(["reboot"]) } }
    }
}
