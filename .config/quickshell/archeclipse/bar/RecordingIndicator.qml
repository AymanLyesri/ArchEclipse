import QtQuick
import qs.theme

// Port of barStates Recording.tsx — pulsing dot + "Recording" + elapsed timer.
// Driven by record.service (wl-screenrec/wf-recorder) — the service itself is
// shared with AGS via the same recording state file; the pulse is activated
// by BarState from the screenrecord IPC hook once wired to keybinds.
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
        Text { text: parent.parent.parent.elapsed; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: parent.elapsed = Qt.formatDateTime(new Date(), "mm:ss")
    }
}
