import Quickshell
import QtQuick
import qs.theme
import Quickshell.Networking

Item {
    id: root

    property real widthRequest: 0

    // Network device
    property var device: Quickshell.Networking.primaryDevice

    // Connection state
    property string state: device?.state ?? "disconnected"
    property string ssid: device?.ssid ?? ""
    property int signalStrength: device?.signalStrength ?? 0

    // Icon based on state
    property string icon: {
        if (state === "connected" || state === "activated") {
            if (device?.type === "wifi") {
                if (signalStrength > 75) return "󰤨"
                if (signalStrength > 50) return "󰤥"
                if (signalStrength > 25) return "󰤢"
                return "󰤟"
            }
            return "󰈀"
        }
        return "󰖪"
    }()

    // Main layout
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 8
        color: qs.theme.Theme.color0
        border.color: qs.theme.Theme.color8
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
                color: state === "connected" ? qs.theme.Theme.color2 : qs.theme.Theme.color8
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                visible: root.ssid !== ""
                text: root.ssid
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 11
                color: qs.theme.Theme.foreground
                elide: Text.ElideRight
                width: 150
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                visible: root.signalStrength > 0 && device?.type === "wifi"
                text: root.signalStrength + "%"
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 10
                color: qs.theme.Theme.color8
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // Click to show network widget
    MouseArea {
        anchors.fill: parent
        onClicked: {
            qs.services.BarState.activateState("network", 3000)
        }
    }

    // Hover handler
    HoverHandler {
        onEntered: qs.services.BarState.activateState("network", 3000)
    }
}