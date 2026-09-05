import QtQuick
import Quickshell
import qs.theme
import qs.services
import Quickshell.Networking

// Port of barStates/NetworkWidget.tsx — compact network status + signal.
// Uses Quickshell.Networking (Networking singleton → devices, each a NetworkDevice).
Item {
    id: root

    property real widthRequest: 0

    // Derive the primary (most relevant) device: first connected, else first available.
    readonly property var device: {
        if (!Networking.devices?.values) return null
        for (const d of Networking.devices.values) {
            if (d && d.connected) return d
        }
        return Networking.devices.values.length > 0 ? Networking.devices.values[0] : null
    }
    readonly property bool connected: device?.connected ?? false
    readonly property int devState: device?.state ?? 0
    readonly property string devName: device?.name ?? "disconnected"
    readonly property bool isWifi: device?.type === DeviceType.Wifi

    // Extract SSID from connected wifi network's connectedNetwork (a WifiNetwork which has `id` field)
    // If no primaryDevice, show "Disconnected". If wired, show the interface name (e.g. "enp0s3").
    // WifiNetwork has id (ssid). Check activeWifiDevice.
    readonly property string label: {
        if (!device || !connected) return "Disconnected"
        if (isWifi) {
            // Look for connected network in the device's networks list (Network.name = SSID)
            if (device.networks?.values) {
                for (const nw of device.networks.values) {
                    if (nw && nw.connected) return nw.name ?? devName
                }
            }
            return devName
        }
        return devName
    }

    // Signal strength (wifi only, from WifiNetwork if available)
    readonly property int signal: {
        if (!isWifi || !device?.networks?.values) return 0
        for (const nw of device.networks.values) {
            if (nw && nw.connected) return Math.round((nw.signalStrength ?? 0) * 100)
        }
        return 0
    }

    // Icons (Nerd Font glyphs)
    readonly property string icon: {
        if (connected) {
            if (isWifi) {
                if (signal > 75) return "\uF0E2"  // 󰗉
                if (signal > 50) return "\uF067"  // 󰚧
                if (signal > 25) return "\uF068"  // 󰚨
                return "\uF069"                    // 󰚩
            }
            return "\uF020"  // 󰈀 (ethernet)
        }
        return "\uF074"  // 󰑴 (disconnected)
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 8
        color: root.connected ? Theme.moduleBg : Theme.color0
        border.color: Theme.color8
        border.width: 1

        Row {
            anchors.fill: parent
            spacing: 6
            anchors.margins: 8

            Text {
                id: netIcon
                text: root.icon
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 14
                color: root.connected ? Theme.color2 : Theme.color8
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                text: root.label
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.foreground
                elide: Text.ElideRight
                width: 120
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                visible: root.signal > 0
                text: root.signal + "%"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
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
        onHoveredChanged: if (hovered) BarState.activate("network", 3000)
    }
}
