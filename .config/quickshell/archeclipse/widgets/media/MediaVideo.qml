import QtQuick
import QtMultimedia
import Quickshell.Widgets
import qs.theme

// MediaVideo — autoplay/loop player with destroy-time teardown that releases the source (else
// the GL context crashes on re-init). Deliberately not an AppVideo wrapper; keep both in sync.
ClippingRectangle {
    id: root

    radius: Theme.radius
    color: "transparent"

    property string source: ""      // local file path (Gio.File.new_for_path equivalent)
    property bool autoplay: true
    property bool loop: true
    property bool fill: true        // if false, letterbox (preserve aspect)
    // Exposed so hosts can keep a poster still underneath until the first frame arrives
    // (otherwise the card is blank during load and forever on decode failure).
    readonly property bool hasVideo: player.hasVideo
    // Presentation gate: dialogs live in often-hidden windows whose `visible` stays true, so
    // without this every instance decodes the same file (triple unmuted audio -> stalls).
    property bool active: visible

    MediaPlayer {
        id: player
        // Gate the source on visibility: VideoOutput.visible alone does NOT stop decoding — a hidden
        // player on an image loops ffmpeg errors and fills /run/user/1000, killing IPC.
        source: (root.active && root.visible && root.source !== "") ? "file://" + root.source : ""
        audioOutput: AudioOutput {}
        videoOutput: videoOut
        loops: root.loop ? MediaPlayer.Infinite : 1
        autoPlay: root.autoplay && root.active && root.visible
    }

    VideoOutput {
        id: videoOut
        anchors.fill: parent
        // Overscan: scaled video often carries a 1px dark fringe (YUV padding, edge filtering), so
        // render 2px past the viewport and let the host clip it. All hosts clip.
        anchors.margins: -2
        fillMode: root.fill ? VideoOutput.Stretch : VideoOutput.PreserveAspectFit
        visible: root.source !== "" && player.hasVideo
    }

    // Teardown: stop (not just pause) + release the stream when the widget leaves the screen, so a
    // re-shown item rebinds a fresh source instead of resuming a failed decode loop.
    onVisibleChanged: {
        if (!visible) {
            _playTimer.stop();
            player.stop();
        } else if (root.autoplay && root.active && root.source !== "") {
            root._kickPlayback();
        }
    }
    // Deactivation behaves like hiding, with a retried startup: a single deferred play() races the
    // source binding (silent no-op), so retry until Playing (AppVideo _kickPlayback parity).
    onActiveChanged: {
        if (!root.active) {
            _playTimer.stop();
            player.stop();
        } else if (root.autoplay && root.source !== "") {
            root._kickPlayback();
        }
    }
    // A direct file->file switch while visible can stall the backend (hasVideo never re-fires,
    // no error, blank card), so bounce through stop() + deferred play() to load like a fresh file.
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
