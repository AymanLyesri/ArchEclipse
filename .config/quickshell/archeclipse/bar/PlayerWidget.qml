import Quickshell
import QtQuick
import qs.theme
import Quickshell.Services.Mpris

Item {
    id: root

    property real widthRequest: 0

    // MPRIS players
    property var players: Quickshell.Services.Mpris.players.values
    property var activePlayer: null

    // Find active player (playing)
    function updateActivePlayer() {
        for (const player of root.players) {
            if (player.playbackStatus === Quickshell.Services.Mpris.MprisPlaybackState.Playing) {
                root.activePlayer = player
                return
            }
        }
        // If none playing, use first available
        if (root.players.length > 0) {
            root.activePlayer = root.players[0]
        }
    }

    Component.onCompleted: {
        updateActivePlayer()
        Quickshell.Services.Mpris.players.onChanged = updateActivePlayer
    }

    // Player info
    property string title: activePlayer?.title ?? ""
    property string artist: activePlayer?.artist ?? ""
    property string artUrl: activePlayer?.artUrl ?? ""
    property string status: activePlayer?.playbackStatus ?? "Stopped"
    property real position: activePlayer?.position ?? 0
    property real length: activePlayer?.length ?? 0
    property real volume: activePlayer?.volume ?? 1

    // Main layout
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 8
        color: Theme.color0
        border.color: Theme.color8
        border.width: 1

        Row {
            id: row
            anchors.fill: parent
            spacing: 10
            anchors.margins: 12

            // Artwork (placeholder)
            Rectangle {
                id: art
                width: 40
                height: 40
                radius: 4
                color: Theme.accentBg
                visible: root.artUrl !== ""

                // Image would go here if artUrl available
            }

            // Track info
            Column {
                spacing: 2
                verticalAlignment: Text.AlignVCenter

                Text {
                    text: root.title
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 11
                    color: Theme.foreground
                    elide: Text.ElideRight
                    width: 200
                }

                Text {
                    text: root.artist
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 9
                    color: Theme.color8
                    elide: Text.ElideRight
                    width: 200
                }
            }

            // Controls
            Row {
                spacing: 8
                verticalAlignment: Text.AlignVCenter

                Button {
                    text: "\u{F040}" // previous
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 14
                    onClicked: activePlayer?.previous()
                    background: Rectangle { color: "transparent" }
                }

                Button {
                    text: status === "Playing" ? "\u{F04C}" : "\u{F04B}" // pause/play
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 14
                    onClicked: activePlayer?.playPause()
                    background: Rectangle { color: "transparent" }
                }

                Button {
                    text: "\u{F041}" // next
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 14
                    onClicked: activePlayer?.next()
                    background: Rectangle { color: "transparent" }
                }
            }

            // Progress bar
            Rectangle {
                id: progressBg
                width: 100
                height: 3
                radius: 1.5
                color: Theme.color8

                Rectangle {
                    width: progressBg.width * (root.length > 0 ? root.position / root.length : 0)
                    height: 3
                    radius: 1.5
                    color: Theme.accent
                }
            }
        }
    }

    // Hover handler for pulse
    HoverHandler {
        onEntered: BarState.activate("player", 2500)
    }
}