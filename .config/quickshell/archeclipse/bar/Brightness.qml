import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.theme

// Port of sub-components/BrightnessWidget.tsx (brightnessctl backend, same as
// services/brightness.ts). Hover reveals slider; icon/percent always visible.
Rectangle {
    id: root

    property real level: 1.0
    property bool pulse: false
    readonly property int fixedWidth: 220

    width: pulse ? fixedWidth : content.width
    height: 22
    radius: Theme.radius
    color: pulse ? Theme.moduleBg : "transparent"

    Process {
        id: getBri
        command: ["sh", "-c", "brightnessctl -m info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.split(",");
                if (m.length > 3) root.level = parseFloat(m[3].replace('%','')) / 100;   // field 3 = percent
            }
        }
    }
    Timer { interval: 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: getBri.running = true }

    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.level > 0.75 ? "\u{F00E0}" : root.level > 0.5 ? "\u{F00DF}" : "\u{F00DE}"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.level * 100) + "%"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        Slider {
            id: briSlider
            visible: root.pulse || hover.hovered
            width: visible ? 100 : 0
            anchors.verticalCenter: parent.verticalCenter
            from: 0.01; to: 1; stepSize: 0.01
            value: root.level
            onMoved: {
                root.level = briSlider.value;
                Quickshell.execDetached(["brightnessctl", "set", Math.round(briSlider.value * 100) + "%"]);
            }
        }
    }

    HoverHandler { id: hover }
}
