import QtQuick
import QtMultimedia

// MediaVideo — QML port of AGS widgets/Video.tsx (Gtk.Video).
// autoplay=true, loop=true, fills the parent (hexpand/vexpand), with a
// destroy-time teardown that releases the media source (mirrors AGS's
// gst teardown on unrealize to avoid GL-context crashes on re-init).
Item {
    id: root

    property string source: ""      // local file path (Gio.File.new_for_path equivalent)
    property bool autoplay: true
    property bool loop: true
    property bool fill: true        // if false, letterbox (preserve aspect)

    MediaPlayer {
        id: player
        source: root.source !== "" ? "file://" + root.source : ""
        audioOutput: AudioOutput {}
        videoOutput: videoOut
        loops: root.loop ? MediaPlayer.Infinite : 1
        autoPlay: root.autoplay
    }

    VideoOutput {
        id: videoOut
        anchors.fill: parent
        fillMode: root.fill ? VideoOutput.Stretch : VideoOutput.PreserveAspectFit
        visible: root.source !== "" && player.hasVideo
    }

    // AGS Video.tsx teardown: pause + release the stream when the widget
    // leaves the screen (prevents the GStreamer GL context crash on re-init).
    onVisibleChanged: {
        if (!visible) player.pause()
    }
    Component.onDestruction: {
        player.stop()
        player.source = ""
    }
}
