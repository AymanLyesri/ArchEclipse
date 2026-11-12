import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.theme
import qs.services
import qs.widgets.shared

// Media Widget: spinning vinyl left, track/source/transport/seek right, collapsible
// Lyrics + Equalizer shelf underneath. Height follows the content so the shelf can open.
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    implicitWidth: 400
    implicitHeight: Math.round(body.implicitHeight + Theme.pad * 2)

    // Selection is shared with the bar pill (PlayerFocus): a pin wins, then whatever plays,
    // then the player that last played, so pausing does not swap the card for an idle one.
    readonly property var playersList: PlayerFocus.players
    readonly property var orderedPlayers: PlayerFocus.players
    readonly property var player: PlayerFocus.current

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

    // Circular disc scaled off the card width so the panel and the narrow right column agree.
    readonly property int discSize: Math.round(Math.max(84, Math.min(112, root.width * 0.28)))
    // Five bands at -12..+12 dB, neutral 0 marked at the centre by AppSlider itself.
    property real eqBass: 0
    property real eqLowMid: 0
    property real eqMid: 0
    property real eqHighMid: 0
    property real eqTreble: 0

    // LRCLIB lyrics — a 3-line window (previous dim / current accent / next plain).
    function fetchLyrics() {
        if (root.player === null)
            return;
        Lyrics.positionSec = root.player?.position ?? 0;
        Lyrics.fetchFor(root.artist, root.title, root.album,
            Math.round(root.player?.length ?? 0));
    }

    // True once LRCLIB returns usable lyric content; the shelf shows a hint otherwise.
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

    // Track identity change → refetch lyrics (fetchLyrics self-guards).
    onTitleChanged: root.fetchLyrics()
    onArtistChanged: root.fetchLyrics()
    onAlbumChanged: root.fetchLyrics()

    // Quickshell only pushes position on nonlinear jumps, so poll while a player exists
    // (docs-sanctioned positionChanged()) to keep the time label, bar and lyrics in sync.
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

    // ----- collapsible shelf -----
    property bool detailsOpen: false
    property int detailsTab: 0
    readonly property int lyricLineHeight: Theme.fontSize + 9
    readonly property int lyricsHeight: root.lyricLineHeight * 3
    readonly property int equalizerHeight: Math.round(Theme.fontSize * 10)
    property real detailsHeight: root.detailsOpen ? (root.detailsTab === 0 ? root.lyricsHeight : root.equalizerHeight) : 0
    readonly property var eqBands: [
        {
            key: "eqBass",
            label: "Bass"
        },
        {
            key: "eqLowMid",
            label: "Low-Mid"
        },
        {
            key: "eqMid",
            label: "Mid"
        },
        {
            key: "eqHighMid",
            label: "High-Mid"
        },
        {
            key: "eqTreble",
            label: "Treble"
        }
    ]
    function gainLabel(v) {
        const n = Math.round((Number(v) || 0) * 2) / 2;
        if (n === 0)
            return "0";
        return (n > 0 ? "+" : "") + n;
    }
    Behavior on detailsHeight {
        Anim {
            type: Anim.FastSpatial
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        clip: true
        // Media card: raised plate with the cover bleeding through at low opacity, so the
        // artwork itself supplies the depth. No outline.
        color: Theme.surfaceRaised
        visible: root.player !== null

        AppImage {
            anchors.fill: parent
            source: root._lastCover || ""
            opacity: 0.12
            visible: root._lastCover !== ""
        }

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: Theme.spaceSm

            // ---- player switcher: every player, playing one first ----
            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                visible: root.orderedPlayers.length > 1
                clip: true
                contentWidth: chipRow.width
                contentHeight: 22
                flickableDirection: Flickable.HorizontalFlick

                Row {
                    id: chipRow
                    height: 22
                    spacing: Theme.spaceXs

                    Repeater {
                        model: root.orderedPlayers
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool current: root.player === modelData
                            readonly property bool rowPlaying: modelData.isPlaying === true

                            width: chipText.implicitWidth + (rowPlaying ? 14 : 0) + Theme.spaceSm * 2
                            height: 20
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
                                onClicked: PlayerFocus.togglePin(modelData)
                            }
                        }
                    }
                }
            }

            // ---- identity: vinyl disc left, track / source / transport right ----
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceMd

                // Circular disc: cover clipped to a circle and rotated as one plate, so the
                // square art never shows a corner; grooves and spindle read as vinyl.
                Item {
                    Layout.preferredWidth: root.discSize
                    Layout.preferredHeight: root.discSize
                    Layout.alignment: Qt.AlignVCenter

                    // ClippingRectangle, not Rectangle.clip: the latter clips a square and
                    // only rounds the fill, which left the spinning cover with sharp corners.
                    ClippingRectangle {
                        id: plate
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.surfaceSunken

                        Item {
                            id: spin
                            // Oversized past √2 so the rotating square always covers the circle.
                            width: Math.ceil(plate.width * 1.45)
                            height: width
                            anchors.centerIn: parent
                            visible: root._lastCover !== ""

                            AppImage {
                                anchors.fill: parent
                                radius: 0
                                source: root._lastCover || ""
                            }

                            // Tint: the art reads as a disc surface, not a thumbnail.
                            Rectangle {
                                anchors.fill: parent
                                color: Theme.rgba(Theme.bg, 0.34)
                            }

                            // Disc speed ~18 s per turn; a timer (not an animator) so pausing
                            // holds the exact angle instead of snapping back to 0 on resume.
                            Timer {
                                interval: 33
                                repeat: true
                                running: root.player !== null && root.playing && Theme.anim.scale > 0
                                onTriggered: spin.rotation = (spin.rotation + 0.7) % 360
                            }
                        }

                        Label {
                            anchors.centerIn: parent
                            visible: root._lastCover === ""
                            text: Icons.music
                            color: Theme.fgDim
                            font.pixelSize: Theme.fs(2.2)
                        }

                        Repeater {
                            model: [0.94, 0.82, 0.7, 0.58]
                            delegate: Rectangle {
                                required property real modelData
                                anchors.centerIn: parent
                                width: parent.width * modelData
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.width: 1
                                border.color: Theme.rgba(Theme.bg, 0.4)
                                visible: root._lastCover !== ""
                            }
                        }

                        // Centre label + spindle.
                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.round(plate.width * 0.3)
                            height: width
                            radius: width / 2
                            color: Theme.rgba(Theme.bg, 0.55)
                            visible: root._lastCover !== ""

                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.round(parent.width * 0.22)
                                height: width
                                radius: width / 2
                                color: Theme.rgba(Theme.fg, 0.35)
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.rgba(Theme.fg, 0.1)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Theme.spaceSm

                    // Title / artist top-left, source app top-right.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceSm

                        ColumnLayout {
                            id: textLayer
                            Layout.fillWidth: true
                            spacing: 0
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
                        }

                        Item {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            Layout.alignment: Qt.AlignTop

                            IconImage {
                                id: appIconImg
                                anchors.fill: parent
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
                                font.pixelSize: Theme.fs(1.2)
                            }
                            AppTooltip {
                                visible: iconTip.hovered && root.player !== null
                                text: root.player?.identity ?? ""
                            }
                            HoverHandler {
                                id: iconTip
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 0
                    }

                    // ---- transport: centred, the play button reads as the primary action ----
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

                    // ---- position: elapsed and total bracket the scrub bar beneath the controls ----
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceSm

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
                            Layout.preferredHeight: Math.max(12, Theme.fontSize)

                            Rectangle {
                                id: progBg
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4
                                radius: 2
                                color: Theme.track

                                property real frac: root.scrubbing ? (root.scrubPos / Math.max(1, root.player?.length ?? 1)) : (root.player?.length ?? 0) > 0 ? (root.player?.position ?? 0) / root.player.length : 0
                                property real fill: Math.max(0, Math.min(1, frac))

                                Rectangle {
                                    width: progBg.width * progBg.fill
                                    height: parent.height
                                    radius: 2
                                    color: Theme.accent
                                }
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

                        Label {
                            Layout.alignment: Qt.AlignVCenter
                            text: root.fmt(root.player?.length ?? 0)
                            color: Theme.fgDim
                            font.pixelSize: Theme.typeCaption
                            font.preferShaping: false
                        }
                    }
                }
            }

            // ---- shelf: collapsed by default; tabs pick Lyrics or Equalizer ----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spaceSm

                    AppSegmentedControl {
                        id: tabBar
                        model: [
                            {
                                label: "Lyrics",
                                icon: Icons.lyrics
                            },
                            {
                                label: "Equalizer",
                                icon: Icons.equalizer
                            }
                        ]
                        currentIndex: root.detailsTab
                        pixelSize: Theme.typeCaption
                        cellHPadding: Theme.spaceSm + 2
                        cellVPadding: Theme.spaceXs
                        onActivated: (index) => {
                            root.detailsTab = index;
                            root.detailsOpen = true;
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                    }

                    AppButton {
                        icon: root.detailsOpen ? Icons.chevronDown : Icons.chevronUp
                        tooltipText: root.detailsOpen ? "Hide lyrics and equalizer" : "Show lyrics and equalizer"
                        pixelSize: Theme.typeCaption
                        hPadding: Theme.spaceSm
                        implicitHeight: Math.max(24, Theme.fontSize + 10)
                        onClicked: root.detailsOpen = !root.detailsOpen
                    }
                }

                Item {
                    id: detailsViewport
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.detailsHeight
                    clip: true

                    // Synced lines click-to-seek; the plain fallback follows position proportionally.
                    Item {
                        id: lyricsBody
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: root.detailsHeight
                        visible: root.detailsTab === 0 && root.detailsHeight > 0

                        Column {
                            anchors.fill: parent
                            spacing: 0
                            visible: root.hasLyrics

                            Repeater {
                                model: 3
                                delegate: Item {
                                    width: parent.width
                                    height: root.lyricLineHeight

                                    property int lineOffset: index - 1
                                    property string lineText: Lyrics.status === "ready-synced" ? root.lyricLineAt(lineOffset) : root.plainWindow()[index]
                                    property real lineTime: Lyrics.status === "ready-synced" ? root.lyricTimeAt(lineOffset) : -1

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

                        Label {
                            anchors.centerIn: parent
                            visible: !root.hasLyrics
                            text: Lyrics.status === "loading" ? "Fetching lyrics…" : "No lyrics for this track"
                            color: Theme.fgDim
                            font.pixelSize: Theme.typeLabel
                        }
                    }

                    // Five vertical bands, neutral 0 at the centre of each travel.
                    RowLayout {
                        id: equalizerBody
                        anchors.fill: parent
                        visible: root.detailsTab === 1 && root.detailsHeight > 0
                        spacing: Theme.spaceSm

                        Repeater {
                            model: root.eqBands
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: Theme.spaceXs

                                Label {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: root.gainLabel(root[modelData.key])
                                    color: Math.abs(root[modelData.key]) < 0.05 ? Theme.fgDim : Theme.accent
                                    font.pixelSize: Theme.typeCaption
                                    font.preferShaping: false
                                }
                                AppSlider {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 24
                                    orientation: Qt.Vertical
                                    from: -12
                                    to: 12
                                    stepSize: 1
                                    defaultValue: 0
                                    value: root[modelData.key]
                                    onMoved: root[modelData.key] = value
                                }
                                Label {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: modelData.label
                                    color: Theme.muted
                                    font.pixelSize: Theme.typeCaption
                                }
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
