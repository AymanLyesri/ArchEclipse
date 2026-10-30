import QtQuick
import Quickshell
import qs.theme
import qs.services
import Quickshell.Networking

// Port of barStates/NetworkWidget.tsx — compact network status + signal.
// Uses Quickshell.Networking (Networking singleton → devices, each a NetworkDevice).
Rectangle {
    id: root

    property string monitorName: ""
    property real widthRequest: 0

    // Side-pill shell: same recipe as MediaPill/WeatherButton (theme
    // surface, radius, sidePillHeight) so it reads as a chained sibling.
    height: Theme.sidePillHeight
    implicitWidth: contentRow.implicitWidth + Theme.islandPad * 2
    width: implicitWidth
    radius: Theme.radius
    color: netHover.hovered ? Theme.surfaceHover : Theme.surfaceActive

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim.fastEffects
        }
    }

    // Derive the primary (most relevant) device: first connected, else first available.
    readonly property var device: {
        if (!Networking.devices?.values)
            return null;
        for (const d of Networking.devices.values) {
            if (d && d.connected)
                return d;
        }
        return Networking.devices.values.length > 0 ? Networking.devices.values[0] : null;
    }
    readonly property bool connected: device?.connected ?? false
    readonly property int devState: device?.state ?? 0
    readonly property string devName: device?.name ?? "disconnected"
    readonly property bool isWifi: device?.type === DeviceType.Wifi

    // SSID from the connected wifi network's id; no primaryDevice -> "Disconnected", wired ->
    // the interface name (e.g. "enp0s3").
    readonly property string label: {
        if (!device || !connected)
            return "Disconnected";
        if (isWifi) {
            // Look for connected network in the device's networks list (Network.name = SSID)
            if (device.networks?.values) {
                for (const nw of device.networks.values) {
                    if (nw && nw.connected)
                        return nw.name ?? devName;
                }
            }
            return devName;
        }
        return devName;
    }

    // Signal strength (wifi only, from WifiNetwork if available)
    readonly property int signal: {
        if (!isWifi || !device?.networks?.values)
            return 0;
        for (const nw of device.networks.values) {
            if (nw && nw.connected)
                return Math.round((nw.signalStrength ?? 0) * 100);
        }
        return 0;
    }

    // Icons (Nerd Font glyphs)
    readonly property string icon: {
        if (connected) {
            if (isWifi) {
                if (signal > 75)
                    return Icons.wifiStrong;
                if (signal > 50)
                    return Icons.wifiGood;
                if (signal > 25)
                    return Icons.wifiWeak;
                return Icons.wifiPoor;
            }
            return Icons.ethernet;
        }
        return Icons.networkOff;
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.spacing

        Text {
            id: netIcon
            text: root.icon
            font.family: "JetBrainsMono NFP"
            font.pixelSize: Theme.fontSize
            color: root.connected ? Theme.accent : Theme.muted
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fg
            elide: Text.ElideRight
            width: 120
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            visible: root.signal > 0
            text: root.signal + "%"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.muted
            verticalAlignment: Text.AlignVCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: BarState.activate("network", 3000, root.monitorName)
    }

    // Hover dwell (Settings.revealInPressure, 0 = instant) so brushing the
    // cursor across the bar doesn't pulse the island by accident.
    Timer {
        id: dwellTimer
        interval: Settings.revealInPressure
        repeat: false
        onTriggered: BarState.activate("network", 3000, root.monitorName)
    }

    HoverHandler {
        id: netHover
        onHoveredChanged: {
            if (netHover.hovered) {
                if (Settings.revealInPressure <= 0)
                    BarState.activate("network", 3000, root.monitorName);
                else
                    dwellTimer.restart();
            } else {
                dwellTimer.stop();
            }
        }
    }
}
