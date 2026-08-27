import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

// Manga Viewer widget
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
                text: "Manga Viewer"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
                Layout.fillWidth: true
            }
        }

        // Search
        TextField {
            placeholderText: "Search manga..."
            Layout.fillWidth: true
            background: Rectangle {
                color: Theme.bg
                radius: 4
                border.width: 1
                border.color: Theme.border
            }
        }

        // Manga list
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Column {
                spacing: 8
                width: parent.width

                Repeater {
                    model: 20 // Placeholder
                    delegate: Rectangle {
                        width: parent.width
                        height: 100
                        color: Theme.moduleBg
                        radius: 8
                        border.width: 1
                        border.color: Theme.border

                        Row {
                            spacing: 12
                            anchors.margins: 12
                            anchors.fill: parent

                            Rectangle {
                                width: 70
                                height: 70
                                color: Theme.bg
                                radius: 4
                                border.width: 1
                                border.color: Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: "📖"
                                    font.pixelSize: 24
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 4

                                Label {
                                    text: "Manga Title " + (index + 1)
                                    font.pixelSize: Theme.fontSize + 1
                                    font.bold: true
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                }
                                Label {
                                    text: "Author: Unknown"
                                    font.pixelSize: Theme.fontSize - 1
                                    color: Theme.fgDim
                                }
                                Label {
                                    text: "Chapter 1 / 100"
                                    font.pixelSize: Theme.fontSize - 1
                                    color: Theme.fgDim
                                }
                                Row {
                                    spacing: 8
                                    Repeater {
                                        model: ["Action", "Fantasy", "Adventure"]
                                        delegate: Label {
                                            text: modelData
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
                                }
                            }

                            Column {
                                spacing: 4
                                Button {
                                    text: "Read"
                                    Layout.preferredWidth: 60
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
                                Button {
                                    text: "📚"
                                    ToolTip.visible: hovered
                                    ToolTip.delay: 500
                                    ToolTip.text: "Library"
                                    Layout.preferredWidth: 40
                                    background: Rectangle {
                                        color: Theme.moduleBg
                                        radius: 4
                                        border.width: 1
                                        border.color: Theme.border
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