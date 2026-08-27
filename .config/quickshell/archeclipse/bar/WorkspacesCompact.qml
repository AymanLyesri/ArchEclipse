import Quickshell
import QtQuick
import qs.theme
import qs.services
import Quickshell.Hyprland

Item {
    id: root

    // Hyprland workspaces model
    property var workspaceModel: Hyprland.workspaces
    property var icons: qs.services.WorkspaceIcons
    property bool showNumbers: qs.theme.Settings.bar.workspaceNumbers.value ?? false

    // Compact: single row of all workspaces (occupied first, then empty singles)
    property var allWorkspaces: []

    function updateWorkspaces() {
        const workspaces = workspaceModel.values
        const occupied = workspaces.filter((ws) => ws.windows > 0)
        const empty = workspaces.filter((ws) => ws.windows === 0)

        occupied.sort((a, b) => a.id - b.id)
        empty.sort((a, b) => a.id - b.id)

        root.allWorkspaces = [...occupied, ...empty]
    }

    Component.onCompleted: {
        updateWorkspaces()
        workspaceModel.onChanged = updateWorkspaces
    }

    Row {
        id: row
        anchors.fill: parent
        spacing: 2

        Repeater {
            model: root.allWorkspaces
            delegate: Item {
                width: 28
                height: 28

                property var workspace: modelData
                property bool isFocused: workspace.id === Hyprland.focusedWorkspace?.id
                property bool hasWindows: workspace.windows > 0

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("workspace " + workspace.id)
                }

                Rectangle {
                    id: bg
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: 5
                    color: isFocused ? qs.theme.Theme.accent : (hasWindows ? qs.theme.Theme.color8 : "transparent")
                    border.color: hasWindows && !isFocused ? qs.theme.Theme.color4 : "transparent"
                    border.width: hasWindows && !isFocused ? 1 : 0

                    Text {
                        anchors.centerIn: parent
                        text: icons.getIcon(workspace.id, workspace.name)
                        font.family: "JetBrainsMono NFP"
                        font.pixelSize: 12
                        color: isFocused ? qs.theme.Theme.background : qs.theme.Theme.foreground
                    }
                }

                Text {
                    visible: showNumbers && hasWindows
                    anchors.bottom: bg.bottom
                    anchors.right: bg.right
                    font.pixelSize: 7
                    color: qs.theme.Theme.color8
                    text: workspace.id.toString()
                }
            }
        }
    }

    function measureWidth() {
        const [, natural] = row.measure(Qt.Horizontal, -1)
        return natural
    }
}