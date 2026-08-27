import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

// Custom Scripts widget
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    property var scripts: [
        { name: "System Update", command: "sudo pacman -Syu", category: "system" },
        { name: "Clean Cache", command: "yay -Sc", category: "maintenance" },
        { name: "Backup Config", command: "rsync -av ~/.config/ ~/backup/", category: "backup" },
        { name: "Check Disk", command: "df -h", category: "system" }
    ]

    Column {
        anchors.fill: parent
        spacing: 10

        Row {
            spacing: 8
            Label {
                text: "Custom Scripts"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
                Layout.fillWidth: true
            }
            Button {
                text: "+"
                Layout.preferredWidth: 40
                onClicked: {
                    // Add new script
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
                    font.pixelSize: Theme.fontSize + 4
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Column {
                spacing: 8
                width: parent.width

                Repeater {
                    model: scripts
                    delegate: Rectangle {
                        width: parent.width
                        color: Theme.moduleBg
                        radius: 8
                        border.width: 1
                        border.color: Theme.border

                        Row {
                            spacing: 12
                            anchors.margins: 12
                            anchors.fill: parent

                            Column {
                                Layout.fillWidth: true
                                spacing: 4

                                Label {
                                    text: modelData.name
                                    font.pixelSize: Theme.fontSize + 1
                                    font.bold: true
                                    color: Theme.fg
                                }
                                Label {
                                    text: modelData.command
                                    font.pixelSize: Theme.fontSize - 1
                                    color: Theme.fgDim
                                    elide: Text.ElideRight
                                }
                                Label {
                                    text: modelData.category
                                    font.pixelSize: Theme.fontSize - 2
                                    color: Theme.accent
                                    padding: 2
                                    background: Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -2
                                        color: Theme.accentBg
                                        radius: 2
                                    }
                                }
                            }

                            Row {
                                spacing: 4
                                Button {
                                    text: "▶ Run"
                                    onClicked: {
                                        // Run script
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
                                Button {
                                    text: "✏"
                                    onClicked: {
                                        // Edit script
                                    }
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
                                    text: "🗑"
                                    onClicked: {
                                        // Delete script
                                    }
                                    background: Rectangle {
                                        color: Theme.dangerBg
                                        radius: 4
                                        border.width: 1
                                        border.color: Theme.danger
                                    }
                                    contentItem: Text {
                                        anchors.centerIn: parent
                                        color: Theme.danger
                                        font.pixelSize: Theme.fontSize
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}