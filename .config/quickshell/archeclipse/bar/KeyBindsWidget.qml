import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme

// Key Binds widget — port of AGS KeyBinds.tsx + KeyBind.tsx
// Loads keybinds from ~/.config/ags/scripts/get-keybinds.sh (JSON),
// groups by category, renders each binding as an array of key chips
// joined by "+", per AGS.
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    // keybinds shape from get-keybinds.sh: { category: [{ description, keys: [] }] }
    property var keybinds: ({})
    property bool loading: true

    // ---- load keybinds from script (AGS execAsync get-keybinds.sh -> JSON.parse) ----
    Process {
        id: loadProc
        command: [Quickshell.env("HOME") + "/.config/ags/scripts/get-keybinds.sh"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text)
                    root.keybinds = parsed
                } catch (e) {
                    console.warn("[KeyBindsWidget] Failed to parse get-keybinds.sh JSON:", text.slice(0, 200))
                }
                root.loading = false
            }
        }
    }

    // sorted category names
    property var categories: Object.keys(root.keybinds).sort()

    // ---- UI: vertical category list exactly like AGS (no filter row) ----
    Column {
        anchors.fill: parent
        spacing: 10

        Label {
            text: "Key Binds"
            font.pixelSize: Theme.fontSize + 4
            font.bold: true
            color: Theme.fg
            width: parent.width
        }

        // Loading indicator
        BusyIndicator {
            running: root.loading
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.loading
        }

        ScrollView {
            width: parent.width
            // Guarded: a negative height sends Flickable into a silent polish loop
            height: Math.max(0, parent.height - y)
            clip: true
            visible: !root.loading

            Column {
                width: parent.width
                spacing: 10

                Repeater {
                    model: root.categories
                    delegate: Column {
                        required property string modelData
                        property string category: modelData
                        width: parent.width
                        spacing: 5

                        Label {
                            text: category
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                            color: Theme.fg
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width
                        }

                        // binds within this category
                        Repeater {
                            model: root.keybinds[category] || []
                            delegate: Rectangle {
                                required property var modelData
                                property var bindKeys: modelData.keys || []
                                width: parent.width
                                color: "transparent"
                                height: 28
                                Row {
                                    anchors.fill: parent
                                    spacing: 10
                                    Label {
                                        text: modelData.description
                                        font.pixelSize: Theme.fontSize
                                        color: Theme.fg
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        width: parent.width - keysRow.width - 10
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    // key chips joined by "+" (AGS KeyBind)
                                    Row {
                                        id: keysRow
                                        spacing: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        Repeater {
                                            model: bindKeys
                                            delegate: Row {
                                                required property string modelData
                                                required property int index
                                                spacing: 3
                                                Rectangle {
                                                    width: kChip.implicitWidth + 10
                                                    height: 22
                                                    radius: 4
                                                    color: Theme.moduleBg
                                                    border.width: 1
                                                    border.color: Theme.border
                                                    Label {
                                                        id: kChip
                                                        anchors.centerIn: parent
                                                        text: modelData
                                                        font.pixelSize: Theme.fontSize - 1
                                                        font.bold: true
                                                        color: Theme.accent
                                                        font.family: "JetBrainsMono NFP"
                                                    }
                                                }
                                                Label {
                                                    text: "+"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: index < (bindKeys.length - 1)
                                                    color: Theme.fgDim
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
        }
    }
}
