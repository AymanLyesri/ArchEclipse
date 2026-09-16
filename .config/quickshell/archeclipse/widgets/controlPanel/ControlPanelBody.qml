import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.theme
import qs.services
import qs.widgets.shared

// Quick-settings body: volume + brightness sliders + action buttons.
// Extracted verbatim from the old ControlPanel sidebar so it can live in
// the bar's dynamic island (ControlIsland) instead of a side window.
// Close behavior = BarState.deactivate("control").
Item {
    id: body

    property string monitorName: ""
    readonly property string effectiveMonitor: body.monitorName || Registry.monitorName

    width: 480
    height: contentCol.height + 32

    // ---- default sink for the volume slider ----
    readonly property PwNode controlSink: Pipewire.defaultAudioSink
    PwObjectTracker {
        objects: [controlSink]
    }

    // ---- dynamic brightness icon (3-level thresholds) ----
    readonly property string brightnessIcon: {
        const bri = Brightness.screen;
        if (bri > 0.75)
            return "\u{F00E0}";       // full (󰃠)
        if (bri > 0.5)
            return "\u{F00DF}";        // medium (󰃟)
        return "\u{F00DE}";                        // low (󰃞)
    }

    // DND ping state: highlight the DND button ~600ms when a
    // notification arrives while DND is active (AppButton `checked` drives
    // the highlight, so the flag lives here instead of on a Rectangle).
    property bool dndPing: false
    Connections {
        target: Notifications
        function onNotified() {
            if (Settings.notifDnd)
                body.dndPing = true;
            if (dndPingTimer.running)
                dndPingTimer.restart();
            else
                dndPingTimer.start();
        }
    }
    Connections {
        target: Settings
        function onNotifDndChanged() {
            if (!Settings.notifDnd)
                body.dndPing = false;
        }
    }
    Timer {
        id: dndPingTimer
        interval: 600
        onTriggered: body.dndPing = false
    }

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
        const dev = body.wifiDevice;
        if (!dev?.networks?.values)
            return [];
        return dev.networks.values.slice().sort((a, b) => (b.signalStrength ?? 0) - (a.signalStrength ?? 0)).slice(0, 6);
    }
    readonly property string netStatus: {
        const dev = body.netDevice;
        if (!dev || !dev.connected)
            return "Disconnected";
        if (body.wifiDevice && dev === body.wifiDevice) {
            for (const nw of body.wifiNetworks) {
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
            onStreamFinished: body.wifiEnabled = (text.trim().toLowerCase() === "enabled")
        }
    }
    function setWifi(on) {
        Quickshell.execDetached(["bash", "-c", "nmcli radio wifi " + (on ? "on" : "off") + " && sleep 1"]);
        wifiRetry.restart();
    }
    Timer {
        id: wifiRetry
        interval: 1500
        onTriggered: body.refreshWifi()
    }
    function connectWifi(ssid) {
        const safe = (ssid ?? "").replace(/'/g, "'\\''");
        Quickshell.execDetached(["bash", "-c", "nmcli device wifi connect '" + safe + "' && notify-send 'Wi-Fi' 'Connected to " + safe + "' || notify-send 'Wi-Fi' 'Failed to connect to " + safe + "'"]);
    }

    // ---- bluetooth (bluetoothctl, polled while the island is open) ----
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
                body.btAvailable = !t.includes("MISSING");
                body.btPowered = t.includes("Powered: yes");
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
                body.btDevices = out;
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
        onTriggered: body.refreshBt()
    }
    function connectBt(mac, name) {
        Quickshell.execDetached(["bash", "-c", "bluetoothctl connect " + mac + " && notify-send 'Bluetooth' 'Connected to " + (name ?? mac).replace(/'/g, "'\\''") + "' || notify-send 'Bluetooth' 'Failed to connect'"]);
    }
    // ---- power profiles (native UPower service; PpdState gates visibility) ----
    // PowerProfiles.profile is reactive + settable, so no polling needed for
    // the value itself. PpdState probes `powerprofilesctl get` once at
    // quickshell start — without PPD the section hides instead of showing
    // a dead control (e.g. PPD-less desktops).
    readonly property int powerIndex: {
        if (PowerProfiles.profile === PowerProfile.Performance)
            return 2;
        if (PowerProfiles.profile === PowerProfile.PowerSaver)
            return 0;
        return 1;
    }
    readonly property string powerLabel: {
        if (PowerProfiles.profile === PowerProfile.Performance)
            return "Performance";
        if (PowerProfiles.profile === PowerProfile.PowerSaver)
            return "Power Saver";
        return "Balanced";
    }
    Component.onCompleted: {
        body.refreshWifi();
        body.refreshBt();
    }
    // Slow poll while open (this body is transient — destroyed with the
    // island — so no leak after close).
    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: {
            body.refreshWifi();
            body.refreshBt();
        }
    }

    // ---- content ----
    Column {
        id: contentCol
        width: parent.width
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 16

        // ===== Connectivity (Network + Bluetooth share one dropdown) =====
        // Shared Card shell + AppCheckBox/AppButton + Theme-only styling.
        // Card needs an explicit height (Rectangle); it tracks the header
        // plus the open body, mirroring the contentCol.height pattern below.
        property bool connectivityOpen: true
        readonly property string btStateText: !body.btAvailable ? "N/A" : (body.btPowered ? "On" : "Off")
        readonly property string connSummary: body.netStatus + " • BT " + body.btStateText

        Card {
            id: connCard
            width: parent.width
            contentMargins: 12
            contentSpacing: 8
            height: contentMargins * 2 + headRow.height + (connBody.visible ? contentSpacing + connBody.height : 0)

            // Header: icon + title + combined status + chevron; click toggles.
            Row {
                id: headRow
                width: parent.width
                spacing: 8
                Text {
                    text: "󰖩"
                    color: Theme.fg
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 18
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    text: "Connectivity"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    text: body.connSummary
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    width: parent.width - 150
                }
                Text {
                    text: body.connectivityOpen ? "\uf107" : "\uf106"
                    color: Theme.muted
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    preventStealing: false
                    propagateComposedEvents: true
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: body.connectivityOpen = !body.connectivityOpen
                }
            }

            // Body: network subsection, divider, bluetooth subsection.
            Column {
                id: connBody
                width: parent.width
                spacing: 10
                visible: body.connectivityOpen

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
                            checked: body.wifiEnabled
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            onToggled: body.setWifi(checked)
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
                        visible: body.wifiNetworks.length > 0
                        Repeater {
                            model: body.wifiNetworks
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
                                    onClicked: body.connectWifi(apRow.ssid)
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
                    visible: body.btAvailable
                }
                Column {
                    width: parent.width
                    spacing: 6
                    visible: body.btAvailable
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
                            checked: body.btPowered
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            onToggled: body.setBtPower(checked)
                        }
                        AppButton {
                            width: 70
                            height: 28
                            cornerRadius: Theme.chipRadius
                            idleBg: Theme.surface
                            text: "Refresh"
                            pixelSize: Theme.fontSize - 2
                            tooltipText: "Refresh Bluetooth devices"
                            onClicked: body.refreshBt()
                        }
                    }
                    Column {
                        width: parent.width
                        spacing: 2
                        visible: body.btDevices.length > 0
                        Repeater {
                            model: body.btDevices
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
                                    onClicked: body.connectBt(btRow.mac, btRow.devName)
                                }
                            }
                        }
                    }
                    Text {
                        visible: body.btPowered && body.btDevices.length === 0
                        text: "No devices found"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }
        }

        // ===== Volume =====
        Column {
            width: parent.width
            spacing: 6
            Row {
                width: parent.width
                spacing: 8
                Text {
                    text: VolumeWatcher.volumeIcon
                    color: Theme.fg
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 18
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    text: "Volume"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
            }
            AppSlider {
                id: volSlider
                width: parent.width
                from: 0
                to: 1
                stepSize: 0.01
                value: body.controlSink?.audio?.volume ?? 0
                onMoved: if (body.controlSink?.audio)
                    body.controlSink.audio.volume = volSlider.value
            }
        }

        // ===== Brightness =====
        Column {
            width: parent.width
            spacing: 6
            visible: Brightness.hasBacklight
            Row {
                width: parent.width
                spacing: 8
                Text {
                    text: body.brightnessIcon
                    color: Theme.fg
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 18
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    text: "Brightness"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
            }
            AppSlider {
                id: brightSlider
                width: parent.width
                from: 0
                to: 1
                stepSize: 0.01
                value: Brightness.screen
                onMoved: Brightness.setScreen(brightSlider.value)
            }
        }

        // ===== Power profile (power-profiles-daemon, native UPower service) =====
        Column {
            width: parent.width
            spacing: 6
            visible: PpdState.available
            Row {
                width: parent.width
                spacing: 8
                Text {
                    text: "󰓅"
                    color: Theme.fg
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 18
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    text: "Power"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    text: body.powerLabel
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    verticalAlignment: Text.AlignVCenter
                }
            }
            AppSegmentedControl {
                pixelSize: Theme.fontSize - 1
                model: [
                    {
                        value: PowerProfile.PowerSaver,
                        label: "Power Saver",
                        tooltip: "Limit performance to save power"
                    },
                    {
                        value: PowerProfile.Balanced,
                        label: "Balanced",
                        tooltip: "Balance performance and power"
                    },
                    {
                        value: PowerProfile.Performance,
                        label: "Performance",
                        tooltip: PowerProfiles.hasPerformanceProfile ? "Maximize performance" : "Performance not available on this system",
                        enabled: PowerProfiles.hasPerformanceProfile
                    }
                ]
                currentIndex: body.powerIndex
                onActivated: (i, v) => PowerProfiles.profile = v
            }
        }

        // ===== Action buttons (shared AppButton cells) =====
        Row {
            width: parent.width
            spacing: 10
            // Theme toggle
            AppButton {
                width: 46
                height: 46
                cornerRadius: Theme.radius
                idleBg: Theme.surface
                icon: GlobalTheme.currentTheme ? "\uf185" : "\uf186"
                pixelSize: Theme.fontSize + 2
                tooltipText: GlobalTheme.currentTheme ? "Switch to Light Theme" : "Switch to Dark Theme"
                onClicked: GlobalTheme.setTheme(!GlobalTheme.currentTheme)
            }
            // DND toggle
            AppButton {
                width: 46
                height: 46
                cornerRadius: Theme.radius
                idleBg: Theme.surface
                icon: Settings.notifDnd ? "\uf1f6" : "\uf0f3"
                pixelSize: Theme.fontSize + 2
                toggle: true
                checked: Settings.notifDnd || body.dndPing
                tooltipText: Settings.notifDnd ? "Disable Do Not Disturb" : "Enable Do Not Disturb"
                onClicked: Settings.updateSetting("notifications.dnd", !Settings.notifDnd)
            }
            AppButton {
                width: 46
                height: 46
                cornerRadius: Theme.radius
                idleBg: Theme.surface
                icon: "\udb83\ude09"
                pixelSize: Theme.fontSize + 2
                tooltipText: "Wallpaper Switcher\n<b>SUPER + W</b>"
                onClicked: {
                    BarState.deactivate("control");
                    if (BarState.state === "wallpaper")
                        BarState.deactivate("wallpaper");
                    else
                        BarState.activate("wallpaper", 0);
                }
            }
            // Keyboard layout — shows the current layout code, click cycles
            AppButton {
                width: 46
                height: 46
                cornerRadius: Theme.radius
                idleBg: Theme.surface
                text: KeyboardLayout.layout
                visible: KeyboardLayout.layout !== ""
                pixelSize: Theme.fontSize + 2
                tooltipText: (KeyboardLayout.layoutName || "Keyboard Layout") + "\nClick to switch layout"
                onClicked: KeyboardLayout.nextLayout()
            }
        }
    }
}
