import QtQuick
import QtMultimedia
import Quickshell.Widgets
import qs.theme

// AppVideo — shared looping video player: `active` gates the decoder (a hidden player on an
// undecodable source loops ffmpeg errors and fills /run), teardown stops and unloads.
ClippingRectangle {
    id: root

    property string source: "" // local file path (no file:// prefix)
    property bool active: visible
    property bool autoplay: true
    property bool loop: true
    property bool muted: false
    property int fillMode: VideoOutput.PreserveAspectCrop
    readonly property bool ready: player.hasVideo || root._failed
    property bool _failed: false
    // Native video dimensions for aspect parity with image tiles; (0,0) means "not known yet",
    // like an undecoded Image's implicit size.
    readonly property size videoSize: {
        try {
            const r = player.metaData.value(MediaMetaData.Resolution);
            if (r !== undefined && r.width > 0 && r.height > 0)
                return Qt.size(r.width, r.height);
        } catch (e) {
            if (!root._ratioWarned) {
                root._ratioWarned = true;
                console.warn("[AppVideo] video resolution lookup failed: " + e);
            }
        }
        return Qt.size(0, 0);
    }
    property bool _ratioWarned: false
    readonly property real videoRatio: (videoSize.width > 0 && videoSize.height > 0) ? videoSize.width / videoSize.height : 0
    // Unified badge overlay (top-right). Same contract as AppImage.badges:
    // callers feed Icons.* glyphs, e.g. badges: [bookmarked ? Icons.bookmark : ""]
    property var badges: []

    signal errorOccurred(string message)

    // Rounded like AppImage by default; hosts that clip square
    // themselves are unaffected (same geometry either way).
    radius: Theme.radius
    color: "transparent"

    MediaPlayer {
        id: player
        source: (root.active && root.source !== "") ? "file://" + root.source : ""
        audioOutput: AudioOutput {
            muted: root.muted
        }
        videoOutput: videoOut
        loops: root.loop ? MediaPlayer.Infinite : 1
        autoPlay: root.autoplay && root.active
        onErrorOccurred: (error, errorString) => {
            // Decode failures are terminal for this source; mark failed
            // once so hosts can fall back (no per-frame logging).
            if (!root._failed) {
                root._failed = true;
                root.errorOccurred(errorString);
            }
        }
        onSourceChanged: root._failed = false
    }

    VideoOutput {
        id: videoOut
        anchors.fill: parent
        // Overscan (see MediaVideo): swallow the 1px decoder/filter fringe
        // under the host's clip — the tile root is a ClippingRectangle.
        anchors.margins: -2
        fillMode: root.fillMode
        visible: root.source !== "" && player.hasVideo
    }

    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 4
        spacing: Theme.spacing
        visible: root.badges.length > 0
        Repeater {
            model: root.badges
            delegate: AppBadge {
                required property string modelData
                text: modelData
            }
        }
    }

    onActiveChanged: {
        if (!root.active) {
            _playTimer.stop();
            player.stop();
        } else if (root.autoplay && root.source !== "") {
            root._kickPlayback();
        }
    }
    // Same silent-stall class as MediaVideo: after source churn the backend holds a source with
    // no video and no error, so bounce stop() + retried play() (one deferred play() races it).
    onSourceChanged: {
        if (!root.active || root.source === "")
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
            if (!root.active || root.source === "" || player.source === "") {
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
        player.stop();
        player.source = "";
    }
}
