import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.theme
import qs.services
import qs.widgets.shared

// Mini media pill (icon, play state, track title) for the best player, right-chained like the
// recording pill; hover/click pulses the player island, middle-click toggles playback.
Rectangle {
    id: root

    property string monitorName: ""

    // search-open expansion (Bar.qml binds this): artist row unfolds off the
    // band beside the launcher island, and the title's elide cap lifts
    property bool expanded: false
    readonly property bool growUp: !Settings.barOrientation
    readonly property real extraGap: Theme.spacing / 2
    readonly property string expandedArtist: (root.firstPlayable?.trackArtist ?? "").trim()

    // ---- media player state (playing-else-first) ----
    // Pass 1: active playing player. Pass 2: first with a title, so the pill hides when idle.
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

    // Icon via the MPRIS DesktopEntry with identity fallbacks, then Quickshell.iconPath() into
    // an image:// URL (bare theme names never load); missing falls back to the music note.
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

    height: root.expanded && root.expandedArtist !== ""
        ? Theme.sidePillHeight + root.extraGap + artistLine.implicitHeight
        : Theme.sidePillHeight
    Behavior on height { Anim {} }
    implicitWidth: root.hasPlayable ? contentRow.implicitWidth + Theme.islandPad * 2 : 0
    width: implicitWidth
    radius: Theme.radius
    color: playerHover.hovered ? Theme.surfaceHover : Theme.surfaceActive

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim.fastEffects
        }
    }

    Row {
        id: contentRow
        anchors.horizontalCenter: parent.horizontalCenter
        // pinned inside the pill's compact band so the artist row hangs off it
        y: growUp ? parent.height - Theme.sidePillHeight + (Theme.sidePillHeight - height) / 2
                  : (Theme.sidePillHeight - height) / 2
        spacing: Theme.spacing

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
                font.pixelSize: Theme.fontSize
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
            width: Math.min(implicitWidth, root.expanded ? 260 : 180)
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    Text {
        id: artistLine
        visible: root.expandedArtist !== ""
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { Anim { type: Anim.FastEffects } }
        x: Theme.islandPad
        width: Math.max(0, root.width - Theme.islandPad * 2)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        y: growUp ? contentRow.y - height - root.extraGap
                  : contentRow.y + contentRow.height + root.extraGap
        text: root.expandedArtist
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
    }

    AppTooltip {
        visible: playerHover.hovered && root.playerTooltip !== ""
        text: root.playerTooltip
        delay: 500
    }

    // Hover dwell so brushing the bar does not pulse; while hovered the pulse is pinned
    // (holdMs 0), and hover-out hands back to the standard 2.5s pulse.
    Timer {
        id: playerDwellTimer
        interval: Settings.revealInPressure
        repeat: false
        onTriggered: {
            if (playerHover.hovered && root.firstPlayable)
                BarState.activate("player", 0, root.monitorName);
        }
    }

    HoverHandler {
        id: playerHover
        onHoveredChanged: {
            if (playerHover.hovered && root.firstPlayable) {
                if (Settings.revealInPressure <= 0)
                    BarState.activate("player", 0, root.monitorName);
                else
                    playerDwellTimer.restart();
            } else {
                playerDwellTimer.stop();
                if (BarState.isOpenFor("player", root.monitorName))
                    BarState.activate("player", 2500, root.monitorName);
            }
        }
    }

    // Re-pin while hovered: a mid-hover track-change pulse or click arms a
    // 2.5s hold timer that would otherwise close the island under the cursor.
    Connections {
        target: BarState
        function onHoldTimersChanged() {
            if (playerHover.hovered && BarState.isOpenFor("player", root.monitorName))
                BarState.activate("player", 0, root.monitorName);
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
            BarState.activate("player", 2500, root.monitorName);
        }
    }
}
