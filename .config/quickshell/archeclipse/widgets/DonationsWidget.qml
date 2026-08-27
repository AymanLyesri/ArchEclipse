import Quickshell
import QtQuick
import qs.theme

Item {
    id: root

    property string className: ""

    // Donation platforms
    property var platforms: [
        {
            name: "GitHub Sponsors",
            icon: "󰊤",
            url: "https://github.com/sponsors/ayman",
            description: "Monthly sponsorship with tier benefits"
        },
        {
            name: "Ko-fi",
            icon: "☕",
            url: "https://ko-fi.com/ayman",
            description: "One-time or monthly coffee donations"
        },
        {
            name: "Liberapay",
            icon: "🤝",
            url: "https://liberapay.com/ayman",
            description: "Recurring donations, no fees"
        },
        {
            name: "Bitcoin",
            icon: "₿",
            url: "bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa",
            address: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa",
            description: "Bitcoin (BTC) address"
        },
        {
            name: "Ethereum",
            icon: "Ξ",
            url: "ethereum:0x742d35Cc6634C0532925a3b844Bc9e7595f6E",
            address: "0x742d35Cc6634C0532925a3b844Bc9e7595f6E",
            description: "Ethereum (ETH) and ERC-20 tokens"
        },
        {
            name: "Monero",
            icon: "🔒",
            url: "monero:4AdUndXHHZ6cfufTMvppY6JwXNouMBzSkbLYfpAV5U",
            address: "4AdUndXHHZ6cfufTMvppY6JwXNouMBzSkbLYfpAV5U",
            description: "Monero (XMR) - private donations"
        }
    ]

    // Benefits
    property var benefits: [
        "Early access to new features and betas",
        "Priority support and bug fixes",
        "Custom theme/color requests",
        "Name in credits / supporters list",
        "Discord supporter role",
        "Direct line for feature requests"
    ]

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        verticalAlignment: AlignVCenter

        // Header
        Column {
            spacing: 8
            horizontalAlignment: AlignHCenter

            Text {
                text: "Support This Project"
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 24
                font.bold: true
                color: qs.theme.Theme.foreground
            }

            Text {
                text: "If this desktop environment has helped you, consider supporting its development"
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 12
                color: qs.theme.Theme.color8
                width: 400
                wrapMode: Text.Wrap
                horizontalAlignment: AlignHCenter
            }
        }

        // Platform cards
        GridView {
            width: parent.width
            height: 300
            cellWidth: 200
            cellHeight: 120
            columnSpacing: 15
            rowSpacing: 15
            model: root.platforms

            delegate: Rectangle {
                width: 200
                height: 120
                radius: 12
                color: qs.theme.Theme.color0
                border.color: qs.theme.Theme.color8
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 8

                    Row {
                        spacing: 10
                        Text {
                            text: modelData.icon
                            font.family: "JetBrainsMono NFP"
                            font.pixelSize: 24
                        }
                        Text {
                            text: modelData.name
                            font.family: "JetBrainsMono NFP"
                            font.pixelSize: 14
                            font.bold: true
                            color: qs.theme.Theme.foreground
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text {
                        text: modelData.description
                        font.family: "JetBrainsMono NFP"
                        font.pixelSize: 10
                        color: qs.theme.Theme.color8
                        wrapMode: Text.Wrap
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Donate"
                        width: parent.width
                        onClicked: Qt.openUrlExternally(modelData.url)
                        font.family: "JetBrainsMono NFP"
                        font.pixelSize: 11
                        background: Rectangle {
                            color: qs.theme.Theme.accentBg
                            border.color: qs.theme.Theme.accent
                            border.width: 1
                            radius: 4
                        }
                        padding: 6
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Qt.openUrlExternally(modelData.url)
                }
            }
        }

        // Crypto addresses (copyable)
        Column {
            spacing: 8
            Text {
                text: "Crypto Addresses (click to copy)"
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 13
                font.bold: true
                color: qs.theme.Theme.foreground
            }

            Column {
                spacing: 6
                Repeater {
                    model: root.platforms.filter((p) => p.address)
                    delegate: Rectangle {
                        width: parent.width
                        height: 40
                        radius: 6
                        color: qs.theme.Theme.color0
                        border.color: qs.theme.Theme.color8
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Text {
                                text: modelData.icon
                                font.pixelSize: 16
                            }

                            Text {
                                text: modelData.name
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 12
                                font.bold: true
                                color: qs.theme.Theme.foreground
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: modelData.address.slice(0, 20) + "..."
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 10
                                color: qs.theme.Theme.color8
                            }

                            Button {
                                text: "Copy"
                                onClicked: QtGui.QGuiApplication.clipboard().text = modelData.address
                                font.pixelSize: 10
                                background: Rectangle { color: "transparent"; border.color: qs.theme.Theme.accent; border.width: 1; radius: 3 }
                                padding: 4
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: QtGui.QGuiApplication.clipboard().text = modelData.address
                        }
                    }
                }
            }
        }

        // Benefits
        Column {
            spacing: 8
            Text {
                text: "Supporter Benefits"
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 13
                font.bold: true
                color: qs.theme.Theme.foreground
            }

            Column {
                spacing: 6
                Repeater {
                    model: root.benefits
                    delegate: Row {
                        spacing: 10
                        Text { text: "✓"; font.family: "JetBrainsMono NFP"; font.pixelSize: 14; color: qs.theme.Theme.color2 }
                        Text {
                            text: modelData
                            font.family: "JetBrainsMono NFP"
                            font.pixelSize: 11
                            color: qs.theme.Theme.foreground
                            wrapMode: Text.Wrap
                            width: 350
                        }
                    }
                }
            }
        }

        // Footer
        Text {
            text: "Thank you for your support! ❤️"
            font.family: "JetBrainsMono NFP"
            font.pixelSize: 14
            font.bold: true
            color: qs.theme.Theme.accent
            horizontalAlignment: AlignHCenter
        }
    }
}