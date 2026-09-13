import QtQuick
import QtMultimedia
import Quickshell.Widgets
import qs.theme

// AppVideo — shared looping video player (qs.widgets.shared parity with
// AppImage, including its top-right badge overlay). Used directly by the
// wallpaper switcher tiles and the waifu widget, around one lifecycle:
//
// - `active` gates the decoder: the source is bound only while active, so
//   hidden/off-viewport instances hold no decoder. A hidden player fed an
//   undecodable source loops ffmpeg errors thousands of times per second,
//   filling /run/user/<uid> and killing IPC/panels — never bind blindly.
//   Defaults to `visible`; viewport-virtualized callers (wallpaper tiles)
//   override it with their own in-view state.
// - Teardown stops (not pauses) + unloads, so re-activation rebinds a
//   fresh source instead of resuming a stale decode (GStreamer GL crash).
// - `ready` (first frame or terminal decode failure) lets hosts fade in
//   or fall back; failures report once via errorOccurred (no per-frame
//   logging here — hosts log with their own context if they care).
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
    // Native video dimensions for aspect parity with image tiles.
    // Unknown until metadata arrives — (0,0) means "not known yet",
    // same as an undecoded Image's implicit size.
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
    // callers feed icon strings, e.g. badges: [bookmarked ? "\uf02e" : ""]
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
        spacing: 4
        visible: root.badges.length > 0
        Repeater {
            model: root.badges
            delegate: Rectangle {
                required property string modelData
                width: 24
                height: 18
                radius: Theme.radius
                color: Theme.accent
                visible: modelData !== ""
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData
                    font.pixelSize: 9
                    font.family: Theme.fontFamily
                    color: "white"
                }
            }
        }
    }

    onActiveChanged: {
        if (!root.active)
            player.stop();
        else if (root.autoplay && root.source !== "")
            player.play();
    }
    Component.onDestruction: {
        player.stop();
        player.source = "";
    }
}
