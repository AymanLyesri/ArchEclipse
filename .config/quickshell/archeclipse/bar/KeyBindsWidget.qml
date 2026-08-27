import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

// Key Binds widget
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    property var keybinds: [
        { key: "SUPER + RETURN", action: "Terminal", category: "apps" },
        { key: "SUPER + D", action: "App Launcher", category: "apps" },
        { key: "SUPER + B", action: "Browser", category: "apps" },
        { key: "SUPER + E", action: "File Manager", category: "apps" },
        { key: "SUPER + Q", action: "Close Window", category: "window" },
        { key: "SUPER + F", action: "Fullscreen", category: "window" },
        { key: "SUPER + SPACE", action: "Floating Toggle", category: "window" },
        { key: "SUPER + 1-9", action: "Workspace 1-9", category: "workspace" },
        { key: "SUPER + SHIFT + 1-9", action: "Move to Workspace", category: "workspace" },
        { key: "SUPER + TAB", action: "Next Workspace", category: "workspace" },
        { key: "SUPER + L", action: "Left Panel", category: "panels" },
        { key: "SUPER + R", action: "Right Panel", category: "panels" },
        { key: "SUPER + V", action: "Clipboard", category: "utility" },
        { key: "SUPER + S", action: "Screenshot", category: "utility" },
        { key: "SUPER + ESC", action: "Exit Menu", category: "utility" }
    ]

    Column {
        anchors.fill: parent
        spacing: 10

        Row {
            spacing: 8
            Label {
                text: "Key Binds"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
                Layout.fillWidth: true
            }
        }

        // Categories
        Row {
            spacing: 4
            Repeater {
                model: ["All", "Apps", "Window", "Workspace", "Panels", "Utility"]
                delegate: Button {
                    text: modelData
                    checkable: true
                    checked: index === 0
                    onClicked: {
                        // Filter by category
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

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Column {
                spacing: 4
                width: parent.width

                Repeater {
                    model: keybinds
                    delegate: Rectangle {
                        width: parent.width
                        color: Theme.moduleBg
                        radius: 6
                        border.width: 1
                        border.color: Theme.border

                        Row {
                            spacing: 12
                            anchors.margins: 12
                            anchors.fill: parent

                            Rectangle {
                                width: 140
                                color: Theme.bg
                                radius: 4
                                border.width: 1
                                border.color: Theme.border

                                Label {
                                    anchors.centerIn: parent
                                    text: modelData.key
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                    color: Theme.accent
                                    font.family: "JetBrainsMono NFP"
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2

                                Label {
                                    text: modelData.action
                                    font.pixelSize: Theme.fontSize
                                    color: Theme.fg
                                }
                                Label {
                                    text: modelData.category
                                    font.pixelSize: Theme.fontSize - 1
                                    color: Theme.fgDim
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}