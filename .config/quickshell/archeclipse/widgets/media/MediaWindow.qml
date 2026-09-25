import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.services

// MediaWindow — standalone player control window (SUPER+m).
// Standalone toggleable player window (media-<monitor>).
// Toggled via IPC (`qs ipc call bar togglePanel media-panel <monitor>`).
PanelWindow {
    id: root

    required property ShellScreen screen
    readonly property string monitorName: Hyprland.monitorFor(screen)?.name ?? ""

    // Top-center floating panel (overlay layer,
    // no exclusive zone, on-demand keyboard focus).
    // Top, full-width layer surface; content pill centered horizontally
    // (layer-shell has no horizontalCenter anchor, so center the inner rect).
    anchors {
        top: true
        left: true
        right: true
    }
    exclusiveZone: -1
    implicitHeight: mediaRect.height + 24
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "media-" + monitorName
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Component.onCompleted: Registry.register(`media-panel-${monitorName}`, root)

    Rectangle {
        id: mediaRect
        width: 420
        // Closed lyrics keep the original 240px card; open lyrics grow it.
        height: Math.max(240, media.implicitHeight + 24)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.margins: 12
        color: Theme.bg
        radius: 12

        border.color: Theme.border

        MediaWidget {
            id: media
            anchors.fill: parent
            anchors.margins: 12
        }
    }
}
