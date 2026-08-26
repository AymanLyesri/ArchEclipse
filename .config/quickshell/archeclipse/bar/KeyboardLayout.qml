import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Port of sub-components/KeyboardLayout.tsx.
// Click: hyprctl switchxkblayout current next. Right-click toggles flag emoji.
Item {
    id: root

    property string layout: ""
    property string layoutName: ""
    readonly property var flagMap: ({ "English (US)": "🇺🇸", "German": "🇩🇪", "French": "🇫🇷", "Arabic": "🇸🇦" })
    property bool showFlag: false

    width: visible && layout.length > 0 ? kbdLabel.width + 12 : 0
    height: 22
    visible: layout.length > 0

    Process {
        id: query
        command: ["sh", "-c", "hyprctl -j devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const devs = JSON.parse(text);
                    const kbds = devs.keyboards?.filter(k => k.main) ?? [];
                    if (kbds.length > 0) {
                        root.layout = kbds[0].active_keymap ?? "";
                        root.layoutName = kbds[0].name ?? "";
                    }
                } catch (e) { console.warn("[KeyboardLayout]", e); }
            }
        }
    }

    Timer {  // layout changes are rare — slow refresh, no busy polling
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: query.running = true
    }

    Text {
        id: kbdLabel
        anchors.centerIn: parent
        text: root.showFlag ? (root.flagMap[root.layout] ?? root.layout) : root.layout.slice(0, 2).toUpperCase()
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) root.showFlag = !root.showFlag;
            else Quickshell.execDetached(["hyprctl", "switchxkblayout", "current", "next"]);
        }
    }
}
