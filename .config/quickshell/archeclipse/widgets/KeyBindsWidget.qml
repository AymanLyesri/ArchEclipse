import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

Item {
    id: root

    property string className: ""

    // Keybind categories
    property var currentCategory: "all"

    // Keybind data (from AGS constants)
    property var keybinds: {
        all: [
            { key: "SUPER", action: "Open app launcher", category: "window" },
            { key: "SUPER + R", action: "Toggle right panel", category: "panel" },
            { key: "SUPER + L", action: "Toggle left panel", category: "panel" },
            { key: "SUPER + Q", action: "Close window", category: "window" },
            { key: "SUPER + F", action: "Fullscreen", category: "window" },
            { key: "SUPER + SHIFT + Q", action: "Kill window", category: "window" },
            { key: "SUPER + SPACE", action: "Toggle floating", category: "window" },
            { key: "SUPER + V", action: "Pseudo tile", category: "window" },
            { key: "SUPER + H/J/K/L", action: "Focus direction", category: "window" },
            { key: "SUPER + SHIFT + H/J/K/L", action: "Move window", category: "window" },
            { key: "SUPER + CTRL + H/J/K/L", action: "Resize window", category: "window" },
            { key: "SUPER + 1-9", action: "Workspace 1-9", category: "workspace" },
            { key: "SUPER + SHIFT + 1-9", action: "Move to workspace", category: "workspace" },
            { key: "SUPER + TAB", action: "Next workspace", category: "workspace" },
            { key: "SUPER + SHIFT + TAB", action: "Previous workspace", category: "workspace" },
            { key: "SUPER + M", action: "Toggle master", category: "layout" },
            { key: "SUPER + SHIFT + M", action: "Toggle monocle", category: "layout" },
            { key: "SUPER + G", action: "Toggle group", category: "layout" },
            { key: "SUPER + SHIFT + G", action: "Ungroup", category: "layout" },
            { key: "SUPER + E", action: "Open file manager", category: "apps" },
            { key: "SUPER + B", action: "Open browser", category: "apps" },
            { key: "SUPER + T", action: "Open terminal", category: "apps" },
            { key: "SUPER + D", action: "App launcher", category: "apps" },
            { key: "SUPER + S", action: "Screenshot region", category: "media" },
            { key: "SUPER + SHIFT + S", action: "Screenshot full", category: "media" },
            { key: "SUPER + ALT + S", action: "Screen record", category: "media" },
            { key: "SUPER + X", action: "Color picker", category: "tools" },
            { key: "SUPER + C", action: "Clipboard history", category: "tools" },
            { key: "SUPER + SHIFT + C", action: "Emoji picker", category: "tools" },
            { key: "SUPER + N", action: "Notes", category: "tools" },
            { key: "SUPER + ESC", action: "Close popups/panels", category: "general" },
            { key: "SUPER + SHIFT + R", action: "Reload Hyprland", category: "general" },
            { key: "SUPER + SHIFT + E", action: "Exit Hyprland", category: "general" },
        ]
    }

    // Filter by category
    property var filteredKeybinds: []

    function updateFiltered() {
        if (root.currentCategory === "all") {
            root.filteredKeybinds = root.keybinds.all
        } else {
            root.filteredKeybinds = root.keybinds.all.filter((kb) => kb.category === root.currentCategory)
        }
    }

    Component.onCompleted: {
        updateFiltered()
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Category filter tabs
        Row {
            spacing: 5
            Repeater {
                model: ["all", "window", "panel", "workspace", "layout", "apps", "media", "tools", "general"]
                delegate: Button {
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    checked: root.currentCategory === modelData
                    onClicked: { root.currentCategory = modelData; root.updateFiltered() }
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 11
                    background: Rectangle {
                        color: root.currentCategory === modelData ? qs.theme.Theme.accentBg : qs.theme.Theme.color0
                        border.color: root.currentCategory === modelData ? qs.theme.Theme.accent : qs.theme.Theme.color8
                        border.width: 1
                        radius: 4
                    }
                }
            }
        }

        // Keybind list
        Column {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 5

            Repeater {
                model: root.filteredKeybinds
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
                        spacing: 15

                        // Key
                        Rectangle {
                            width: 80
                            height: 28
                            radius: 4
                            color: qs.theme.Theme.accentBg
                            border.color: qs.theme.Theme.accent
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.key
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 11
                                font.bold: true
                                color: qs.theme.Theme.accent
                            }
                        }

                        // Action
                        Text {
                            text: modelData.action
                            font.family: "JetBrainsMono NFP"
                            font.pixelSize: 12
                            color: qs.theme.Theme.foreground
                            Layout.fillWidth: true
                        }

                        // Category badge
                        Rectangle {
                            width: 70
                            height: 20
                            radius: 10
                            color: qs.theme.Theme.color8

                            Text {
                                anchors.centerIn: parent
                                text: modelData.category
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 8
                                color: qs.theme.Theme.foreground
                            }
                        }
                    }
                }
            }
        }
    }
}