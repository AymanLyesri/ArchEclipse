import Quickshell
import Quickshell.Io
import QtQuick
import qs.theme
import qs.widgets.bar
import Quickshell.Services.Mpris
import qs.services

Item {
    id: root

    property real widthRequest: 0

    // MPRIS players
    property var players: Quickshell.Services.Mpris.players.values
    // Computed (not assigned): re-evaluates whenever the player list OR any
    // player's title/playbackStatus changes — mirrors AGS playablePlayers
    // createComputed which re-filters on title + playbackStatus bindings.
    readonly property var activePlayer: {
        let firstPlayable = null
        for (const player of root.players) {
            // touch reactive props so the binding re-fires on changes
            const st = player.playbackState
            const ti = player.trackTitle
            if (st === Quickshell.Services.Mpris.MprisPlaybackState.Playing) return player
            if (!firstPlayable && ((ti ?? "").trim() !== "")) firstPlayable = player
        }
        return firstPlayable
    }

    // Cava audio visualizer points (from external cava CLI raw output)
    property var visualizerPoints: []
    readonly property bool isPlaying: root.activePlayer?.isPlaying ?? false

    // AGS isPlayablePlayer (PlayerWidget.tsx:18-29): browsers leave zombie
    // mpris players behind after a media tab closes — no title, nothing
    // playing — which would render as "Unknown Track" entries. Only players
    // with real metadata or active playback count.
    function isPlayablePlayer(p) {
        return ((p.trackTitle ?? "").trim() !== "") ||
            p.playbackState === Quickshell.Services.Mpris.MprisPlaybackState.Playing
    }

    Component.onCompleted: {
        Quickshell.Services.Mpris.players.onChanged = function() { root.players = Quickshell.Services.Mpris.players.values }
    }

    // Cava process — runs only while a player is playing
    Process {
        id: cavaProc
        running: root.isPlaying
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/quickshell/archeclipse/scripts/cava/raw_output_config.txt"]
        stdout: SplitParser {
            onRead: function(data) {
                // Parse `;`-separated values into visualizerPoints
                const pts = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p))
                if (pts.length > 0) root.visualizerPoints = pts
            }
        }
    }

    // Player info
    property string title: activePlayer?.trackTitle ?? ""
    property string artist: activePlayer?.trackArtist ?? ""
    // AGS cover guard (PlayerWidget.tsx:54-60): YouTube clears coverArt
    // transiently — keep the last valid cover instead of flickering.
    property string _lastValidArt: ""
    property string artUrl: {
        const a = activePlayer?.trackArtUrl ?? ""
        if (a && a.trim() !== "") root._lastValidArt = a
        return (a && a.trim() !== "") ? a : root._lastValidArt
    }
    property string status: activePlayer?.playbackState ?? "Stopped"
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

            // Artwork with cava visualizer overlay
            Rectangle {
                id: art
                width: 40
                height: 40
                radius: 4
                color: Theme.accentBg
                visible: root.artUrl !== ""

                WaveVisualizer {
                    anchors.fill: parent
                    live: root.isPlaying
                    points: root.visualizerPoints
                    color: Theme.accent
                    visible: root.isPlaying
                }
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
                    text: root.isPlaying ? "\u{F04C}" : "\u{F04B}" // pause/play
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 14
                    onClicked: activePlayer?.togglePlaying()
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