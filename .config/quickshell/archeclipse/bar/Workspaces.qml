import QtQuick
import Quickshell.Hyprland
import qs.theme
import qs.services

// Port of Workspaces.tsx (full, grouped) and WorkspacesCompact.
//
// Full mode: workspaces 1..max(existing,10); occupied ones are grouped into a
// pill ("workspace-group active"), empties stand alone. Focused = highlighted,
// inactive = 0.4 opacity. Click dispatches focus. Special-workspace toggle on
// the left.
Row {
    id: root

    property bool compact: false
    spacing: Theme.spacing

    // snapshot of workspace state: [{id, exists, icon}]
    readonly property var wsModel: {
        Hyprland.workspaces.values;      // reactive dep
        const focused = Hyprland.focusedWorkspace?.id;
        const map = new Map();
        for (const w of Hyprland.workspaces.values) {
            let icon = WorkspaceIcons.extraIcon;
            const tops = Hyprland.toplevels.values.filter(t => t.workspace?.id === w.id);
            if (tops.length > 0)
                icon = WorkspaceIcons.forClientClass(tops[0].lastIpcObject?.class ?? "");
            map.set(w.id, { id: w.id, exists: true, icon });
        }
        const maxId = Math.max(10, ...map.keys());
        const out = [];
        for (let i = 1; i <= maxId; i++) {
            if (compact && !map.has(i)) continue;   // compact shows only existing 1..10
            out.push(map.get(i) ?? { id: i, exists: false, icon: WorkspaceIcons.emptyIcon });
        }
        return out.slice(0, compact ? 10 : maxId);
    }

    readonly property bool specialActive: {
        Hyprland.focusedWorkspace?.id;
        return (Hyprland.focusedWorkspace?.id ?? 1) < 0;
    }

    // ---- special workspace button ----
    Rectangle {
        visible: !root.compact
        radius: Theme.radius
        color: root.specialActive ? Theme.buttonCheckedBg : "transparent"
        width: specialLabel.implicitWidth + 12
        height: parent.height - 6
        anchors.verticalCenter: parent.verticalCenter

        Behavior on color { ColorAnimation { duration: 200 } }

        Text {
            id: specialLabel
            anchors.centerIn: parent
            text: WorkspaceIcons.specialIcon
            color: root.specialActive ? Theme.buttonCheckedFg : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Hyprland.dispatch("workspace togglespecialworkspace")
        }
    }

    // ---- grouped workspaces ----
    Row {
        spacing: 0

        Repeater {
            model: root.wsModel

            Rectangle {
                id: btn
                required property var modelData
                readonly property int wid: modelData.id
                readonly property bool exists: modelData.exists
                readonly property bool focused: (Hyprland.focusedWorkspace?.id ?? 1) === wid

                radius: Theme.radius
                color: focused ? (root.compact ? Theme.background : Theme.buttonCheckedBg) : "transparent"
                opacity: !exists ? 0.4 : 1.0
                implicitWidth: label.implicitWidth + (focused ? 24 : 8)   // is-focused min-width 50px feel
                implicitHeight: root.height > 0 ? root.height - 6 : 22
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color { ColorAnimation { duration: 300 } }
                Behavior on implicitWidth { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 300 } }

                Text {
                    id: label
                    anchors.centerIn: parent
                    textFormat: Text.RichText
                    text: Settings.workspaceNumbers && root.compact === false
                          ? modelData.icon + WorkspaceIcons.numberBadge(btn.wid)
                          : (Settings.workspaceNumbers ? modelData.icon + WorkspaceIcons.numberBadge(btn.wid) : modelData.icon)
                    color: btn.focused && !root.compact ? Theme.buttonCheckedFg : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${btn.wid}`)
                }
            }
        }
    }
}
