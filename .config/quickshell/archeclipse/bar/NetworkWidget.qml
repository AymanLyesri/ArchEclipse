import Quickshell
import QtQuick
import qs.theme
import qs.services
import Quickshell.Networking

// Port of barStates NetworkWidget.tsx — compact network status + signal.
Item {
    id: root

    property real widthRequest: 0
    property var device: Quickshell.Networking.primaryDevice
    property string state: device?.state ?? "disconnected"
    property string ssid: device?.ssid ?? ""
    property int signalStrength: device?.signalStrength ?? 0

    property string icon: {
        if (state === "connected" || state === "activated") {
            if (device?.type === "wifi") {
                if (signalStrength > 75) return "\u{F0E2}"
                if (signalStrength > 50) return "\u{F067}"
                if (signalStrength > 25) return "\u{F068}"
                return "\u{F069}"
            }
            return "\u{F020}"
        }
        return "\u{F074}"
    }()

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 8
        color: Theme.color0
        border.color: Theme.color8
        border.width: 1

        Row {
            anchors.fill: parent
            spacing: 8
            anchors.margins: 12

            Text {
                id: netIcon
                text: root.icon
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 16
                color: state === "connected" ? Theme.color2 : Theme.color8
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                visible: root.ssid !== ""
                text: root.ssid
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 11
                color: Theme.foreground
                elide: Text.ElideRight
                width: 150
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                visible: root.signalStrength > 0 && device?.type === "wifi"
                text: root.signalStrength + "%"
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 10
                color: Theme.color8
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: BarState.activate("network", 3000)
    }

    HoverHandler {
        onEntered: BarState.activate("network", 3000)
    }
}
