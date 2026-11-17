import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.widgets.shared
import qs.services

// Plugins tab: install user plugins from a GitHub repo URL or a local file/folder and
// manage them (enable / rename / delete). An enabled plugin gets its own sidebar tab.
Item {
    id: root
    property string monitorName: ""

    property string repoUrl: ""
    property string localPath: ""

    Component.onCompleted: PluginManager.refresh()

    SmoothFlickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: pluginsCol.implicitHeight

        Column {
            id: pluginsCol
            width: parent.width
            spacing: Theme.spaceMd

            Text {
                width: parent.width
                text: "Plugins"
                color: Theme.fg
                font.pixelSize: Theme.typeTitle
                font.family: Theme.fontFamily
            }
            Text {
                width: parent.width
                text: "Install a plugin from its GitHub repo, or upload its folder / zip by hand. Every enabled plugin appears as its own tab in the sidebar."
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                wrapMode: Text.WordWrap
            }

            Card {
                width: parent.width
                height: installCol.implicitHeight + Theme.pad * 2
                Column {
                    id: installCol
                    width: parent.width
                    spacing: Theme.spaceSm
                    SettingLabel {
                        text: "Install from GitHub"
                    }
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spaceSm
                        AppTextField {
                            Layout.fillWidth: true
                            placeholderText: "https://github.com/user/plugin"
                            text: root.repoUrl
                            onTextChanged: root.repoUrl = text
                        }
                        AppButton {
                            text: PluginManager.busy ? "Working..." : "Install"
                            enabled: !PluginManager.busy && root.repoUrl.trim() !== ""
                            onClicked: PluginManager.installFromGit(root.repoUrl)
                        }
                    }
                    SettingLabel {
                        text: "Manual upload"
                    }
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spaceSm
                        AppTextField {
                            Layout.fillWidth: true
                            placeholderText: "/path/to/folder or plugin.zip"
                            text: root.localPath
                            onTextChanged: root.localPath = text
                        }
                        AppButton {
                            text: "Browse"
                            onClicked: pickProc.running = true
                        }
                        AppButton {
                            text: "Install"
                            enabled: !PluginManager.busy && root.localPath.trim() !== ""
                            onClicked: {
                                const p = root.localPath.trim();
                                if (p.toLowerCase().endsWith(".zip"))
                                    PluginManager.installFromArchive(p);
                                else
                                    PluginManager.installFromFolder(p);
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        visible: PluginManager.lastError !== ""
                        text: PluginManager.lastError
                        color: Theme.danger
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Text {
                width: parent.width
                visible: (PluginManager.plugins || []).length === 0
                text: "No plugins yet. Install one above to get started."
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
            }

            Repeater {
                model: PluginManager.plugins
                delegate: Card {
                    id: rowCard
                    width: root.width
                    height: rowCol.implicitHeight + Theme.pad * 2
                    property var plugin: modelData
                    Column {
                        id: rowCol
                        width: parent.width
                        spacing: Theme.spaceSm
                        RowLayout {
                            width: parent.width
                            spacing: Theme.spaceSm
                            AppToggle {
                                checked: rowCard.plugin.enabled !== false
                                onToggled: PluginManager.setEnabled(rowCard.plugin.id, checked)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: rowCard.plugin.name || rowCard.plugin.id
                                color: Theme.fg
                                font.pixelSize: Theme.fontSize
                                font.family: Theme.fontFamily
                                elide: Text.ElideRight
                            }
                            AppButton {
                                text: "Open"
                                enabled: rowCard.plugin.enabled !== false
                                onClicked: Registry.selectLeftTab("Plugin:" + rowCard.plugin.id, undefined, root.monitorName)
                            }
                            AppButton {
                                text: "Delete"
                                onClicked: PluginManager.removePlugin(rowCard.plugin.id)
                            }
                        }
                        AppTextField {
                            width: parent.width
                            placeholderText: "Rename plugin"
                            text: rowCard.plugin.name || ""
                            onEditingFinished: {
                                if (text.trim() !== "" && text !== rowCard.plugin.name)
                                    PluginManager.renamePlugin(rowCard.plugin.id, text);
                            }
                        }
                        Text {
                            width: parent.width
                            text: rowCard.plugin.enabled !== false ? "Shown as a sidebar tab" : "Disabled - hidden from the sidebar"
                            color: Theme.muted
                            font.pixelSize: Theme.fontSizeCaption
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    // File picker for manual upload (zenity argv flow, same as WaifuWidget).
    Process {
        id: pickProc
        command: ["zenity", "--file-selection", "--title=Select plugin folder or zip"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path !== "")
                    root.localPath = path;
            }
        }
    }
}
