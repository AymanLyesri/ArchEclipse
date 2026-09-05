import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.theme
import qs.services
import qs.widgets.shared

// Media Widget — port of widgets/MediaWidget.tsx + widgets/Player.tsx.
// Shows the active (playing-else-first) player with the rich Player layout:
// cover art + spinning indicator + track slide transition, drag-scrubbable
// position, can_* gated controls. (Cava visualizer omitted: requires cava.)
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    // Pick active player: the PLAYING one, else the first (matches AGS
    // MediaWidget / AppLauncher left pane logic). Mpris.players is an
    // UntypedObjectModel — access via .values for iteration.
    readonly property var playersList: Mpris.players.values ?? (Array.from ? Array.from(Mpris.players.values() ?? []) : [])
    readonly property var player: {
        for (const p of root.playersList) {
            if (p.isPlaying) return p
        }
        return root.playersList.length > 0 ? root.playersList[0] : null
    }

    readonly property bool playing: root.player?.isPlaying ?? false

    // Hysteresis: hold last valid cover to prevent flicker (AGS lastValidCover)
    property string _lastCover: ""
    onArtUrlChanged: {
        if (artUrl && artUrl.trim() !== "") root._lastCover = artUrl
    }

    property bool scrubbing: false
    property real scrubPos: 0

    // Title/artist from active player (binding → change signal fires)
    property string title: root.player?.trackTitle ?? "Unknown Track"
    property string artist: root.player?.trackArtist ?? "Unknown Artist"
    property string artUrl: root.player?.trackArtUrl ?? ""

    // Title change → slide animation via MPRIS trackTitleChanged signal
    Connections {
        target: root.player
        function onTrackTitleChanged() {
            slideAnim.stop()
            textLayer.anchors.verticalCenterOffset = -12
            slideAnim.to = 0
            slideAnim.restart()
        }
    }

    function fmt(usec) {
        if (!usec || usec <= 0) return "0:00"
        const s = Math.floor(usec / 1e6)
        const m = Math.floor(s / 60), ss = s % 60
        return m + ":" + (ss < 10 ? "0" : "") + ss
    }

    Column {
        anchors.fill: parent
        spacing: 10

        Row {
            spacing: 8
            Label { text: "Media"; font.pixelSize: Theme.fontSize + 4; font.bold: true; color: Theme.fg; Layout.fillWidth: true }
        }

        Rectangle {
            width: parent.width
            height: 170
            radius: 8
            clip: true
            color: Theme.moduleBg
            border.width: 1
            border.color: Theme.border
            visible: root.player !== null

            // Blurred background cover (AGS Picture "img" blurred layer)
            Image {
                anchors.fill: parent
                source: root._lastCover || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0.35
                visible: root._lastCover !== ""
            }

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Top row: spinner cover art + title/artist + app icon
                Row {
                    width: parent.width
                    spacing: 10

                    // Spinning cover art thumbnail (AGS cover-art-spinner)
                    Rectangle {
                        id: coverBox
                        width: 64; height: 64
                        radius: 8
                        clip: true
                        color: Theme.bg
                        border.width: 1
                        border.color: Theme.border

                        Image {
                            id: coverImg
                            anchors.fill: parent
                            source: root._lastCover || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: 2
                            border.color: root.playing ? Theme.accent : Qt.alpha(Theme.accent, 0.3)
                            radius: 8
                        }
                        // spinning indicator (rotation while playing)
                        Rectangle {
                            anchors.right: parent.right; anchors.top: parent.top
                            width: 10; height: 10
                            radius: 5
                            color: root.playing ? Theme.accent : Theme.fgDim
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        // progress ring while playing (spinner visual)
                        Canvas {
                            id: ringCanvas
                            anchors.fill: parent
                            visible: root.playing
                            function redrawRing() {
                                if (!visible) return
                                const ctx = getContext("2d")
                                if (!ctx) return
                                ctx.reset()
                                const len = root.player ? root.player.length : 0
                                const pos = root.player ? root.player.position : 0
                                const frac = len > 0 ? pos / len : 0
                                ctx.beginPath()
                                ctx.strokeStyle = Theme.accent
                                ctx.lineWidth = 2
                                ctx.arc(width/2, height/2, width/2 - 4, -Math.PI/2, -Math.PI/2 + 2*Math.PI*frac)
                                ctx.stroke()
                            }
                            onVisibleChanged: if (visible) redrawRing()
                            // periodic repaint while playing (avoids null-player Connections)
                            Timer {
                                interval: 1000
                                running: ringCanvas.visible
                                repeat: true
                                onTriggered: ringCanvas.redrawRing()
                            }
                        }
                    }

                    // Title / artist with slide transition (AGS textStack)
                    Item {
                        id: trackBlock
                        Layout.fillWidth: true
                        height: 64
                        clip: true

                        Column {
                            id: textLayer
                            width: parent.width
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter

                            Label {
                                id: titleLabel
                                width: parent.width
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontSize + 1
                                font.bold: true
                                color: Theme.fg
                                text: root.title
                            }
                            Label {
                                width: parent.width
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontSize - 1
                                color: Theme.foregroundSecondary
                                text: root.artist
                            }
                        }
                        NumberAnimation {
                            id: slideAnim
                            target: textLayer
                            property: "anchors.verticalCenterOffset"
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }

                    // App icon (AGS identity tooltip + entry icon)
                    Label {
                        width: 22; height: 64
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "\u{F1FE}"  // music-note icon
                        color: Theme.fgDim
                        font.pixelSize: 18
                        ToolTip.visible: iconTip.hovered
                        ToolTip.text: root.player?.identity ?? ""
                        HoverHandler { id: iconTip }
                    }
                }

                Item { width: 1; height: 6 }

                // Position/length + controls
                Row {
                    width: parent.width
                    spacing: 6

                    Label { text: root.fmt(root.scrubbing ? root.scrubPos : (root.player?.position ?? 0)); color: Theme.fgDim; font.pixelSize: Theme.fontSize - 2; verticalAlignment: Text.AlignVCenter }

                    Item { Layout.fillWidth: true }

                    // prev
                    AppButton {
                        enabled: root.player?.canGoPrevious ?? false
                        icon: "⏪"
                        pixelSize: 14
                        onClicked: root.player?.previous()
                    }
                    // play/pause
                    AppButton {
                        enabled: root.player?.canPause ?? (root.player?.canPlay ?? false)
                        icon: root.playing ? "⏸" : "▶"
                        pixelSize: 14
                        cornerRadius: 16
                        implicitWidth: 30
                        implicitHeight: 30
                        idleBg: Theme.accentBg
                        idleFg: Theme.accent
                        onClicked: { if (root.playing) root.player?.pause(); else root.player?.play() }
                    }
                    // next
                    AppButton {
                        enabled: root.player?.canGoNext ?? false
                        icon: "⏩"
                        pixelSize: 14
                        onClicked: root.player?.next()
                    }

                    Item { Layout.fillWidth: true }

                    Label { text: root.fmt(root.player?.length ?? 0); color: Theme.fgDim; font.pixelSize: Theme.fontSize - 2; verticalAlignment: Text.AlignVCenter }
                }

                // Drag-scrubbable position slider (AGS GestureDrag scrub)
                Rectangle {
                    id: progBg
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.border

                    property real frac: root.scrubbing ? (root.scrubPos / Math.max(1, root.player?.length ?? 1))
                                                         : (root.player?.length ?? 0) > 0 ? (root.player?.position ?? 0) / root.player.length : 0
                    property real fill: Math.max(0, Math.min(1, frac))

                    Rectangle {
                        id: progFill
                        width: progBg.width * progBg.fill
                        height: 6
                        radius: 3
                        color: Theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.player?.canSeek ?? false
                        cursorShape: Qt.PointingHandCursor
                        onPressed: (mouse) => { root.scrubbing = true; root.scrubPos = mouse.x / width * (root.player?.length ?? 0) }
                        onPositionChanged: (mouse) => { if (root.scrubbing) root.scrubPos = mouse.x / width * (root.player?.length ?? 0) }
                        onReleased: (mouse) => {
                            if (root.scrubbing) {
                                root.scrubPos = mouse.x / width * (root.player?.length ?? 0)
                                root.player?.seek(root.scrubPos)
                                root.scrubbing = false
                            }
                        }
                    }
                }
            }
        }

        // No player state — centered container (anchors inside Column unreliable)
        Item {
            visible: root.player === null
            height: 170
            width: parent.width
            Label {
                anchors.centerIn: parent
                text: "No player found"
                font.pixelSize: Theme.fontSize
                color: Theme.fgDim
            }
        }
    }



}
