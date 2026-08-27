import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

// Chat Bot widget
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    property var messages: []
    property string currentInput: ""

    Column {
        anchors.fill: parent
        spacing: 10

        Row {
            spacing: 8
            Label {
                text: "Chat Bot"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
                Layout.fillWidth: true
            }
            ComboBox {
                model: ["GPT-4o-mini", "GPT-4o", "Claude", "Local"]
                currentIndex: 0
                background: Rectangle {
                    color: Theme.bg
                    radius: 4
                    border.width: 1
                    border.color: Theme.border
                }
            }
        }

        // Messages area
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Column {
                spacing: 8
                width: parent.width

                Repeater {
                    model: messages
                    delegate: Rectangle {
                        width: parent.width
                        color: index % 2 === 0 ? Theme.moduleBg : Theme.bg
                        radius: 8
                        border.width: 1
                        border.color: Theme.border

                        Column {
                            anchors.fill: parent
                            spacing: 4
                            anchors.margins: 12

                            Label {
                                text: role === "user" ? "You" : "Assistant"
                                font.pixelSize: Theme.fontSize - 1
                                font.bold: true
                                color: Theme.accent
                            }
                            Label {
                                text: content
                                font.pixelSize: Theme.fontSize
                                color: Theme.fg
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    height: 1
                }
            }
        }

        // Input area
        Row {
            spacing: 8
            TextArea {
                id: inputField
                placeholderText: "Ask anything..."
                Layout.fillWidth: true
                height: 60
                wrapMode: Text.WordWrap
                background: Rectangle {
                    color: Theme.bg
                    radius: 8
                    border.width: 1
                    border.color: Theme.border
                }
            }
            Button {
                text: "Send"
                Layout.preferredWidth: 80
                height: 60
                onClicked: {
                    // Send message
                    const text = inputField.text.trim();
                    if (text) {
                        messages = [...messages, { role: "user", content: text }];
                        inputField.text = "";
                        // TODO: Get AI response
                    }
                }
                background: Rectangle {
                    color: Theme.accentBg
                    radius: 8
                    border.width: 1
                    border.color: Theme.accent
                }
                contentItem: Text {
                    anchors.centerIn: parent
                    color: Theme.accent
                    font.pixelSize: Theme.fontSize
                }
            }
        }
    }
}