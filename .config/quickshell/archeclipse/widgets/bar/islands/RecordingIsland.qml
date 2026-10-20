import QtQuick
import qs.theme
import qs.services
import qs.widgets.bar.islands
import qs.widgets.shared

// Recording island — idle: circular record button (hover-revealed in the
// empty right pill zone); click starts the recording and the circle morphs
// into pulsing-dot pill + "Recording" + TRUE elapsed timer (mm:ss since the
// recording actually started, via ScreenRecorder.startTimestamp). Clicking
// while recording stops it and morphs back. When not recording, elapsed
// resets to 00:00.
Item {
    id: root
    // Expand driver: 0 -> 1 on creation unfolds the body; the Bar
    // exit driver plays 1 -> 0 on close before swapping content.
    property real expand: 0
    Component.onCompleted: expand = 1

    property string monitorName: ""
    property string elapsed: "00:00"
    readonly property bool recording: ScreenRecorder.isRecording && ScreenRecorder.targetMonitors.includes(monitorName)

    // Circle when idle, full pill once this monitor records; the animated
    // pillW feeds Bar.qml's targetWidth so the wipe clip tracks the morph.
    property real pillW: recording ? 180 : Theme.sidePillHeight
    Behavior on pillW { Anim { duration: Theme.anim.fastSpatial } }
    implicitWidth: pillW
    implicitHeight: clip.height
    width: implicitWidth
    height: implicitHeight

    MouseArea {
        anchors.fill: parent
        // isRecording lags reality ~2s (pgrep poll): one honest click per
        // intent; rapid re-clicks inside the settle window re-issue toggles.
        onClicked: ScreenRecorder.toggleRecording("now", root.monitorName)
    }

    IslandExpandClip {
        id: clip
        expand: root.expand
        contentHeight: Theme.sidePillHeight

        Rectangle {
            width: root.pillW
            height: Theme.sidePillHeight
            radius: root.recording ? Theme.radius : height / 2
            Behavior on radius { Anim { duration: Theme.anim.fastSpatial } }
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
                    text: "Recording"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                Text {
                    text: root.elapsed
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }

            // idle record button: static dot centered in the circle
            Rectangle {
                anchors.centerIn: parent
                visible: !root.recording
                width: 8
                height: 8
                radius: width / 2
                color: Theme.danger
            }
        }
    }

    function formatElapsed(ms) {
        const total = Math.max(0, Math.floor(ms / 1000));
        const m = Math.floor(total / 60).toString().padStart(2, "0");
        const s = (total % 60).toString().padStart(2, "0");
        return m + ":" + s;
    }

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
