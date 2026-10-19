import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import qs.widgets.shared

// Fullscreen animated hover preview, scoped to the owning monitor. The empty
// input mask keeps the overlay transparent to pointer events so the tile still
// receives leave events and can dismiss the preview.
PanelWindow {
    id: root

    property string monitorName: ""
    property string source: ""
    readonly property bool isVideo: /\.(mp4|webm|mkv|mov)$/i.test(root.source)
    readonly property bool isGif: /\.gif$/i.test(root.source)

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: -1
    color: "transparent"
    visible: root.source !== ""
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "wallpaper-preview-" + root.monitorName
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    AppVideo {
        anchors.fill: parent
        visible: root.isVideo
        source: root.isVideo ? root.source : ""
        active: root.visible && root.isVideo
        muted: true
        loop: true
        radius: 0
        fillMode: VideoOutput.PreserveAspectCrop
    }

    AnimatedImage {
        anchors.fill: parent
        asynchronous: true
        cache: false
        fillMode: Image.PreserveAspectCrop
        visible: root.isGif
        playing: root.visible && root.isGif
        source: root.isGif ? "file://" + root.source : ""
    }
}
