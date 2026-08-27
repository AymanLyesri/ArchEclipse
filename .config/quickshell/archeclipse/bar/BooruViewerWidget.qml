import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

// Booru Viewer widget
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
                text: "Booru Viewer"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
                Layout.fillWidth: true
            }
        }

        // Tabs for different sources
        Row {
            spacing: 4
            Repeater {
                model: ["Danbooru", "Gelbooru", "Safebooru", "Rule34", "Yandere"]
                delegate: Button {
                    text: modelData
                    checkable: true
                    checked: index === 0
                    onClicked: {
                        // Switch source
                    }
                    background: Rectangle {
                        color: checked ? Theme.accentBg : Theme.moduleBg
                        radius: 4
                        border.width: 1
                        border.color: checked ? Theme.accent : Theme.border
                    }
                    contentItem: Text {
                        anchors.centerIn: parent
                        color: checked ? Theme.accent : Theme.fg
                        font.pixelSize: Theme.fontSize
                    }
                }
            }
        }

        // Search and tags
        Column {
            spacing: 8
            width: parent.width

            TextField {
                placeholderText: "Tags: -rating:explicit berserk order:score"
                Layout.fillWidth: true
                background: Rectangle {
                    color: Theme.bg
                    radius: 4
                    border.width: 1
                    border.color: Theme.border
                }
            }

            Row {
                spacing: 8
                SpinBox {
                    id: limitSpin
                    from: 1
                    to: 100
                    value: 33
                    Layout.fillWidth: true
                    background: Rectangle {
                        color: Theme.bg
                        radius: 4
                        border.width: 1
                        border.color: Theme.border
                    }
                }
                SpinBox {
                    id: pageSpin
                    from: 1
                    to: 1000
                    value: 1
                    Layout.fillWidth: true
                    background: Rectangle {
                        color: Theme.bg
                        radius: 4
                        border.width: 1
                        border.color: Theme.border
                    }
                }
            }
        }

        // Results grid
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Grid {
                columns: 2
                spacing: 8

                Repeater {
                    model: 10 // Placeholder
                    delegate: Rectangle {
                        width: (parent.width - 8) / 2
                        height: width * 0.75
                        color: Theme.moduleBg
                        radius: 8
                        border.width: 1
                        border.color: Theme.border
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.bg
                            border.width: 1
                            border.color: Theme.border
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Image " + (index + 1)
                            color: Theme.fgDim
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                // Open image
                            }
                        }
                    }
                }
            }
        }
    }
}