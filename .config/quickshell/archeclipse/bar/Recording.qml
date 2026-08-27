import Quickshell
import QtQuick
import qs.theme
import qs.services

Item {
    id: root

    property real widthRequest: 0

    // Recording state (from external script)
    property bool recording: false

    // Pulse animation
    property bool pulseVisible: true
    property Timer pulseTimer: Timer {
        interval: 500
        repeat: true
        running: root.recording
        onTriggered: root.pulseVisible = !root.pulseVisible
    }

    // Main layout
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 8
        color: qs.theme.Theme.dangerBg
        border.color: qs.theme.Theme.danger
        border.width: 2

        Row {
            anchors.fill: parent
            spacing: 8
            anchors.margins: 12

            // Recording icon (pulsing)
            Text {
                id: recIcon
                text: "󰑋"
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 16
                color: root.pulseVisible ? qs.theme.Theme.danger : qs.theme.Theme.color0
                verticalAlignment: Text.AlignVCenter

                Behavior on color {
                    ColorAnimation { duration: 500 }
                }
            }

            Text {
                text: "REC"
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 12
                font.bold: true
                color: qs.theme.Theme.danger
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // Click to stop recording
    MouseArea {
        anchors.fill: parent
        onClicked: {
            // Call screenrecord stop
            const proc = Qt.createQmlObject(
                'import Quickshell.Io; Process { command: ["bash", "-c", "' + Quickshell.env("HOME") + '/.config/hypr/scripts/screenrecord.sh stop"] }',
                root
            )
            proc.running = true
            proc.destroy()
        }
    }
}