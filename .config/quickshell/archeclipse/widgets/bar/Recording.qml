import Quickshell
import QtQuick
import Quickshell.Io
import qs.theme
import qs.services

Item {
    id: root

    property real widthRequest: 0
    property bool recording: false

    property bool pulseVisible: true
    readonly property Timer pulseTimer: Timer {
        interval: 500
        repeat: true
        running: root.recording
        onTriggered: root.pulseVisible = !root.pulseVisible
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 8
        color: Theme.dangerBg
        border.color: Theme.danger
        border.width: 2

        Row {
            anchors.fill: parent
            spacing: 8
            anchors.margins: 12

            Text {
                id: recIcon
                text: "\u{F045}"
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 16
                color: root.pulseVisible ? Theme.danger : Theme.color0
                verticalAlignment: Text.AlignVCenter
                Behavior on color { ColorAnimation { duration: 500 } }
            }

            Text {
                text: "REC"
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 12
                font.bold: true
                color: Theme.danger
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            const proc = Qt.createQmlObject(
                'import Quickshell.Io; Process { command: ["bash", "-c", "' + Quickshell.env("HOME") + '/.config/hypr/scripts/screenrecord.sh stop"] }',
                root
            )
            proc.running = true
            proc.destroy()
        }
    }
}
