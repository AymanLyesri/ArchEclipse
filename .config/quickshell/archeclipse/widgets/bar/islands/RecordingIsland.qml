import QtQuick
import qs.theme
import qs.services
import qs.widgets.bar.islands
import qs.widgets.shared

// Recording island — idle: 56px stadium with two start-mode buttons
// (fullscreen / area), revealed by hovering the empty right pill zone —
// widths only ever change on state transitions (hover-coupled resizes
// churn hover re-evaluation: probe-proven flap). Starting shows a
// spinner (pinned open via ScreenRecorder.starting) until wf-recorder is
// actually up, then the pulsing-dot pill + "Recording" + TRUE elapsed
// timer (mm:ss since the recording actually started, via
// ScreenRecorder.startTimestamp). Clicking while recording stops it and
// morphs back. When not recording, elapsed resets to 00:00.
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

    // Idle hugs its content (8px dot + two 20px buttons + 16px gutters) so
    // the gutters can never go asymmetric; recording/loading is a fixed
    // 96px pill so the elapsed text doesn't resize it. Deliberately NO
    // hover-driven width animation: a resize tied to hover churns hover
    // re-evaluation every animated frame and the reveal flaps on/off
    // forever (probe-proven limit cycle). Widths change only on state
    // transitions.
    property real pillW: root.recording || root.starting ? 96 : idleRow.implicitWidth + 16
    Behavior on pillW {
        Anim {
            duration: Theme.anim.fastSpatial
        }
    }
    implicitWidth: pillW
    implicitHeight: clip.height
    width: implicitWidth
    height: implicitHeight

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
        expand: root.expand
        contentHeight: Theme.sidePillHeight

        Rectangle {
            width: root.pillW
            height: Theme.sidePillHeight
            radius: root.recording ? Theme.radius : height / 2
            Behavior on radius {
                Anim {
                    duration: Theme.anim.fastSpatial
                }
            }
            color: Theme.surface

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
                    tooltipText: "Record workspace · <b>SUPER+SHIFT+R</b>"
                    onClicked: ScreenRecorder.toggleRecording("now", root.monitorName)
                }
                ModeButton {
                    glyph: "\u{F125}"   // nf-fa-crop — area record
                    tooltipText: "Record area · <b>SUPER+CTRL+SHIFT+R</b>"
                    onClicked: ScreenRecorder.toggleRecording("area", root.monitorName)
                }
            }

            // loading circle: a start click keeps the piece visible (Bar pins
            // it open via ScreenRecorder.starting) and shows a spinner until
            // the recorder is actually up
            AppProgress {
                anchors.centerIn: parent
                visible: root.starting
                status: "loading"
                variant: "spinner"
                width: 14
                height: 14
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
