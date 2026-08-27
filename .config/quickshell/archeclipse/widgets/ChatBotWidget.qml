import Quickshell
import QtQuick
import qs.theme
import qs.services
import Quickshell.Io

Item {
    id: root

    property string className: ""

    // Chat settings
    property var model: qs.theme.Settings.chatBot.api.value
    property var messages: []

    // UI state
    property string inputText: ""
    property bool loading: false

    // Send message
        function sendMessage() {
            if (!root.inputText.trim() || root.loading) return

            const userMessage = { role: "user", content: root.inputText }
            root.messages = [...root.messages, userMessage]
            const query = root.inputText
            root.inputText = ""
            root.loading = true

            // Call AI API (simplified - would use actual API)
            const jsonPayload = JSON.stringify({
                model: root.model,
                messages: root.messages
            })
            const escapedPayload = jsonPayload.replace(/"/g, '\\"')
            const proc = Qt.createQmlObject(
                'import Quickshell.Io; Process { command: ["curl", "-fsSL", "-X", "POST", "https://api.openai.com/v1/chat/completions", "-H", "Content-Type: application/json", "-d", "' + escapedPayload + '"] }',
                root
            )
            proc.running = true
            proc.stdout = StdioCollector {
                onStreamFinished: {
                    try {
                        const response = JSON.parse(text)
                        const aiMessage = { role: "assistant", content: response.choices[0]?.message?.content ?? "Error" }
                        root.messages = [...root.messages, aiMessage]
                        root.loading = false
                    } catch (e) {
                        console.error("Chat API error:", e)
                        root.messages = [...root.messages, { role: "assistant", content: "Error: " + e.message }]
                        root.loading = false
                    }
                }
            }
        }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Messages area
        Column {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            clip: true

            Repeater {
                model: root.messages
                delegate: Rectangle {
                    width: parent.width
                    height: 60
                    radius: 8
                    color: modelData.role === "user" ? qs.theme.Theme.accentBg : qs.theme.Theme.color0
                    border.color: modelData.role === "user" ? qs.theme.Theme.accent : qs.theme.Theme.color8
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        Row {
                            Text {
                                text: modelData.role === "user" ? "You" : "AI"
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 11
                                font.bold: true
                                color: modelData.role === "user" ? qs.theme.Theme.accent : qs.theme.Theme.foreground
                            }
                            Item { Layout.fillWidth: true }
                        }

                        Text {
                            text: modelData.content
                            font.family: "JetBrainsMono NFP"
                            font.pixelSize: 12
                            color: qs.theme.Theme.foreground
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            // Loading indicator
            Rectangle {
                visible: root.loading
                width: parent.width
                height: 40
                radius: 8
                color: qs.theme.Theme.accentBg
                border.color: qs.theme.Theme.accent
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Thinking..."
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 12
                    color: qs.theme.Theme.accent
                }
            }
        }

        // Input area
        Row {
            spacing: 10
            TextInput {
                id: input
                text: root.inputText
                onTextChanged: root.inputText = text
                onAccepted: root.sendMessage()
                placeholderText: "Message..."
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 12
                Layout.fillWidth: true
                background: Rectangle { color: qs.theme.Theme.color0; border.color: qs.theme.Theme.color8; border.width: 1; radius: 4 }
                padding: 8
            }
            Button {
                text: "Send"
                enabled: root.inputText.trim() !== "" && !root.loading
                onClicked: root.sendMessage()
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 12
                background: Rectangle { color: qs.theme.Theme.accentBg; border.color: qs.theme.Theme.accent; border.width: 1; radius: 4 }
                padding: 8
            }
        }

        // Model selector
        Row {
            spacing: 10
            Text { text: "Model:"; font.family: "JetBrainsMono NFP"; font.pixelSize: 11; color: qs.theme.Theme.color8; verticalAlignment: Text.AlignVCenter }
            ComboBox {
                model: [root.model]
                currentIndex: 0
                onCurrentIndexChanged: {
                    qs.theme.Settings.updateSetting("chatBot.api", modelData)
                }
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 11
                Layout.fillWidth: true
            }
        }
    }
}