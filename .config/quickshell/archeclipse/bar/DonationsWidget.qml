import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

// Donations widget
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    Column {
        anchors.fill: parent
        spacing: 16

        // Header
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Label {
                text: "❤️"
                font.pixelSize: 48
            }

            Label {
                text: "Support this project"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
            }

            Label {
                text: "If ArchEclipse helped you, consider supporting its development"
                font.pixelSize: Theme.fontSize
                color: Theme.fgDim
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.width * 0.8
            }
        }

        // Donation options
        Column {
            spacing: 12
            width: parent.width

            // GitHub Sponsors
            Rectangle {
                width: parent.width
                height: 100
                color: Theme.moduleBg
                radius: 12
                border.width: 1
                border.color: Theme.border

                Row {
                    spacing: 16
                    anchors.centerIn: parent
                    anchors.margins: 16

                    Rectangle {
                        width: 60
                        height: 60
                        color: "#24292e"
                        radius: 8
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "❤️"
                            font.pixelSize: 24
                        }
                    }

                    Column {
                        spacing: 4
                        Label {
                            text: "GitHub Sponsors"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.fg
                        }
                        Label {
                            text: "Monthly sponsorship with perks"
                            font.pixelSize: Theme.fontSize - 1
                            color: Theme.fgDim
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Sponsor"
                        onClicked: {
                            // Open GitHub Sponsors
                        }
                        background: Rectangle {
                            color: "#24292e"
                            radius: 6
                            border.width: 1
                            border.color: Theme.border
                        }
                        contentItem: Text {
                            anchors.centerIn: parent
                            color: "#fff"
                            font.pixelSize: Theme.fontSize
                        }
                    }
                }
            }

            // Ko-fi
            Rectangle {
                width: parent.width
                height: 100
                color: Theme.moduleBg
                radius: 12
                border.width: 1
                border.color: Theme.border

                Row {
                    spacing: 16
                    anchors.centerIn: parent
                    anchors.margins: 16

                    Rectangle {
                        width: 60
                        height: 60
                        color: "#FF5E5B"
                        radius: 8
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "☕"
                            font.pixelSize: 24
                        }
                    }

                    Column {
                        spacing: 4
                        Label {
                            text: "Ko-fi"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.fg
                        }
                        Label {
                            text: "One-time coffee donation"
                            font.pixelSize: Theme.fontSize - 1
                            color: Theme.fgDim
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Donate"
                        onClicked: {
                            // Open Ko-fi
                        }
                        background: Rectangle {
                            color: "#FF5E5B"
                            radius: 6
                            border.width: 1
                            border.color: "#FF5E5B"
                        }
                        contentItem: Text {
                            anchors.centerIn: parent
                            color: "#fff"
                            font.pixelSize: Theme.fontSize
                        }
                    }
                }
            }

            // Liberapay
            Rectangle {
                width: parent.width
                height: 100
                color: Theme.moduleBg
                radius: 12
                border.width: 1
                border.color: Theme.border

                Row {
                    spacing: 16
                    anchors.centerIn: parent
                    anchors.margins: 16

                    Rectangle {
                        width: 60
                        height: 60
                        color: "#F6C915"
                        radius: 8
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "💝"
                            font.pixelSize: 24
                        }
                    }

                    Column {
                        spacing: 4
                        Label {
                            text: "Liberapay"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.fg
                        }
                        Label {
                            text: "Recurring donations, no fees"
                            font.pixelSize: Theme.fontSize - 1
                            color: Theme.fgDim
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Donate"
                        onClicked: {
                            // Open Liberapay
                        }
                        background: Rectangle {
                            color: "#F6C915"
                            radius: 6
                            border.width: 1
                            border.color: "#F6C915"
                        }
                        contentItem: Text {
                            anchors.centerIn: parent
                            color: "#000"
                            font.pixelSize: Theme.fontSize
                        }
                    }
                }
            }

            // Crypto
            Rectangle {
                width: parent.width
                height: 120
                color: Theme.moduleBg
                radius: 12
                border.width: 1
                border.color: Theme.border

                Column {
                    anchors.fill: parent
                    spacing: 8
                    anchors.margins: 16

                    Row {
                        spacing: 8
                        Label {
                            text: "₿"
                            font.pixelSize: 24
                        }
                        Label {
                            text: "Cryptocurrency"
                            font.pixelSize: Theme.fontSize + 2
                            font.bold: true
                            color: Theme.fg
                        }
                    }

                    Label {
                        text: "BTC: bc1qexampleaddress..."
                        font.pixelSize: Theme.fontSize - 1
                        font.family: "JetBrainsMono NFP"
                        color: Theme.fgDim
                    }

                    Row {
                        spacing: 8
                        Label {
                            text: "ETH: 0xexampleaddress..."
                            font.pixelSize: Theme.fontSize - 1
                            font.family: "JetBrainsMono NFP"
                            color: Theme.fgDim
                        }
                        Button {
                            text: "Copy"
                            onClicked: {
                                // Copy address
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
                                font.pixelSize: Theme.fontSize - 1
                            }
                        }
                    }
                }
            }
        }

        // Supporter benefits
        Column {
            spacing: 8
            Label {
                text: "Supporter Benefits"
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
                color: Theme.accent
            }

            Column {
                spacing: 4
                Repeater {
                    model: [
                        "✨ Supporter badge in profile",
                        "🎨 Access to exclusive themes",
                        "🔧 Priority feature requests",
                        "📊 Detailed usage statistics",
                        "💬 Direct Discord channel access"
                    ]
                    delegate: Row {
                        spacing: 8
                        Label {
                            text: modelData
                            font.pixelSize: Theme.fontSize
                            color: Theme.fg
                        }
                    }
                }
            }
        }
    }
}