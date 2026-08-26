import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.theme

// Port of barStates PlayerWidget pulse — shown for 2.5s when a player's
// title changes (watcher lives in BarState via the "player" activation from
// MediaPulseWatcher below).
Rectangle {
    width: 320; height: 24
    radius: Theme.radius
    color: Theme.moduleBg

    readonly property var player: {
        Mpris.players.values;
        for (const p of Mpris.players.values)
            if ((p.trackTitle ?? "").trim() !== "" || p.playbackState === MprisPlaybackState.Playing)
                return p;
        return null;
    }

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacing
        Text { text: root.player?.playbackState === MprisPlaybackState.Playing ? "\u{F03E5}" : "\u{F040A}"; color: Theme.foreground; font.family: Theme.fontFamily }
        Text {
            text: root.player?.trackTitle ?? ""
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 240)
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
