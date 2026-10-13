import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.theme
import qs.services
import qs.widgets.shared

// Mini media pill — app icon + play state + track title for the most
// relevant player (playing-else-first, MediaWidget parity). Hidden when
// no player has anything to show. Hover (dwell) / click pulses the full
// player island; middle-click toggles playback. Hosted as a standalone
// pill outside the default bar (Bar.qml, right-chained like the
// recording pill).
Rectangle {
    id: root

    // ---- media player state (playing-else-first) ----
    // Pass 1: active playing player. Pass 2: first with a title (so the
    // pill hides instead of showing an empty entry when nothing plays).
    readonly property var firstPlayable: {
        Mpris.players.values;   // reactive dep
        const vals = Mpris.players.values;
        for (const p of vals) {
            // touch reactive props so title / play-state changes re-fire
            const _t = p.trackTitle;
            const _s = p.playbackState;
            const _p = p.isPlaying;
            if (_p === true || _s === MprisPlaybackState.Playing)
                return p;
        }
        for (const p of vals) {
            const _t = p.trackTitle;
            const _s = p.playbackState;
            const _p = p.isPlaying;
            if ((_t ?? "").trim() !== "")
                return p;
        }
        return null;
    }
    readonly property bool hasPlayable: root.firstPlayable !== null
    readonly property bool isPlaying: {
        const p = root.firstPlayable;
        if (!p)
            return false;
        if (p.isPlaying !== undefined)
            return p.isPlaying;
        return p.playbackState === MprisPlaybackState.Playing;
    }
    readonly property string playerTitleText: {
        const p = root.firstPlayable;
        if (!p)
            return "";
        return p.trackTitle ?? "";
    }

    // Resolve the player's app icon via its MPRIS DesktopEntry, with identity
    // fallbacks, then through Quickshell.iconPath() into an image:// URL —
    // IconImage.source is a plain Image URL alias, so bare theme names
    // never load. Missing icons yield "" and the pill falls back to its
    // music-note glyph.
    readonly property string playerIconSource: {
        const p = root.firstPlayable;
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
        // Lowercase identity usually matches (e.g. "Spotify" -> "spotify");
        // dbus suffix as last resort.
        if (raw === "" && id !== "")
            raw = id.toLowerCase();
        if (raw === "") {
            const bus = String(p.dbusName ?? "").trim();
            if (bus !== "") {
                const tail = bus.split(".").pop();
                if (tail)
                    raw = tail.toLowerCase();
            }
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
    readonly property string playerTooltip: {
        const p = root.firstPlayable;
        if (!p)
            return "";
        const id = (p.identity ?? "").trim();
        const artist = (p.trackArtist ?? "").trim();
        const title = (p.trackTitle ?? "").trim();
        const track = artist !== "" ? artist + " — " + title : title;
        return (id !== "" ? id : "Player") + (track !== "" ? "\n" + track : "");
    }

    height: Theme.sidePillHeight
    implicitWidth: root.hasPlayable ? contentRow.implicitWidth + Theme.islandPad * 2 : 0
    width: implicitWidth
    radius: Theme.radius
    color: playerHover.hovered ? Theme.surfaceHover : Theme.surfaceActive

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        // app icon (fallback: music-note glyph for the empty state)
        Item {
            width: 14
            height: 14
            anchors.verticalCenter: parent.verticalCenter

            IconImage {
                id: playerIcon
                anchors.fill: parent
                source: root.playerIconSource
                visible: status === Image.Ready && root.playerIconSource !== ""
                asynchronous: true
            }
            Text {
                visible: !playerIcon.visible
                anchors.centerIn: parent
                text: "󰎈"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }

        // play/pause state glyph
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.isPlaying ? "" : ""
            color: root.isPlaying ? Theme.accent : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
        }

        Text {
            id: playerTitle
            anchors.verticalCenter: parent.verticalCenter
            text: root.playerTitleText
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 180)
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    AppTooltip {
        visible: playerHover.hovered && root.playerTooltip !== ""
        text: root.playerTooltip
        delay: 500
    }

    // Hover dwell (Settings.revealInPressure, 0 = instant) so
    // brushing the cursor across the bar doesn't pulse the
    // island by accident.
    Timer {
        id: playerDwellTimer
        interval: Settings.revealInPressure
        repeat: false
        onTriggered: {
            if (playerHover.hovered && root.firstPlayable)
                BarState.activate("player", 2500);
        }
    }

    HoverHandler {
        id: playerHover
        onHoveredChanged: {
            if (playerHover.hovered && root.firstPlayable) {
                if (Settings.revealInPressure <= 0)
                    BarState.activate("player", 2500);
                else
                    playerDwellTimer.restart();
            } else {
                playerDwellTimer.stop();
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (!root.firstPlayable)
                return;
            if (mouse.button === Qt.MiddleButton) {
                root.firstPlayable.togglePlaying();
                return;
            }
            BarState.activate("player", 2500);
        }
    }
}
