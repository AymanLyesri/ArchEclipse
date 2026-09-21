import QtQuick
import qs.theme
import qs.services
import qs.widgets.bar.islands

// Recording island — pulsing dot + "Recording" + TRUE elapsed timer (mm:ss
// since the recording actually started). Uses ScreenRecorder.startTimestamp
// 0->1 recording-state edge. When not recording, elapsed resets to 00:00.
Item {
    id: root
    // Expand driver: 0 -> 1 on creation unfolds the body; the Bar
    // exit driver plays 1 -> 0 on close before swapping content.
    property real expand: 0
    Component.onCompleted: expand = 1

    property string elapsed: "00:00"

    implicitWidth: 180
    implicitHeight: clip.height
    width: implicitWidth
    height: implicitHeight

    IslandExpandClip {
        id: clip
        expand: root.expand
        contentHeight: 24

        Rectangle {
            width: 180
            height: 24
            radius: Theme.radius
            color: Theme.surface

            Row {
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: "#a94545"
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 1
                            to: 0.3
                            duration: 600
                        }
                        NumberAnimation {
                            from: 0.3
                            to: 1
                            duration: 600
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
