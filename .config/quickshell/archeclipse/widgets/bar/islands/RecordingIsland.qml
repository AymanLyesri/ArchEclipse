import QtQuick
import qs.theme
import qs.services
import qs.widgets.bar.islands
import qs.widgets.shared

// Recording island — idle: 24px stadium with two start-mode buttons
// (fullscreen / area), revealed by hovering the empty right pill zone —
// widths only ever change on state transitions (hover-coupled resizes
// churn hover re-evaluation: probe-proven flap). Starting shows a
// spinner (pinned open via ScreenRecorder.starting) until wf-recorder is
// actually up, then the pulsing-dot pill + "Recording" + TRUE elapsed
// timer (mm:ss since the recording actually started, via
// ScreenRecorder.startTimestamp). Clicking while recording stops it and
// morphs back. When not recording, elapsed resets to 00:00.
//
// Launcher expansion (Bar.qml binds `expanded` to the monitor's search
// state, weather-pill recipe): the pill grows vertically off the band
// (away from the screen edge) and the modes re-represent as labeled
// IslandActionRow rows — compact = idle modes as stadium buttons;
// expanded = each mode as its own row, and an active recording becomes a
// Stop row (same toggle handler, clearer representation; the band keeps
// the dot/timer pill). ONE card owns the whole grown body: the band and
// the rows share a single surface, so the expanded pill reads as one card
// rather than a chip plus a sheet. No hover machinery: rows are
// click-only ModeButton/label cells.
Item {
    id: root
    // Expand driver: 0 -> 1 on creation unfolds the body; the Bar
    // exit driver plays 1 -> 0 on close before swapping content.
    property real expand: 0
    Component.onCompleted: expand = 1

    property string monitorName: ""
    property string elapsed: "00:00"
    readonly property bool recording: ScreenRecorder.isRecording && ScreenRecorder.targetMonitors.includes(monitorName)
    // start intent in flight: spinner state until wf-recorder is actually up
    readonly property bool starting: ScreenRecorder.starting && ScreenRecorder.targetMonitors.includes(monitorName)

    // ---- launcher expansion stem (cf. WeatherButton) ----
    property bool expanded: false
    // bottom-oriented bars grow upward instead of off-screen
    readonly property bool growUp: !Settings.barOrientation
    readonly property real extraGap: Theme.spacing / 2
    // rows exist whenever expanded (any live state except starting): idle
    // shows the two mode rows, an active recording shows one Stop row
    readonly property int expandedRowCount: root.expanded && !root.starting ? (root.recording ? 1 : 2) : 0
    property real extraT: root.expandedRowCount > 0 ? 1 : 0
    Behavior on extraT {
        Anim {}
    }
    // rows block that the card carries beyond the band: rows plus the
    // card's 4px outer padding (the band-side gap is extraGap)
    readonly property real rowsBlockW: recRows.implicitWidth + 16
    readonly property real rowsBlockH: recRows.implicitHeight + 4
    // band offset while grown: clears the stacked rows above/below
    readonly property real extraH: root.extraT * (root.extraGap + root.rowsBlockH)
    // the card IS the island: band + rows, one background
    implicitHeight: Theme.sidePillHeight + root.extraH
    height: implicitHeight
    width: Math.max(root.pillW, root.expandedRowCount > 0 ? root.rowsBlockW : 0)
    Behavior on width {
        Anim {
            duration: Theme.anim.fastSpatial
        }
    }

    // Idle hugs its content (8px dot + two 20px buttons + 16px gutters) so
    // the gutters can never go asymmetric; recording/loading is a fixed
    // 96px pill so the elapsed text doesn't resize it. Deliberately NO
    // hover-driven width animation: a resize tied to hover churns hover
    // re-evaluation every animated frame and the reveal flaps on/off
    // forever (probe-proven limit cycle). Widths change only on state
    // transitions.
    readonly property real idleW: idleRow.implicitWidth + 16
    property real pillW: root.recording || root.starting ? 96 : idleW
    Behavior on pillW {
        Anim {
            duration: Theme.anim.fastSpatial
        }
    }

    MouseArea {
        id: idleMouse
        anchors.fill: parent
        // isRecording lags reality ~2s (pgrep poll): one honest click per
        // intent; rapid re-clicks inside the settle window re-issue toggles.
        // `starting` = start already in flight (would double-start; no
        // cancel path) — ignored. Recording click stops it; idle click on
        // the padding (outside the mode buttons) starts fullscreen.
        // NO hoverEnabled here: hover-coupled MouseAreas churned the hover
        // state and made the reveal flap on/off (probe-proven).
        onClicked: if (!root.starting)
            ScreenRecorder.toggleRecording("now", root.monitorName)
    }

    IslandExpandClip {
        id: clip
        // opposite edge pinned to the band: the card wipes away from the
        // screen edge on bottom bars (opposite on top bars)
        y: root.growUp ? root.height - clip.height : 0
        expand: root.expand
        contentHeight: root.implicitHeight

        Item {
            id: body
            width: root.width
            height: root.implicitHeight
            // band stays parked at its edge while the card grows
            anchors.bottom: root.growUp ? parent.bottom : undefined
            anchors.top: root.growUp ? undefined : parent.top

            // ONE background for the whole island: band + rows share it, so
            // the expanded stack reads as one card, not a chip plus a sheet
            Rectangle {
                anchors.fill: parent
                // stadium only while it is a bare band; the grown card is a
                // rounded card (never radius == height/2, which a tall card
                // would bow into a lozenge)
                radius: root.recording || root.starting || root.extraT > 0 ? Theme.radius : Theme.sidePillHeight / 2
                Behavior on radius {
                    Anim {
                        duration: Theme.anim.fastSpatial
                    }
                }
                color: Theme.surface
            }

            // band: dot + elapsed (recording), dot + mode buttons (idle), or
            // the start spinner — parked at the band edge
            Item {
                id: band
                width: parent.width
                height: Theme.sidePillHeight
                y: root.growUp ? parent.height - height : 0

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacing
                    visible: root.recording

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: width / 2
                        color: Theme.danger
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: 1
                                to: 0.3
                                duration: Theme.anim.large
                            }
                            NumberAnimation {
                                from: 0.3
                                to: 1
                                duration: Theme.anim.large
                            }
                        }
                    }
                    Text {
                        text: root.elapsed
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }

                // idle stadium: recording indicator on the left, mode buttons
                // after it — uniform cells, centered in the hugging pill
                Row {
                    id: idleRow
                    anchors.centerIn: parent
                    spacing: 4
                    visible: !root.recording && !root.starting

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: width / 2
                        color: Theme.danger
                    }

                    ModeButton {
                        glyph: "\u{F065}"   // nf-fa-expand — fullscreen record
                        // park while the launcher expansion re-represents
                        // the modes as rows; return at the flip, not at the
                        // end of the geometry unwind — a late return reads as
                        // the band clipping to a dot width and then popping
                        // back
                        visible: !root.expanded
                        tooltipText: "Record workspace · <b>SUPER+SHIFT+R</b>"
                        onClicked: ScreenRecorder.toggleRecording("now", root.monitorName)
                    }
                    ModeButton {
                        glyph: "\u{F125}"   // nf-fa-crop — area record
                        visible: !root.expanded
                        tooltipText: "Record area · <b>SUPER+CTRL+SHIFT+R</b>"
                        onClicked: ScreenRecorder.toggleRecording("area", root.monitorName)
                    }
                }

                // loading circle: a start click keeps the piece visible (Bar
                // pins it open via ScreenRecorder.starting) and shows a
                // spinner until the recorder is actually up
                AppProgress {
                    anchors.centerIn: parent
                    visible: root.starting
                    status: "loading"
                    variant: "spinner"
                    width: 14
                    height: 14
                }
            }

            // ---- launcher-expanded rows: modes re-represented as rows on
            // the SAME card as the band ----
            // Away from the screen edge: above the band on bottom-oriented
            // bars, below it on top bars — 4px card padding at the outer end.
            // The reveal rides extraT (FastEffects fade, like the weather
            // stats rows); rows stay laid out while extraT > 0 so the
            // width/height stems glide through fade-out instead of yanking.
            // Handlers are the SAME actions the band buttons run —
            // representation only, no new actions. Background-less rows
            // (IslandActionRow) keep the card's single surface intact.
            Column {
                id: recRows
                x: (parent.width - width) / 2
                y: root.growUp ? 4 : Theme.sidePillHeight + root.extraGap
                visible: root.extraT > 0
                // fade rides its OWN fast stem (like the weather stats rows),
                // never the spatial extraT curve — opacity tracking the
                // geometry animation gates the rows on the pill's full growth
                // and reads as a delay
                opacity: root.expandedRowCount > 0 ? 1 : 0
                Behavior on opacity {
                    Anim { type: Anim.FastEffects }
                }
                spacing: root.extraGap

                IslandActionRow {
                    visible: !root.recording && !root.starting
                    glyph: "\u{F065}"   // nf-fa-expand — fullscreen record
                    label: "Fullscreen"
                    tooltipText: "Record workspace · <b>SUPER+SHIFT+R</b>"
                    onActivated: ScreenRecorder.toggleRecording("now", root.monitorName)
                }
                IslandActionRow {
                    visible: !root.recording && !root.starting
                    glyph: "\u{F125}"   // nf-fa-crop — area record
                    label: "Area"
                    tooltipText: "Record area · <b>SUPER+CTRL+SHIFT+R</b>"
                    onActivated: ScreenRecorder.toggleRecording("area", root.monitorName)
                }
                IslandActionRow {
                    visible: root.recording
                    glyph: "\u{F04D}"   // nf-fa-stop — stop record
                    label: "Stop"
                    tooltipText: "Stop recording"
                    onActivated: ScreenRecorder.toggleRecording("now", root.monitorName)
                }
            }
        }
    }

    function formatElapsed(ms) {
        const total = Math.max(0, Math.floor(ms / 1000));
        const m = Math.floor(total / 60).toString().padStart(2, "0");
        const s = (total % 60).toString().padStart(2, "0");
        return m + ":" + s;
    }

    // icon cells are the shared ModeButton (qs.widgets.bar.islands): glyph
    // only, no hover machinery — hover-toggled feedback inside the island
    // churned the bar hot-zone hover re-eval (probe-proven)

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // Real elapsed duration since recording start.
            if (ScreenRecorder.isRecording) {
                root.elapsed = root.formatElapsed(Date.now() - ScreenRecorder.startTimestamp);
            } else {
                root.elapsed = "00:00";
            }
        }
    }
}
