import QtQuick
import qs.theme
import qs.services

// Port of barStates Recording.tsx — pulsing dot + "Recording" + TRUE elapsed
// timer (mm:ss since the recording actually started). AGS computes
// Date.now() - start; we use ScreenRecorder.startTimestamp captured on the
// 0->1 recording-state edge. When not recording, elapsed resets to 00:00.
Rectangle {
    width: 180; height: 24
    radius: Theme.radius
    color: Theme.moduleBg

    property string elapsed: "00:00"

    Row {
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8; height: 8; radius: 4
            color: "#a94545"
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.3; duration: 600 }
                NumberAnimation { from: 0.3; to: 1; duration: 600 }
            }
        }
        Text { text: "Recording"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
        Text { text: parent.parent.elapsed; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
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
            // Real elapsed duration since recording start (AGS Date.now() - start).
            if (ScreenRecorder.isRecording) {
                parent.elapsed = parent.formatElapsed(Date.now() - ScreenRecorder.startTimestamp);
            } else {
                parent.elapsed = "00:00";
            }
        }
    }
}
