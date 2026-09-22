import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.theme
import qs.widgets.shared

// Connectivity section (Network + Bluetooth share one dropdown).
// Moved verbatim out of ControlPanelBody so the body only composes
// sections; behavior (hover-expand, 8s poll, nmcli/bluetoothctl) unchanged.
Item {
    id: root
    height: connCard.height

    property bool sectionOpen: false

    // ---- network (Quickshell.Networking + nmcli actions) ----
    readonly property var netDevice: {
        if (!Networking.devices?.values)
            return null;
        for (const d of Networking.devices.values) {
            if (d && d.connected)
                return d;
        }
        return Networking.devices.values.length > 0 ? Networking.devices.values[0] : null;
    }
    readonly property var wifiDevice: {
        if (!Networking.devices?.values)
            return null;
        for (const d of Networking.devices.values) {
            if (d && d.type === DeviceType.Wifi)
                return d;
        }
        return null;
    }
    readonly property var wifiNetworks: {
        const dev = root.wifiDevice;
        if (!dev?.networks?.values)
            return [];
        return dev.networks.values.slice().sort((a, b) => (b.signalStrength ?? 0) - (a.signalStrength ?? 0)).slice(0, 6);
    }
    readonly property string netStatus: {
        const dev = root.netDevice;
        if (!dev || !dev.connected)
            return "Disconnected";
        if (root.wifiDevice && dev === root.wifiDevice) {
            for (const nw of root.wifiNetworks) {
                if (nw && nw.connected)
                    return nw.name ?? dev.name;
            }
        }
        return dev.name ?? "Connected";
    }

    // Wi-Fi radio state, polled via nmcli (refreshed on open + after toggles).
    property bool wifiEnabled: true
    function refreshWifi() {
        wifiProc.running = true;
    }
    property Process wifiProc: Process {
        command: ["bash", "-c", "nmcli -t -f WIFI g 2>/dev/null | tr -d ' \\n'"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiEnabled = (text.trim().toLowerCase() === "enabled")
        }
    }
    function setWifi(on) {
        Quickshell.execDetached(["bash", "-c", "nmcli radio wifi " + (on ? "on" : "off") + " && sleep 1"]);
        wifiRetry.restart();
    }
    Timer {
        id: wifiRetry
        interval: 1500
        onTriggered: root.refreshWifi()
    }
    function connectWifi(ssid) {
        const safe = (ssid ?? "").replace(/'/g, "'\\''");
        Quickshell.execDetached(["bash", "-c", "nmcli device wifi connect '" + safe + "' && notify-send 'Wi-Fi' 'Connected to " + safe + "' || notify-send 'Wi-Fi' 'Failed to connect to " + safe + "'"]);
    }

    // ---- bluetooth (bluetoothctl, polled while the section is open) ----
    property bool btAvailable: true
    property bool btPowered: false
    property var btDevices: []
    function refreshBt() {
        btShowProc.running = true;
        btListProc.running = true;
    }
    property Process btShowProc: Process {
        command: ["bash", "-c", "bluetoothctl show 2>/dev/null || echo MISSING"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                root.btAvailable = !t.includes("MISSING");
                root.btPowered = t.includes("Powered: yes");
            }
        }
    }
    property Process btListProc: Process {
        command: ["bash", "-c", "bluetoothctl devices 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.trim().split("\n")) {
                    const m = line.match(/^Device\s+([0-9A-F:]+)\s+(.+)$/);
                    if (m)
                        out.push({
                            mac: m[1],
                            name: m[2]
                        });
                }
                root.btDevices = out;
            }
        }
    }
    function setBtPower(on) {
        Quickshell.execDetached(["bash", "-c", "bluetoothctl power " + (on ? "on" : "off") + "; sleep 1"]);
        btRetry.restart();
    }
    Timer {
        id: btRetry
        interval: 1500
        onTriggered: root.refreshBt()
    }
    function connectBt(mac, name) {
        Quickshell.execDetached(["bash", "-c", "bluetoothctl connect " + mac + " && notify-send 'Bluetooth' 'Connected to " + (name ?? mac).replace(/'/g, "'\\''") + "' || notify-send 'Bluetooth' 'Failed to connect'"]);
    }

    readonly property string btStateText: !root.btAvailable ? "N/A" : (root.btPowered ? "On" : "Off")
    readonly property string connSummary: root.netStatus + " • BT " + root.btStateText

    Component.onCompleted: {
        root.refreshWifi();
        root.refreshBt();
    }
    // Slow poll while open (this section is transient — destroyed with the
    // island — so no leak after close).
    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: {
            root.refreshWifi();
            root.refreshBt();
        }
    }

    // Hover wrapper: Card forwards direct children to its content Column,
    // so the handler must not be a direct Card child.
    HoverHandler {
        id: connHover
        onHoveredChanged: root.sectionOpen = hovered
    }
    Card {
        id: connCard
        width: parent.width
        contentMargins: 12
        contentSpacing: 8
        height: contentMargins * 2 + headRow.height + (connBody.visible ? contentSpacing + connBody.height : 0)
        Behavior on height {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        // Header: icon + title + status, chevron pinned right; click toggles.
        Item {
            width: parent.width
            height: headRow.height
            Row {
                id: headRow
                width: parent.width - 22
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰖩"
                    color: Theme.fg
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 18
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Connectivity"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.connSummary
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    elide: Text.ElideRight
                    width: parent.width - 150
                }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.sectionOpen ? "\uf106" : "\uf107"
                color: Theme.muted
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 14
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                preventStealing: false
                propagateComposedEvents: true
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sectionOpen = !root.sectionOpen
            }
        }

        // Body: network subsection, divider, bluetooth subsection.
        Column {
            id: connBody
            width: parent.width
            spacing: 10
            visible: root.sectionOpen

            // ----- Network -----
            Column {
                width: parent.width
                spacing: 6
                Text {
                    text: "Network"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
                Row {
                    width: parent.width
                    spacing: 8
                    AppCheckBox {
                        text: "Wi-Fi"
                        checked: root.wifiEnabled
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        onToggled: root.setWifi(checked)
                    }
                    AppButton {
                        width: 70
                        height: 28
                        cornerRadius: Theme.chipRadius
                        idleBg: Theme.surface
                        text: "Rescan"
                        pixelSize: Theme.fontSize - 2
                        tooltipText: "Rescan Wi-Fi networks"
                        onClicked: Quickshell.execDetached(["bash", "-c", "nmcli device wifi rescan"])
                    }
                }
                // Visible access points (top 6 by signal); click connects.
                Column {
                    width: parent.width
                    spacing: 2
                    visible: root.wifiNetworks.length > 0
                    Repeater {
                        model: root.wifiNetworks
                        delegate: Rectangle {
                            id: apRow
                            required property var modelData
                            readonly property string ssid: modelData.name ?? "hidden"
                            readonly property bool linked: modelData.connected ?? false
                            readonly property int sig: Math.round((modelData.signalStrength ?? 0) * 100)

                            width: parent.width
                            // Explicit height (see AGENTS.md §2.3).
                            height: 26
                            radius: Theme.chipRadius
                            color: apRow.linked ? Theme.surfaceActive : "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 6
                                Text {
                                    text: apRow.linked ? "󰖩" : "󰖨"
                                    color: apRow.linked ? Theme.accent : Theme.muted
                                    font.family: "JetBrainsMono NFP"
                                    font.pixelSize: 13
                                    verticalAlignment: Text.AlignVCenter
                                    height: parent.height
                                }
                                Text {
                                    text: apRow.ssid
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 2
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    height: parent.height
                                    width: parent.width - 70
                                }
                                Text {
                                    text: apRow.sig + "%"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 2
                                    verticalAlignment: Text.AlignVCenter
                                    height: parent.height
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                preventStealing: false
                                propagateComposedEvents: true
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.connectWifi(apRow.ssid)
                            }
                        }
                    }
                }
            }

            // ----- Bluetooth -----
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
                visible: root.btAvailable
            }
            Column {
                width: parent.width
                spacing: 6
                visible: root.btAvailable
                Text {
                    text: "Bluetooth"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
                Row {
                    width: parent.width
                    spacing: 8
                    AppCheckBox {
                        text: "Power"
                        checked: root.btPowered
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        onToggled: root.setBtPower(checked)
                    }
                    AppButton {
                        width: 70
                        height: 28
                        cornerRadius: Theme.chipRadius
                        idleBg: Theme.surface
                        text: "Refresh"
                        pixelSize: Theme.fontSize - 2
                        tooltipText: "Refresh Bluetooth devices"
                        onClicked: root.refreshBt()
                    }
                }
                Column {
                    width: parent.width
                    spacing: 2
                    visible: root.btDevices.length > 0
                    Repeater {
                        model: root.btDevices
                        delegate: Rectangle {
                            id: btRow
                            required property var modelData
                            readonly property string mac: modelData.mac
                            readonly property string devName: modelData.name

                            width: parent.width
                            height: 26
                            radius: Theme.chipRadius
                            color: "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 6
                                Text {
                                    text: "󰂯"
                                    color: Theme.muted
                                    font.family: "JetBrainsMono NFP"
                                    font.pixelSize: 13
                                    verticalAlignment: Text.AlignVCenter
                                    height: parent.height
                                }
                                Text {
                                    text: btRow.devName
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 2
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    height: parent.height
                                    width: parent.width - 40
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                preventStealing: false
                                propagateComposedEvents: true
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.connectBt(btRow.mac, btRow.devName)
                            }
                        }
                    }
                }
                Text {
                    visible: root.btPowered && root.btDevices.length === 0
                    text: "No devices found"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
            }
        }
    }
}
