import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services

// Port of widgets/bar/components/sub-components/KeyboardLayout.tsx
// Shows current keyboard layout, click to cycle, right-click to show flag emoji
Item {
    id: root
    height: 22
    width: 40  // Fixed width to avoid binding loop

    property bool showFlag: false

    // Process for switching layout (AGS hyprctlCommand injects
    // -i $HYPRLAND_INSTANCE_SIGNATURE — plain hyprctl breaks with
    // multiple Hyprland instances).
    property Process _switchLayoutProc: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    console.warn("[KeyboardLayout] Failed to switch layout: " + text);
                }
            }
        }
        Component.onCompleted: {
            const cmd = ["hyprctl", "switchxkblayout", "current", "next"];
            const signature = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
            if (signature) cmd.splice(1, 0, "-i", signature);
            command = cmd;
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 4

        MouseArea {
            width: text.width
            height: parent.height
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            onClicked: {
                if (mouse.button === Qt.RightButton) {
                    root.showFlag = !root.showFlag;
                } else if (mouse.button === Qt.LeftButton) {
                    root._switchLayoutProc.running = true;
                }
            }
            ToolTip.visible: hovered
            ToolTip.text: KeyboardLayout.layoutName
        }

        Text {
            id: text
            anchors.verticalCenter: parent.verticalCenter
            text: root.showFlag ? (KeyboardLayout.flagEmoji(KeyboardLayout.layout) || KeyboardLayout.layout) : KeyboardLayout.layout
            visible: KeyboardLayout.layout.length > 0
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}