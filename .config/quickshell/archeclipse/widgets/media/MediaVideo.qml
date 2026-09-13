import QtQuick
import QtMultimedia

// MediaVideo — video player widget.
// autoplay=true, loop=true, fills the parent (hexpand/vexpand), with a
// destroy-time teardown that releases the media source (mirrors the old
// gst teardown on unrealize to avoid GL-context crashes on re-init).
//
// NOTE: deliberately NOT a wrapper over AppVideo (see widgets/shared).
// AppVideo's ClippingRectangle root puts the video through a clip-shader
// layer that left a thin dark frame around dialog videos; a plain Item
// renders edge-to-edge here (the hosts clip/round it themselves).
// Lifecycle fixes belong in both files until they can share an Item root.
Item {
    id: root

    property string source: ""      // local file path (Gio.File.new_for_path equivalent)
    property bool autoplay: true
    property bool loop: true
    property bool fill: true        // if false, letterbox (preserve aspect)

    MediaPlayer {
        id: player
        // Gate the source on visibility: VideoOutput.visible alone does NOT
        // stop decoding — a hidden player fed an image (e.g. WaifuWidget's
        // png with visible:false) loops ffmpeg errors thousands of times
        // per second, filling /run/user/1000 and killing IPC/panels.
        source: (root.visible && root.source !== "") ? "file://" + root.source : ""
        audioOutput: AudioOutput {}
        videoOutput: videoOut
        loops: root.loop ? MediaPlayer.Infinite : 1
        autoPlay: root.autoplay && root.visible
    }

    VideoOutput {
        id: videoOut
        anchors.fill: parent
        // Overscan: scaled video often carries a 1px dark fringe (odd
        // dimensions padded for YUV 4:2:0, edge-texel filtering) — render
        // 2px past the viewport and let the host clip it away. Hosts
        // (dialogMedia, waifu mediaContainer) all clip, so nothing bleeds.
        anchors.margins: -2
        fillMode: root.fill ? VideoOutput.Stretch : VideoOutput.PreserveAspectFit
        visible: root.source !== "" && player.hasVideo
    }

    // Teardown: pause + release the stream when the widget
    // leaves the screen (prevents the GStreamer GL context crash on re-init).
    // Stop (not just pause) so a re-shown item rebinds a fresh source
    // instead of resuming a failed decode loop.
    onVisibleChanged: {
        if (!visible)
            player.stop();
        else if (root.autoplay && root.source !== "")
            player.play();
    }
    Component.onDestruction: {
        player.stop()
        player.source = ""
    }
}
