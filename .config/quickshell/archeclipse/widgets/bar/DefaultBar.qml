import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.theme
import qs.services
import qs.widgets.bar
import qs.widgets.shared
import qs.widgets.weather

// Center section (ex-Information) is inlined here directly:
// weather + resources on the left; center rectangle with
// bandwidth | control panel | clock; player pill first on the right,
// then battery/brightness/volume/tray.
// Top row holds all content; the workspace strip sits at the very bottom,
// stretched across the full bar width.
Column {
    id: root
    spacing: 4

    // ---- media player state (ex-Information firstPlayable logic) ----
    readonly property var firstPlayable: {
        Mpris.players.values;   // reactive dep
        for (const p of Mpris.players.values) {
            // touch reactive props so title / play-state changes re-fire
            const _t = p.trackTitle;
            const _s = p.playbackState;
            if ((_t ?? "").trim() !== "" || _s === MprisPlaybackState.Playing)
                return p;
        }
        return null;
    }
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

    // Fixed-width dynamic speed: always 4 chars (3-char numeric + 1-char
    // unit that scales B/K/M/G), so the bandwidth cell never shifts width
    // as speeds change. Monospace font keeps every string the same width.
    function fmtSpeed(bps) {
        if (bps < 1000)
            return String(Math.round(bps)).padStart(3, " ") + "B";
        const kb = bps / 1024;
        if (kb < 10)
            return kb.toFixed(1) + "K";
        if (kb < 1000)
            return String(Math.round(kb)).padStart(3, " ") + "K";
        const mb = kb / 1024;
        if (mb < 10)
            return mb.toFixed(1) + "M";
        if (mb < 1000)
            return String(Math.round(mb)).padStart(3, " ") + "M";
        const gb = mb / 1024;
        if (gb < 10)
            return gb.toFixed(1) + "G";
        return String(Math.round(gb)).padStart(3, " ") + "G";
    }

    Item {
        id: topRow
        // Both side sections count as wide as the wider one, so the
        // centered pill always keeps at least Theme.spacing clearance
        // from either side instead of clipping into the wider section.
        // The weather button stretches to absorb any slack on the left.
        readonly property real leftMinWidth: weatherButton.implicitWidth + Theme.spacing + resourceMonitor.implicitWidth
        readonly property real rightMinWidth: utilities.implicitWidth
        readonly property real sideWidth: Math.max(leftMinWidth, rightMinWidth)
        implicitWidth: 2 * sideWidth + centerPill.width + Theme.spacing * 2
        width: implicitWidth
        height: Theme.barContentHeight

        // Center rectangle — bandwidth on the left, control panel
        // button dead-center, clock on the right.
        Rectangle {
            id: centerPill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: centerRow.implicitWidth + 20
            height: Theme.barContentHeight
            radius: Theme.radius
            color: Theme.surfaceActive

            Row {
                id: centerRow
                anchors.centerIn: parent
                spacing: Theme.spacing
                height: parent.height
                // Equal-width side cells so the control button stays
                // dead-center relative to the whole bar even when
                // bandwidth and clock text widths differ.
                readonly property real sideCellWidth: Math.max(bandwidthRow.implicitWidth, clockItem.width)

                // bandwidth compact (up/down from SysInfo loop) — left
                Item {
                    width: centerRow.sideCellWidth
                    height: parent.height
                    Row {
                        id: bandwidthRow
                        spacing: 4
                        anchors.centerIn: parent
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.fmtSpeed(SysInfo.bandwidth[0] * 1024)
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ""
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.fmtSpeed(SysInfo.bandwidth[1] * 1024)
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ""
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }
                }

                // control panel toggle — center
                ControlPanelButton {
                    id: centerButton
                    anchors.verticalCenter: parent.verticalCenter
                }

                // clock — right, same cell width as bandwidth side
                Item {
                    width: centerRow.sideCellWidth
                    height: parent.height
                    Clock {
                        id: clockItem
                        anchors.centerIn: parent
                        hoverColor: "transparent"
                    }
                }
            }
        }

        // left zone — fixed sideWidth; weather stretches into the slack
        Item {
            id: leftZone
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: topRow.sideWidth
            height: parent.height

            RowLayout {
                anchors.fill: parent
                spacing: Theme.spacing

                ResourceMonitor {
                    Layout.fillWidth: true
                }
                WeatherButton {
                    Layout.fillWidth: true
                }
            }
        }

        // right zone — fixed sideWidth like the left, content right-aligned
        // so the center pill keeps symmetric spacing on both sides
        Item {
            id: rightZone
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: topRow.sideWidth
            height: parent.height

            Row {
                id: utilities
                spacing: Theme.spacing
                height: parent.height
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                // media pill (app icon + track title; hover/click pulses the
                // full player island) — first on the right
                Rectangle {
                    id: playerPill
                    visible: root.firstPlayable !== null
                    width: visible ? contentRow.width + 16 : 0
                    height: Theme.barContentHeight
                    radius: Theme.radius
                    color: playerHover.hovered ? Theme.surfaceHover : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

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

                Battery {}
                Brightness {}
                Volume {}
                Tray {}
            }
        }
    } // topRow

    // bottom workspace strip — full width of the bar content
    Workspaces {
        width: topRow.implicitWidth
    }
}
