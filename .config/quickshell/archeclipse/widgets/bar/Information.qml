import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Mpris
import qs.theme
import qs.services
import qs.widgets.rightPanel
import qs.widgets.weather

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
        text: root.firstPlayable ? (root.firstPlayable.playbackState === MprisPlaybackState.Playing ? "\uF03E5" : "\uF040A") + " " + root.firstPlayable.trackTitle : ""
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

    KeyboardLayoutWidget {
    }

    // ---- bandwidth (Bandwidth.tsx compact form) ----
    Row {
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter
        Text { text: SysInfo.bandwidth[0] + ""; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
        Text { text: "\uF062"; color: Theme.secondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
        Text { text: SysInfo.bandwidth[1] + ""; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
        Text { text: "\uF063"; color: Theme.secondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2 }
    }

    // ---- weather button (AGS WeatherButton) ----
    WeatherButton {
        anchors.verticalCenter: parent.verticalCenter
    }

    // ---- pinned crypto favorite (AGS Information crypto.favorite, click-to-remove) ----
    Item {
        id: favBox
        visible: Settings.cryptoFavorite && (Settings.cryptoFavorite.symbol || "") !== ""
        width: favItem.width + 4
        height: 22
        anchors.verticalCenter: parent.verticalCenter

        CryptoItem {
            id: favItem
            anchors.verticalCenter: parent.verticalCenter
            width: 170
            entry: Settings.cryptoFavorite
            property bool horizontal: true
            itemWidth: 170
            anchors.left: parent.left
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Settings.cryptoFavorite = { symbol: "", timeframe: "" }
                Settings.updateSetting("crypto.favorite", Settings.cryptoFavorite)
            }
            ToolTip.visible: hovered
            ToolTip.text: "click to remove"
        }
    }
}