import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.theme
import qs.services

// Port of Information.tsx (center section):
// player (if any playable MPRIS player) + clock + keyboard layout + bandwidth
// (+ crypto favorite, hidden while unset — same as AGS).
Row {
    id: root
    spacing: Theme.spacing
    height: 24

    // ---- media (PlayerWidget presence logic) ----
    readonly property var firstPlayable: {
        Mpris.players.values;   // reactive dep
        for (const p of Mpris.players.values)
            if ((p.trackTitle ?? "").trim() !== "" || p.playbackState === MprisPlaybackState.Playing)
                return p;
        return null;
    }

    Text {
        visible: root.firstPlayable !== null
        anchors.verticalCenter: parent.verticalCenter
        text: root.firstPlayable ? `${root.firstPlayable.playbackState === MprisPlaybackState.Playing ? "\u{F03E5}" : "\u{F040A}"} ${root.firstPlayable.trackTitle}` : ""
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 200)
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    Clock {
        anchors.verticalCenter: parent.verticalCenter
        height: 22
    }

    KeyboardLayout {
        anchors.verticalCenter: parent.verticalCenter
        height: 22
    }

    // ---- bandwidth (Bandwidth.tsx compact form) ----
    Row {
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter
        Text { text: SysInfo.bandwidth[0] + ""; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
        Text { text: "\u{F062}"; color: Theme.secondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
        Text { text: SysInfo.bandwidth[1] + ""; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
        Text { text: "\u{F063}"; color: Theme.secondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
    }
}
