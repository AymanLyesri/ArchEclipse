import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import qs.theme

// Port of bar/components/sub-components/Bandwidth.tsx
// Reads real network speeds from the bandwidth-loop-ags daemon (JSON on stdout
// every 3s: [upload_speed, download_speed, today_upload, today_download] in B/s).
// Compact form shows up/down speeds; click reveals the Network Statistics
// popover (Upload/Download, Packets + today's Data).
Item {
    id: root
    height: 24

    property string timestamp: ""
    property string uploadSpeed: "0"      // b[0] KB/s (speed_tx/-1024)
    property string downloadSpeed: "0"    // b[1] KB/s
    property real todayUpload: 0          // b[2] bytes
    property real todayDownload: 0        // b[3] bytes

    // Persistent daemon — Spawns on load and restarts if it exits/crashes.
    // NOTE: never hardcode /tmp/ags-<user> (breaks multi-user); SysInfo.qml
    // builds /tmp/ags-$USER the same way.
    property Process _bandwidthProc: Process {
        command: [`/tmp/ags-${Quickshell.env("USER")}/bandwidth-loop-ags`]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => root.parse(data)
        }
        onExited: (code, status) => { if (root.active) Qt.callLater(() => running = true) }
    }

    // Hover popover (AGS bandwidth popover, Network Statistics)
    Popup {
        id: bwPopup
        parent: root
        y: root.height + 6
        x: root.width / 2 - bwPopup.implicitWidth / 2
        padding: 8
        closePolicy: Popup.CloseOnPressOutside
        background: Rectangle { color: Theme.moduleBg; radius: 8; border.color: Theme.border }

        Column {
            spacing: 8
            Text {
                text: "Network Statistics"
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
                color: Theme.foreground
            }

            Row {
                spacing: 24

                // Upload section
                Column {
                    spacing: 4
                    Text { text: "Upload"; color: Theme.foregroundSecondary; font.pixelSize: Theme.fontSize }
                    Row {
                        spacing: 16
                        Column {
                            spacing: 2
                            Text { text: "Packets"; color: Theme.foregroundSecondary; font.pixelSize: Theme.fontSize - 2 }
                            Text { text: root.uploadSpeed + " KB/s"; color: Theme.foreground; font.pixelSize: Theme.fontSize }
                        }
                        Column {
                            spacing: 2
                            Text { text: "Data"; color: Theme.foregroundSecondary; font.pixelSize: Theme.fontSize - 2 }
                            Text { text: root.formatData(root.todayUpload); color: Theme.foreground; font.pixelSize: Theme.fontSize }
                        }
                    }
                }

                // Download section
                Column {
                    spacing: 4
                    Text { text: "Download"; color: Theme.foregroundSecondary; font.pixelSize: Theme.fontSize }
                    Row {
                        spacing: 16
                        Column {
                            spacing: 2
                            Text { text: "Packets"; color: Theme.foregroundSecondary; font.pixelSize: Theme.fontSize - 2 }
                            Text { text: root.downloadSpeed + " KB/s"; color: Theme.foreground; font.pixelSize: Theme.fontSize }
                        }
                        Column {
                            spacing: 2
                            Text { text: "Data"; color: Theme.foregroundSecondary; font.pixelSize: Theme.fontSize - 2 }
                            Text { text: root.formatData(root.todayDownload); color: Theme.foreground; font.pixelSize: Theme.fontSize }
                        }
                    }
                }
            }
        }
    }

    // Compact display (AGS bandwidth-button) — click to open popover
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 6
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: bwPopup.open()
            cursorShape: Qt.PointingHandCursor

            ToolTip.visible: hovered
            ToolTip.text: "click to open"
        }

        Row {
            anchors.fill: parent
            spacing: 5
            anchors.margins: 6

            // Upload (tx) — b[0]
            Row { spacing: 1
                Text { text: root.uploadSpeed; color: Theme.foreground; font.pixelSize: 10; font.family: Theme.fontFamily }
                Text { text: "\u{F062}"; color: Theme.accent; font.pixelSize: 10 }
            }
            // Download (rx) — b[1]
            Row { spacing: 1
                Text { text: root.downloadSpeed; color: Theme.foreground; font.pixelSize: 10; font.family: Theme.fontFamily }
                Text { text: "\u{F063}"; color: Theme.accent; font.pixelSize: 10 }
            }
        }
    }

    Component.onCompleted: _bandwidthProc.running = true

    // Parse "[tx,rx,today_tx,today_rx]" -> KB/s for speeds, bytes for data
    function parse(line) {
        const m = line.match(/\[([^\]]+)\]/);
        if (!m) return;
        const parts = m[1].split(",").map(x => parseInt(x, 10));
        if (parts.length !== 4) return;
        root.uploadSpeed = Math.round(parts[0] / 1024 * 100) / 100;
        root.downloadSpeed = Math.round(parts[1] / 1024 * 100) / 100;
        root.todayUpload = parts[2];
        root.todayDownload = parts[3];
    }

    // formatKiloBytes equivalent (AGS utils/bytes)
    function formatData(bytes) {
        if (bytes >= 1024 * 1024 * 1024) return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB";
        if (bytes >= 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(2) + " MB";
        if (bytes >= 1024) return (bytes / 1024).toFixed(2) + " KB";
        return bytes + " B";
    }
}
