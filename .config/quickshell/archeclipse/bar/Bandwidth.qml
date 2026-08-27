import Quickshell
import QtQuick
import qs.theme

Item {
    id: root

    // Bandwidth data (from external binary)
    property real downloadSpeed: 0  // KB/s
    property real uploadSpeed: 0    // KB/s

    // Polling timer
    property Timer pollTimer: Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.poll()
    }

    function poll() {
        // Would read from /sys/class/net/*/statistics or use nethogs/iftop
        // For now, placeholder
    }

    // Format speed
    function formatSpeed(bytes) {
        if (bytes >= 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB/s"
        if (bytes >= 1024) return (bytes / 1024).toFixed(1) + " KB/s"
        return bytes + " B/s"
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 8
        color: qs.theme.Theme.color0
        border.color: qs.theme.Theme.color8
        border.width: 1

        Row {
            anchors.fill: parent
            spacing: 6
            anchors.margins: 10

            // Download
            Row {
                spacing: 2
                Text {
                    text: "↓"
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 12
                    color: qs.theme.Theme.color2
                }
                Text {
                    text: root.formatSpeed(root.downloadSpeed)
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 10
                    color: qs.theme.Theme.foreground
                }
            }

            // Upload
            Row {
                spacing: 2
                Text {
                    text: "↑"
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 12
                    color: qs.theme.Theme.color1
                }
                Text {
                    text: root.formatSpeed(root.uploadSpeed)
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 10
                    color: qs.theme.Theme.foreground
                }
            }
        }
    }
}