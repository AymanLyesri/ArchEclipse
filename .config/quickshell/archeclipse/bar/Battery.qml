import QtQuick
import Quickshell.Services.UPower
import qs.theme

// Port of sub-components/Battery.tsx — icon + %, hidden when no battery.
// Power-profile popover deferred to the panel migration phase.
Rectangle {
    id: root
    width: visible ? content.width + 8 : 0
    height: 22
    radius: Theme.radius
    color: hover.hovered ? Theme.buttonHoverBg : "transparent"

    readonly property real pct: UPower.displayDevice?.percentage ?? 1
    readonly property bool present: UPower.displayDevice?.isLaptopBattery ?? false
    visible: present

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spacing
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                const p = root.pct;
                const charging = UPower.displayDevice?.state === UPowerDeviceState.Charging;
                if (charging) return "\u{F00E2}";
                return p > 0.9 ? "\u{F007E}" : p > 0.7 ? "\u{F07E}" : p > 0.5 ? "\u{F07D}" : p > 0.3 ? "\u{F07C}" : p > 0.15 ? "\u{F07B}" : "\u{F07A}";
            }
            color: root.pct < 0.15 ? "#a94545" : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.floor(root.pct * 100) + "%"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    HoverHandler { id: hover }
}
