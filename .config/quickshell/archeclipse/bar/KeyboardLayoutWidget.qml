import QtQuick
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

    // Process for switching layout
    property Process _switchLayoutProc: Process {
        command: ["hyprctl", "switchxkblayout", "current", "next"]
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    console.warn("[KeyboardLayout] Failed to switch layout: " + text);
                }
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 4

        MouseArea {
            width: text.width
            height: parent.height
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {
                if (mouse.button === Qt.RightButton) {
                    root.showFlag = !root.showFlag;
                } else if (mouse.button === Qt.LeftButton) {
                    root._switchLayoutProc.running = true;
                }
            }
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