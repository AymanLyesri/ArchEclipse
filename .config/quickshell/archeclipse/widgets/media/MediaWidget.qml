import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.theme
import qs.services
import qs.widgets.shared

// Media Widget (port of MediaWidget.tsx + Player.tsx): the active (playing-else-first) player
// with cover art, spinning indicator, drag-scrubbable position and can_* gated controls.
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    // Natural size (single source of truth): consumers without a sized parent (PlayerIsland)
    // derive from these instead of hardcoding width/height.
    // Extra row when more than one player is available (the switcher above the art).
    readonly property real switcherHeight: root.orderedPlayers.length > 1 ? 30 : 0
    implicitWidth: 400
    implicitHeight: 172 + root.switcherHeight + (root.player !== null && root.hasLyrics ? 72 : 0)

    // All players, PLAYING first: the switcher shows this order. Mpris.players is an
    // UntypedObjectModel, so iterate via .values.
    readonly property var playersList: Mpris.players.values ?? (Array.from ? Array.from(Mpris.players.values() ?? []) : [])
    readonly property var orderedPlayers: {
        Mpris.players.values;
        const playing = [];
        const rest = [];
        for (const p of root.playersList) {
            if (!p)
                continue;
            const title = String(p.trackTitle ?? "").trim();
            const identity = String(p.identity ?? "").trim();
            if (title === "" && identity === "")
                continue;
            if (p.isPlaying === true)
                playing.push(p);
            else
                rest.push(p);
        }
        return playing.concat(rest);
    }
    // -1 follows the list head (always the playing player). A chip pins one explicitly.
    property int selectedIndex: -1
    readonly property var player: {
        const list = root.orderedPlayers;
        if (list.length === 0)
            return null;
        if (root.selectedIndex >= 0 && root.selectedIndex < list.length)
            return list[root.selectedIndex];
        return list[0];
    }

    readonly property bool playing: root.player?.isPlaying ?? false

    // Hysteresis: hold last valid cover to prevent flicker
    property string _lastCover: ""
    onArtUrlChanged: {
        if (artUrl && artUrl.trim() !== "")
            root._lastCover = artUrl;
    }

    property bool scrubbing: false
    property real scrubPos: 0

    // Title/artist from active player (binding → change signal fires)
    property string title: root.player?.trackTitle ?? "Unknown Track"
    property string artist: root.player?.trackArtist ?? "Unknown Artist"
    property string artUrl: root.player?.trackArtUrl ?? ""
    property string album: root.player?.trackAlbum ?? ""

    // LRCLIB lyrics — always visible, Spotify-style 3-line window
    // (previous dim / current accent / next plain).

    function fetchLyrics() {
        if (root.player === null)
            return;
        Lyrics.positionSec = root.player?.position ?? 0;
        Lyrics.fetchFor(root.artist, root.title, root.album,
            Math.round(root.player?.length ?? 0));
    }

    // True once LRCLIB returns usable lyric content; the section
    // collapses to zero height otherwise so it never takes space.
    readonly property bool hasLyrics: Lyrics.status === "ready-synced" || Lyrics.status === "ready-plain"

    // 3-line window over the synced lines, clamped into range.
    // currentIndex -1 (before the first line) shows from the top.
    readonly property int lyricCursor: {
        const n = (Lyrics.lines || []).length;
        if (n === 0)
            return -1;
        return Math.max(0, Math.min(Lyrics.currentIndex, n - 1));
    }
    function lyricLineAt(offset) {
        const arr = Lyrics.lines || [];
        const i = root.lyricCursor + offset;
        if (root.lyricCursor < 0 || i < 0 || i >= arr.length)
            return "";
        return arr[i].text || "";
    }
    function lyricTimeAt(offset) {
        const arr = Lyrics.lines || [];
        const i = root.lyricCursor + offset;
        if (root.lyricCursor < 0 || i < 0 || i >= arr.length)
            return -1;
        return Number(arr[i].t);
    }
    // Plain-lyrics fallback: proportional 3-line window (no timestamps).
    function plainWindow() {
        const raw = String(Lyrics.plainText || "").split("\n");
        const arr = [];
        for (let i = 0; i < raw.length; i++) {
            const t = raw[i].trim();
            if (t !== "")
                arr.push(t);
        }
        if (arr.length === 0)
            return ["", "", ""];
        const dur = root.player?.length ?? 0;
        let idx = 0;
        if (dur > 0)
            idx = Math.floor((Lyrics.positionSec / dur) * arr.length);
        idx = Math.max(0, Math.min(idx, arr.length - 1));
        return [
            idx > 0 ? arr[idx - 1] : "",
            arr[idx],
            idx + 1 < arr.length ? arr[idx + 1] : ""
        ];
    }

    // Icon via the MPRIS DesktopEntry with identity fallbacks, then Quickshell.iconPath() into
    // an image:// URL (bare theme names never load); missing falls back to the music note.
    readonly property string appIconSource: {
        const p = root.player;
        if (!p)
            return "";
        const de = String(p.desktopEntry ?? "").trim();
        const id = String(p.identity ?? "").trim();
        let raw = "";
        try {
            let entry = null;
            if (de !== "")
                entry = DesktopEntries.byId(de) ?? DesktopEntries.heuristicLookup(de);
            if (!entry && id !== "")
                entry = DesktopEntries.heuristicLookup(id);
            if (entry && entry.icon)
                raw = entry.icon;
        } catch (e) {}
        if (raw === "" && id !== "")
            raw = id.toLowerCase();
        if (raw === "") {
            try {
                const bus = String(p.dbusName ?? "").trim();
                if (bus !== "") {
                    const tail = bus.split(".").pop();
                    if (tail)
                        raw = tail.toLowerCase();
                }
            } catch (e) {}
        }
        if (raw === "")
            return "";
        if (raw.startsWith("image://") || raw.startsWith("file://") || raw.startsWith("qrc:/") || raw.startsWith("/"))
            return raw;
        try {
            return Quickshell.iconPath(raw, true);
        } catch (e) {
            return "";
        }
    }

    // Title change → the track block rises into place instead of swapping text in place.
    Connections {
        target: root.player
        function onTrackTitleChanged() {
            trackIn.restart();
        }
    }
    ParallelAnimation {
        id: trackIn
        NumberAnimation {
            target: textLayer
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.anim.small
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: textShift
            property: "y"
            from: 8
            to: 0
            duration: Theme.anim.small
            easing.type: Easing.OutCubic
        }
    }

    // Track identity change → refetch lyrics (fetchLyrics self-guards
    // on lyricsOpen/player, so these are cheap when closed).
    onTitleChanged: root.fetchLyrics()
    onArtistChanged: root.fetchLyrics()
    onAlbumChanged: root.fetchLyrics()

    // Quickshell only pushes position on nonlinear jumps, so poll while a player exists
    // (docs-sanctioned positionChanged()) to keep the time label, ring and lyrics in sync.
    Timer {
        interval: 500
        running: root.player !== null
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.player)
                return;
            if (root.player.playbackState === MprisPlaybackState.Playing)
                root.player.positionChanged();
            Lyrics.positionSec = root.player.position ?? 0;
        }
    }

    function fmt(sec) {
        if (!sec || sec <= 0)
            return "0:00";
        // MPRIS position/length arrive in seconds (ms precision).
        const s = Math.floor(sec);
        const m = Math.floor(s / 60), ss = s % 60;
        return m + ":" + (ss < 10 ? "0" : "") + ss;
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        clip: true
        // Media card: raised plate with the cover bleeding through at low opacity, so the
        // artwork itself supplies the depth. No outline.
        color: Theme.surfaceRaised
        visible: root.player !== null

        // Blurred background cover ("img" blurred layer)
        AppImage {
            anchors.fill: parent
            source: root._lastCover || ""
            opacity: 0.12
            visible: root._lastCover !== ""
        }

        // One vertical reading: who is playing, how far along, what you can do, what is sung.
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: Theme.spaceSm

            // ---- player switcher: every player, playing one first ----
            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: root.switcherHeight > 0 ? 24 : 0
                visible: root.switcherHeight > 0
                clip: true
                contentWidth: chipRow.width
                contentHeight: 24
                flickableDirection: Flickable.HorizontalFlick

                Row {
                    id: chipRow
                    height: 24
                    spacing: Theme.spaceXs

                    Repeater {
                        model: root.orderedPlayers
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool current: root.player === modelData
                            readonly property bool rowPlaying: modelData.isPlaying === true

                            width: chipText.implicitWidth + (rowPlaying ? 14 : 0) + Theme.spaceSm * 2
                            height: 22
                            radius: Theme.radius
                            color: current ? Theme.surfaceOverlay : (chipHover.hovered ? Theme.surfaceHover : "transparent")
                            Behavior on color {
                                CAnim {}
                            }

                            Text {
                                id: chipText
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spaceSm
                                text: modelData.identity || "Player"
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, 92)
                                color: current ? Theme.fg : Theme.fgDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.typeCaption
                            }
                            Rectangle {
                                visible: parent.rowPlaying
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spaceSm
                                anchors.verticalCenter: parent.verticalCenter
                                width: 5
                                height: 5
                                radius: 3
                                color: Theme.accent
                            }

                            HoverHandler {
                                id: chipHover
                                cursorShape: Qt.PointingHandCursor
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: false
                                preventStealing: false
                                propagateComposedEvents: true
                                onClicked: root.selectedIndex = index
                            }
                        }
                    }
                }
            }

            // ---- identity: art, track, source app ----
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceMd

                // Cover art is the anchor of the card: large enough to recognize at a glance.
                Rectangle {
                    id: coverBox
                    Layout.preferredWidth: 84
                    Layout.preferredHeight: 84
                    radius: Theme.radius
                    clip: true
                    color: Theme.bg

                    AppImage {
                        id: coverImg
                        anchors.fill: parent
                        source: root._lastCover || ""
                    }

                    // Playback state is a dot on the art, not a second progress ring: the bar
                    // below already carries position.
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        width: 8
                        height: 8
                        radius: 4
                        color: root.playing ? Theme.accent : Theme.fgDim
                        Behavior on color {
                            CAnim {}
                        }
                    }
                }

                // Title / artist / album with a small slide on track change.
                ColumnLayout {
                    id: textLayer
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1
                    transform: Translate {
                        id: textShift
                    }

                    Label {
                        id: titleLabel
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.pixelSize: Theme.typeSubtitle
                        font.weight: Font.DemiBold
                        color: Theme.fg
                        text: root.title
                    }
                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.pixelSize: Theme.typeLabel
                        color: Theme.muted
                        text: root.artist
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: root.album !== ""
                        elide: Text.ElideRight
                        font.pixelSize: Theme.typeCaption
                        color: Theme.fgDim
                        text: root.album
                    }
                }

                // App icon (DefaultBar parity: real theme icon via DesktopEntry/identity
                // lookup, music-note glyph fallback), top-aligned with the art.
                Item {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: coverBox.height

                    IconImage {
                        id: appIconImg
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 4
                        width: 20
                        height: 20
                        source: root.appIconSource
                        visible: status === Image.Ready && root.appIconSource !== ""
                        asynchronous: true
                    }
                    Label {
                        anchors.centerIn: parent
                        visible: !appIconImg.visible
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: Icons.music
                        color: Theme.fgDim
                        font.pixelSize: Theme.fs(1.5)
                    }
                    AppTooltip {
                        visible: iconTip.hovered
                        text: root.player?.identity ?? ""
                    }
                    HoverHandler {
                        id: iconTip
                    }
                }
            }

            // ---- position: elapsed and total bracket the scrub bar they describe ----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.fmt(root.scrubbing ? root.scrubPos : (root.player?.position ?? 0))
                        color: Theme.fgDim
                        font.pixelSize: Theme.typeCaption
                        font.preferShaping: false
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                    }
                    Label {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.fmt(root.player?.length ?? 0)
                        color: Theme.fgDim
                        font.pixelSize: Theme.typeCaption
                        font.preferShaping: false
                    }
                }

                Rectangle {
                    id: progBg
                    Layout.fillWidth: true
                    Layout.minimumHeight: 5
                    Layout.preferredHeight: 5
                    height: 5
                    radius: 3
                    color: Theme.track

                    property real frac: root.scrubbing ? (root.scrubPos / Math.max(1, root.player?.length ?? 1)) : (root.player?.length ?? 0) > 0 ? (root.player?.position ?? 0) / root.player.length : 0
                    property real fill: Math.max(0, Math.min(1, frac))

                    Rectangle {
                        id: progFill
                        width: progBg.width * progBg.fill
                        height: 5
                        radius: 3
                        color: Theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.player?.canSeek ?? false
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => {
                            root.scrubbing = true;
                            root.scrubPos = mouse.x / width * (root.player?.length ?? 0);
                        }
                        onPositionChanged: mouse => {
                            if (root.scrubbing)
                                root.scrubPos = mouse.x / width * (root.player?.length ?? 0);
                        }
                        onReleased: mouse => {
                            if (root.scrubbing) {
                                const len = root.player?.length ?? 0;
                                root.scrubPos = Math.max(0, Math.min(mouse.x / width * len, len));
                                // Absolute write: seek(offset) is relative per the
                                // MprisPlayer docs, so it can't land a drag.
                                if (root.player && (root.player.canSeek ?? false))
                                    root.player.position = root.scrubPos;
                                root.scrubbing = false;
                            }
                        }
                    }
                }
            }

            // ---- transport: centered, the play button reads as the primary action ----
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceMd

                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }
                AppButton {
                    tooltipText: "Previous track"
                    enabled: root.player?.canGoPrevious ?? false
                    icon: Icons.arrowLeft
                    pixelSize: Theme.fontSizeLarge
                    Layout.preferredWidth: 32
                    Layout.minimumWidth: 24
                    implicitHeight: 32
                    onClicked: root.player?.previous()
                }
                AppButton {
                    enabled: root.player?.canPause ?? (root.player?.canPlay ?? false)
                    icon: root.playing ? Icons.pause : Icons.play
                    tooltipText: root.playing ? "Pause" : "Play"
                    pixelSize: Theme.fontSizeLarge + 1
                    cornerRadius: Theme.radius
                    Layout.preferredWidth: 42
                    Layout.minimumWidth: 34
                    implicitHeight: 38
                    idleBg: Theme.surfaceActive
                    idleFg: Theme.accent
                    hoverBg: Theme.surfaceOverlay
                    onClicked: {
                        if (root.playing)
                            root.player?.pause();
                        else
                            root.player?.play();
                    }
                }
                AppButton {
                    enabled: root.player?.canGoNext ?? false
                    tooltipText: "Next track"
                    icon: Icons.arrowRight
                    pixelSize: Theme.fontSizeLarge
                    Layout.preferredWidth: 32
                    Layout.minimumWidth: 24
                    implicitHeight: 32
                    onClicked: root.player?.next()
                }
                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }
            }

            // LRCLIB lyrics — always-visible 3-line window (previous dim / current accent / next).
            // Synced lines click-to-seek; fixed 64px keeps implicitHeight exact.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.hasLyrics ? 64 : 0
                Layout.minimumHeight: 0
                visible: root.hasLyrics
                clip: true

                Column {
                    anchors.fill: parent
                    spacing: 0

                    Repeater {
                        model: 3
                        delegate: Item {
                            width: parent.width
                            height: 24

                            property int lineOffset: index - 1
                            property string lineText: Lyrics.status === "ready-synced"
                                ? root.lyricLineAt(lineOffset) : root.plainWindow()[index]
                            property real lineTime: Lyrics.status === "ready-synced"
                                ? root.lyricTimeAt(lineOffset) : -1

                            Label {
                                anchors.fill: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                text: parent.lineText
                                color: index === 1 ? Theme.accent : (index === 0 ? Theme.fgDim : Theme.fg)
                                font.bold: index === 1
                                font.pixelSize: index === 1 ? Theme.fontSize + 1 : Theme.fontSize - 1
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                preventStealing: false
                                propagateComposedEvents: true
                                enabled: parent.lineTime >= 0 && (root.player?.canSeek ?? false)
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.player.position = parent.lineTime
                            }
                        }
                    }
                }
            }
        }
    }

    // No player state — fill parent so empty state also expands
    // vertically (e.g. app-launcher left pane) instead of staying 170px.
    Item {
        visible: root.player === null
        anchors.fill: parent
        Label {
            anchors.centerIn: parent
            text: "No player found"
            font.pixelSize: Theme.fontSize
            color: Theme.fgDim
        }
    }
}
