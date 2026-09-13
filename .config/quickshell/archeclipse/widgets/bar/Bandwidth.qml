import QtQuick
import QtQuick.Controls
import qs.theme
import qs.services
import qs.widgets.shared

// Network speed pill + popover.
// Binds SysInfo.bandwidth — the single bandwidth-loop owner (see
// services/SysInfo.qml) — instead of spawning a second daemon.
// Compact form shows up/down speeds; click reveals the Network Statistics
// popover (Upload/Download, Packets + today's Data).
Item {
    id: root
    height: Theme.barContentHeight

    // Single source: [upKB, downKB, todayUpKB, todayDownKB] (SysInfo applies
    // Math.round(B/1024) to all four). Speeds display directly; today's
    // counters are scaled back to bytes for formatData().
    readonly property var _bw: SysInfo.bandwidth
    property string uploadSpeed: String(_bw[0])      // b[0] KB/s
    property string downloadSpeed: String(_bw[1])    // b[1] KB/s
    property real todayUpload: _bw[2] * 1024         // b[2] KB -> bytes
    property real todayDownload: _bw[3] * 1024       // b[3] KB -> bytes

    // Hover popover (Network Statistics)
    Popup {
        id: bwPopup
        parent: root
        y: root.height + 6
        x: root.width / 2 - bwPopup.implicitWidth / 2
        padding: 8
        closePolicy: Popup.CloseOnPressOutside
        background: Rectangle {
            color: Theme.surface
            radius: 8
            border.color: Theme.border
        }

        Column {
            spacing: 8
            Text {
                text: "Network Statistics"
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
                color: Theme.fg
            }

            Row {
                spacing: 24

                // Upload section
                Column {
                    spacing: 4
                    Text {
                        text: "Upload"
                        color: Theme.muted
                        font.pixelSize: Theme.fontSize
                    }
                    Row {
                        spacing: 16
                        Column {
                            spacing: 2
                            Text {
                                text: "Packets"
                                color: Theme.muted
                                font.pixelSize: Theme.fontSize - 2
                            }
                            Text {
                                text: root.uploadSpeed + " KB/s"
                                color: Theme.fg
                                font.pixelSize: Theme.fontSize
                            }
                        }
                        Column {
                            spacing: 2
                            Text {
                                text: "Data"
                                color: Theme.muted
                                font.pixelSize: Theme.fontSize - 2
                            }
                            Text {
                                text: root.formatData(root.todayUpload)
                                color: Theme.fg
                                font.pixelSize: Theme.fontSize
                            }
                        }
                    }
                }

                // Download section
                Column {
                    spacing: 4
                    Text {
                        text: "Download"
                        color: Theme.muted
                        font.pixelSize: Theme.fontSize
                    }
                    Row {
                        spacing: 16
                        Column {
                            spacing: 2
                            Text {
                                text: "Packets"
                                color: Theme.muted
                                font.pixelSize: Theme.fontSize - 2
                            }
                            Text {
                                text: root.downloadSpeed + " KB/s"
                                color: Theme.fg
                                font.pixelSize: Theme.fontSize
                            }
                        }
                        Column {
                            spacing: 2
                            Text {
                                text: "Data"
                                color: Theme.muted
                                font.pixelSize: Theme.fontSize - 2
                            }
                            Text {
                                text: root.formatData(root.todayDownload)
                                color: Theme.fg
                                font.pixelSize: Theme.fontSize
                            }
                        }
                    }
                }
            }
        }
    }

    // Compact display — click to open popover
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

            AppTooltip {
                visible: parent.containsMouse
                text: "click to open"
            }
        }

        Row {
            anchors.fill: parent
            spacing: 5
            anchors.margins: 6

            // Upload (tx) — b[0]
            Row {
                spacing: 1
                Text {
                    text: root.uploadSpeed
                    color: Theme.fg
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                }
                Text {
                    text: "\u{F062}"
                    color: Theme.accent
                    font.pixelSize: 10
                }
            }
            // Download (rx) — b[1]
            Row {
                spacing: 1
                Text {
                    text: root.downloadSpeed
                    color: Theme.fg
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                }
                Text {
                    text: "\u{F063}"
                    color: Theme.accent
                    font.pixelSize: 10
                }
            }
        }
    }

    // Human-readable byte formatter (B/KB/MB/GB)
    function formatData(bytes) {
        if (bytes >= 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB";
        if (bytes >= 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(2) + " MB";
        if (bytes >= 1024)
            return (bytes / 1024).toFixed(2) + " KB";
        return bytes + " B";
    }
}
