import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
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

    // Natural size (single source of truth): consumers without a sized
    // parent (e.g. PlayerIsland) derive their size from these instead
    // of hardcoding width/height.
    implicitWidth: 400
    implicitHeight: (root.player !== null && root.hasLyrics) ? 242 : 170

    // Pick active player: the PLAYING one, else the first.
    // Mpris.players is an
    // UntypedObjectModel — access via .values for iteration.
    readonly property var playersList: Mpris.players.values ?? (Array.from ? Array.from(Mpris.players.values() ?? []) : [])
    readonly property var player: {
        for (const p of root.playersList) {
            if (p.isPlaying)
                return p;
        }
        return root.playersList.length > 0 ? root.playersList[0] : null;
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

    // Resolve the player's app icon via its MPRIS DesktopEntry (DefaultBar
    // playerIconSource parity) with identity fallbacks, then through
    // Quickshell.iconPath() into an image:// URL — IconImage.source is a
    // plain Image URL alias, so bare theme names never load (AppEntry
    // _iconSrc parity). Missing icons yield "" and the music-note glyph
    // fallback shows instead of the provider's missing-texture.
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

    // Title change → slide animation via MPRIS trackTitleChanged signal
    Connections {
        target: root.player
        function onTrackTitleChanged() {
            slideAnim.stop();
            textLayer.anchors.verticalCenterOffset = -12;
            slideAnim.to = 0;
            slideAnim.restart();
        }
    }

    // Track identity change → refetch lyrics (fetchLyrics self-guards
    // on lyricsOpen/player, so these are cheap when closed).
    onTitleChanged: root.fetchLyrics()
    onArtistChanged: root.fetchLyrics()
    onAlbumChanged: root.fetchLyrics()

    // Keep MPRIS position fresh: quickshell only pushes position on
    // nonlinear jumps, so poll while a player exists (docs-sanctioned
    // positionChanged() emission). Refreshes the time label, progress
    // ring and the lyrics highlighter below.
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
        radius: 8
        clip: true
        color: Theme.surface

        border.color: Theme.border
        visible: root.player !== null

        // Blurred background cover ("img" blurred layer)
        AppImage {
            anchors.fill: parent
            source: root._lastCover || ""

            opacity: 0.1
            visible: root._lastCover !== ""
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Top row: spinner cover art + title/artist + app icon
            Row {
                Layout.fillWidth: true
                spacing: 10

                // Spinning cover art thumbnail
                Rectangle {
                    id: coverBox
                    width: 64
                    height: 64
                    radius: 8
                    clip: true
                    color: Theme.bg

                    border.color: Theme.border

                    AppImage {
                        id: coverImg
                        anchors.fill: parent
                        source: root._lastCover || ""
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: 8
                    }
                    // spinning indicator (rotation while playing)
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        width: 10
                        height: 10
                        radius: 5
                        color: root.playing ? Theme.accent : Theme.fgDim
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                    }
                    // progress ring while playing (spinner visual)
                    Canvas {
                        id: ringCanvas
                        anchors.fill: parent
                        visible: root.playing
                        function redrawRing() {
                            if (!visible)
                                return;
                            const ctx = getContext("2d");
                            if (!ctx)
                                return;
                            ctx.reset();
                            const len = root.player ? root.player.length : 0;
                            const pos = root.player ? root.player.position : 0;
                            const frac = len > 0 ? pos / len : 0;
                            ctx.beginPath();
                            ctx.strokeStyle = Theme.accent;
                            ctx.lineWidth = 2;
                            ctx.arc(width / 2, height / 2, width / 2 - 4, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * frac);
                            ctx.stroke();
                        }
                        onVisibleChanged: if (visible)
                            redrawRing()
                        // periodic repaint while playing (avoids null-player Connections)
                        Timer {
                            interval: 1000
                            running: ringCanvas.visible
                            repeat: true
                            onTriggered: ringCanvas.redrawRing()
                        }
                    }
                }

                // Title / artist with slide transition.
                // Explicit width (cover + icon + spacing): the dead
                // Layout.fillWidth left this at 0 and no text showed.
                Item {
                    id: trackBlock
                    width: parent.width - 64 - 22 - 20
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
                            color: Theme.muted
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

                // App icon (DefaultBar parity: real theme icon via
                // DesktopEntry/identity lookup, music-note glyph fallback)
                Item {
                    width: 22
                    height: 64

                    IconImage {
                        id: appIconImg
                        anchors.centerIn: parent
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
                        text: ""  // music-note icon
                        color: Theme.fgDim
                        font.pixelSize: 18
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

            // LRCLIB lyrics — always-visible Spotify-style 3-line window
            // (previous dim / current accent / next plain). Synced lines
            // click-to-seek via absolute position write; plain fallback
            // shows a proportional window. Fixed 64px so the widget
            // implicitHeight stays exact (170 + 8 + 64 = 242).
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


            // Position/length + controls
            // RowLayout with compressible buttons + spacers: the 5-piece
            // controls row (pos, prev, play, next, len) cannot fit the
            // narrow panel at natural widths, so buttons/spacers shrink
            // to their minimums instead of painting past the parent.
            RowLayout {
                Layout.fillWidth: true
                spacing: 3

                Label {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.fmt(root.scrubbing ? root.scrubPos : (root.player?.position ?? 0))
                    color: Theme.fgDim
                    font.pixelSize: Theme.fontSize - 2
                    verticalAlignment: Text.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }

                // prev
                AppButton {
                    enabled: root.player?.canGoPrevious ?? false
                    icon: "\uf060"
                    pixelSize: 14
                    Layout.preferredWidth: 30
                    Layout.minimumWidth: 22
                    onClicked: root.player?.previous()
                }
                // play/pause
                AppButton {
                    enabled: root.player?.canPause ?? (root.player?.canPlay ?? false)
                    icon: root.playing ? "\uf04c" : "\uf04b"
                    pixelSize: 14
                    cornerRadius: 16
                    Layout.preferredWidth: 30
                    Layout.minimumWidth: 22
                    implicitHeight: 30
                    idleBg: Theme.surfaceActive
                    idleFg: Theme.accent
                    onClicked: {
                        if (root.playing)
                            root.player?.pause();
                        else
                            root.player?.play();
                    }
                }
                // next
                AppButton {
                    enabled: root.player?.canGoNext ?? false
                    icon: "\uf061"
                    pixelSize: 14
                    Layout.preferredWidth: 30
                    Layout.minimumWidth: 22
                    onClicked: root.player?.next()
                }

                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }

                Label {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.fmt(root.player?.length ?? 0)
                    color: Theme.fgDim
                    font.pixelSize: Theme.fontSize - 2
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Drag-scrubbable position slider
            Rectangle {
                id: progBg
                Layout.fillWidth: true
                Layout.minimumHeight: 6
                Layout.preferredHeight: 6
                height: 6
                radius: 3
                color: Theme.bg

                border.color: Theme.border

                property real frac: root.scrubbing ? (root.scrubPos / Math.max(1, root.player?.length ?? 1)) : (root.player?.length ?? 0) > 0 ? (root.player?.position ?? 0) / root.player.length : 0
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
