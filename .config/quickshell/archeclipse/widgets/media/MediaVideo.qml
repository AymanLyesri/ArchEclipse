import QtQuick
import QtMultimedia
import Quickshell.Widgets
import qs.theme

// MediaVideo — video player widget.
// autoplay=true, loop=true, fills the parent (hexpand/vexpand), with a
// destroy-time teardown that releases the media source (mirrors the old
// gst teardown on unrealize to avoid GL-context crashes on re-init).
//
// NOTE: deliberately NOT a wrapper over AppVideo (see widgets/shared).
// (Historical note kept: an early ClippingRectangle root was blamed for
// a thin dark frame around dialog videos; the -2 overscan below exists
// to swallow exactly that fringe, and the AppVideo twin — same root +
// overscan — ships frame-free in the wallpaper tiles. Plain-Item hosts
// only scissor-clip rectangularly, so a plain root leaves video corners
// square against rounded cards: hence the rounded root here.)
// Lifecycle fixes belong in both files until they can share an Item root.
ClippingRectangle {
    id: root

    radius: Theme.radius
    color: "transparent"

    property string source: ""      // local file path (Gio.File.new_for_path equivalent)
    property bool autoplay: true
    property bool loop: true
    property bool fill: true        // if false, letterbox (preserve aspect)
    // Exposed so hosts can keep a poster still underneath until the
    // first frame arrives (otherwise the card is blank during load
    // and permanently blank when the decode fails).
    readonly property bool hasVideo: player.hasVideo
    // Presentation gate: dialogs live inside windows that are often
    // hidden (docked popup, undetached float) while their own `visible`
    // stays true — without this every dialog instance decodes the same
    // file concurrently (triple unmuted audio → stalls). Hosts bind it
    // to their actual window/panel visibility (AppVideo `active` parity).
    property bool active: visible

    MediaPlayer {
        id: player
        // Gate the source on visibility: VideoOutput.visible alone does NOT
        // stop decoding — a hidden player fed an image (e.g. WaifuWidget's
        // png with visible:false) loops ffmpeg errors thousands of times
        // per second, filling /run/user/1000 and killing IPC/panels.
        source: (root.active && root.visible && root.source !== "") ? "file://" + root.source : ""
        audioOutput: AudioOutput {}
        videoOutput: videoOut
        loops: root.loop ? MediaPlayer.Infinite : 1
        autoPlay: root.autoplay && root.active && root.visible
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
        if (!visible) {
            _playTimer.stop();
            player.stop();
        } else if (root.autoplay && root.active && root.source !== "") {
            root._kickPlayback();
        }
    }
    // Deactivation (presentation gate above) behaves like hiding, with a
    // retried startup: a single deferred play() races the source binding
    // (lands while player.source is still "" → silent no-op → loaded but
    // never playing), so retry until Playing (AppVideo `_kickPlayback`
    // parity — lifecycle fixes belong in both files).
    onActiveChanged: {
        if (!root.active) {
            _playTimer.stop();
            player.stop();
        } else if (root.autoplay && root.source !== "") {
            root._kickPlayback();
        }
    }
    // A direct file→file switch while visible can stall the backend:
    // player.source changes but hasVideo never re-fires and no error
    // surfaces — the card stays blank (seen in probes: reopening an
    // already-downloaded mp4 straight from another video). Bounce
    // through stop() + deferred play() so the new file loads like a
    // fresh one (source "" reset always worked).
    onSourceChanged: {
        if (!root.active || !root.visible || root.source === "")
            return;
        player.stop();
        root._kickPlayback();
    }
    property int _playAttempts: 0
    function _kickPlayback() {
        root._playAttempts = 0;
        _playTimer.restart();
    }
    Timer {
        id: _playTimer
        interval: 120
        repeat: true
        onTriggered: {
            if (!root.active || !root.visible || root.source === "" || player.source === "") {
                if (++root._playAttempts > 25)
                    stop();
                return;
            }
            if (player.playbackState === MediaPlayer.PlayingState) {
                stop();
                return;
            }
            player.play();
            if (++root._playAttempts > 25)
                stop();
        }
    }
    Component.onDestruction: {
        player.stop()
        player.source = ""
    }
}
