import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme
import qs.services

// MediaWindow — standalone player control window (SUPER+m), toggled per monitor via
// `qs ipc call bar togglePanel media-panel <monitor>`.
PanelWindow {
    id: root

    // `screen` is the inherited QsWindow property — do not redeclare it
    // (see Bar.qml); a shadow would leave the surface on one output.
    readonly property string monitorName: Hyprland.monitorFor(screen)?.name ?? screen?.name ?? ""

    // Top, full-width layer surface on the overlay layer (no exclusive zone, on-demand keyboard
    // focus); layer-shell has no horizontalCenter anchor, so the inner pill is centered by hand.
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
    Component.onDestruction: Registry.unregister(`media-panel-${monitorName}`)

    Rectangle {
        id: mediaRect
        width: 420
        // Closed lyrics keep the original 240px card; open lyrics grow it.
        height: Math.max(240, media.implicitHeight + 24)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.margins: Theme.pad
        color: Theme.bg
        radius: Theme.radius

        border.color: Theme.border

        MediaWidget {
            id: media
            anchors.fill: parent
            anchors.margins: Theme.pad
        }
    }
}
