import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.services

// Media Widget - shows currently playing media
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    Column {
        anchors.fill: parent
        spacing: 10

        Row {
            spacing: 8
            Label {
                text: "Media"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
                Layout.fillWidth: true
            }
        }

        // MPRIS Players
        Repeater {
            model: Mpris.players

            delegate: Rectangle {
                width: parent.width
                color: Theme.moduleBg
                radius: 8
                border.width: 1
                border.color: Theme.border

                Column {
                    anchors.fill: parent
                    spacing: 8
                    anchors.margins: 12

                    // Header with player name and play/pause
                    Row {
                        spacing: 8
                        Label {
                            text: modelData.identity || "Unknown"
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                            color: Theme.fg
                            Layout.fillWidth: true
                        }

                        // Play/Pause
                        Button {
                            text: modelData.playbackStatus === MprisPlaybackState.Playing ? "⏸" : "▶"
                            onClicked: {
                                if (modelData.playbackStatus === MprisPlaybackState.Playing) {
                                    modelData.pause()
                                } else {
                                    modelData.play()
                                }
                            }
                            background: Rectangle {
                                color: Theme.accentBg
                                radius: 4
                                border.width: 1
                                border.color: Theme.accent
                            }
                            contentItem: Text {
                                anchors.centerIn: parent
                                color: Theme.accent
                                font.pixelSize: Theme.fontSize
                            }
                        }

                        // Previous/Next
                        Button {
                            text: "⏮"
                            onClicked: modelData.previous()
                            background: Rectangle {
                                color: Theme.moduleBg
                                radius: 4
                                border.width: 1
                                border.color: Theme.border
                            }
                            contentItem: Text {
                                anchors.centerIn: parent
                                color: Theme.fg
                                font.pixelSize: Theme.fontSize
                            }
                        }
                        Button {
                            text: "⏭"
                            onClicked: modelData.next()
                            background: Rectangle {
                                color: Theme.moduleBg
                                radius: 4
                                border.width: 1
                                border.color: Theme.border
                            }
                            contentItem: Text {
                                anchors.centerIn: parent
                                color: Theme.fg
                                font.pixelSize: Theme.fontSize
                            }
                        }
                    }

                    // Track info
                    Row {
                        spacing: 12

                        // Album art placeholder
                        Rectangle {
                            width: 60
                            height: 60
                            color: Theme.bg
                            radius: 4
                            border.width: 1
                            border.color: Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: "🎵"
                                font.pixelSize: 24
                            }
                        }

                        // Track details
                        Column {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                text: modelData.metadata.title || "Unknown Title"
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                                color: Theme.fg
                                elide: Text.ElideRight
                            }
                            Label {
                                text: modelData.metadata.artist ? modelData.metadata.artist.join(", ") : "Unknown Artist"
                                font.pixelSize: Theme.fontSize - 1
                                color: Theme.fgDim
                                elide: Text.ElideRight
                            }
                            Label {
                                text: modelData.metadata.album || "Unknown Album"
                                font.pixelSize: Theme.fontSize - 1
                                color: Theme.fgDim
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // Progress bar
                    Column {
                        spacing: 4

                        Row {
                            spacing: 8
                            Label {
                                text: formatTime(modelData.position)
                                font.pixelSize: Theme.fontSize - 2
                                color: Theme.fgDim
                            }
                            Item { Layout.fillWidth: true }
                            Label {
                                text: formatTime(modelData.metadata.length)
                                font.pixelSize: Theme.fontSize - 2
                                color: Theme.fgDim
                            }
                        }

                        Slider {
                            from: 0
                            to: modelData.metadata.length || 100
                            value: modelData.position
                            onValueChanged: {
                                if (pressed) {
                                    modelData.position = value
                                }
                            }
                            background: Rectangle {
                                color: Theme.bg
                                radius: 2
                                border.width: 1
                                border.color: Theme.border
                            }
                        }
                    }
                }
            }
        }

        // No players message
        Label {
            visible: Mpris.players.length === 0
            text: "No media playing"
            font.pixelSize: Theme.fontSize
            color: Theme.fgDim
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    function formatTime(usec) {
        if (!usec) return "0:00";
        const seconds = Math.floor(usec / 1000000);
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }
}