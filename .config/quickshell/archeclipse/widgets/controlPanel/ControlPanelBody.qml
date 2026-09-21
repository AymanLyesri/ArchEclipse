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

// Quick-settings body: two columns — left holds the audio + connectivity
// revealing cards (collapsed until hovered), right holds the action grid,
// brightness slider and power profile selector. Lives in the bar's dynamic
// island (ControlIsland) instead of a side window.
// Close behavior = BarState.deactivate("control").
Item {
    id: body

    property string monitorName: ""
    readonly property string effectiveMonitor: body.monitorName || Registry.monitorName

    width: 680
    height: contentRow.height + 32

    // ---- default sink for the audio card ----
    readonly property PwNode controlSink: Pipewire.defaultAudioSink
    PwObjectTracker {
        objects: [controlSink]
    }
    // Per-app playback streams track themselves so their volumes stay live.
    PwObjectTracker {
        objects: body.appStreams
    }
    // Count of app sliders currently dragged (delegates bump this).
    property int appPressed: 0

    // ---- audio device lists (sinks vs sources, no streams) ----
    readonly property var audioNodes: (Pipewire.nodes && Pipewire.nodes.values) ? Pipewire.nodes.values : []
    readonly property var outputDevices: body.audioNodes.filter(function (n) {
        return n && !n.isStream && n.isSink;
    })
    // Playback streams only (capture streams excluded via media.class,
    // falling back to the node type flag when metadata is not ready yet).
    readonly property var appStreams: body.audioNodes.filter(function (n) {
        if (!n || !n.isStream || !n.audio)
            return false;
        const mc = (n.properties && n.properties["media.class"]) || "";
        if (mc)
            return mc === "Stream/Output/Audio";
        try {
            if (typeof PwNodeType !== "undefined" && (n.type & PwNodeType.AudioInStream))
                return false;
        } catch (e) {}
        return true;
    })
    function streamLabel(n) {
        if (!n)
            return "Unknown app";
        if (n.properties) {
            const app = n.properties["application.name"] || n.properties["app.name"];
            if (app)
                return app;
        }
        return (n.nickname || n.description || n.name) || "Unknown app";
    }
    function deviceLabel(n) {
        return (n && (n.nickname || n.description || n.name)) || "Unknown";
    }
    readonly property var outputDeviceNames: body.outputDevices.map(function (n) {
        return body.deviceLabel(n);
    })
    readonly property int outputIndex: {
        const cur = body.controlSink;
        if (!cur)
            return -1;
        for (let i = 0; i < body.outputDevices.length; i++) {
            if (body.outputDevices[i] === cur)
                return i;
        }
        // Fall back to name match (default node object may differ).
        for (let j = 0; j < body.outputDevices.length; j++) {
            if (body.outputDevices[j] && cur && body.outputDevices[j].name === cur.name)
                return j;
        }
        return -1;
    }
    function selectOutput(i) {
        const n = body.outputDevices[i];
        if (n)
            Pipewire.preferredDefaultAudioSink = n;
    }
    // Collapsible audio card state. Collapsed by default; the card's
    // HoverHandler expands on hover (mirrors connectivityOpen below).
    property bool audioOpen: false

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
    // Collapsible connectivity card state. Lives on the body (not the
    // content Row) so every reference below resolves as body.* — the old
    // contentCol-owned copies were shadowed and read back undefined.
    // Collapsed by default; the card's HoverHandler expands on hover.
    property bool connectivityOpen: false
    readonly property string btStateText: !body.btAvailable ? "N/A" : (body.btPowered ? "On" : "Off")
    readonly property string connSummary: body.netStatus + " • BT " + body.btStateText
    // True while the user is dragging either slider. ControlIsland binds the
    // hover-pin's holdOpen to this: HoverHandler.hovered drops while a button
    // is pressed, so a drag would otherwise read as "left" and arm the leave
    // timer mid-adjustment.
    readonly property bool adjusting: brightSlider.pressed || masterSlider.pressed || body.appPressed > 0
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

    // ---- content: two columns ----
    // Left: audio + connectivity revealing cards (collapsed until hovered).
    // Right: action grid + brightness + power profile.
    Row {
        id: contentRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 16

        // ===== Left column: revealing cards =====
        Column {
            id: leftCol
            width: (parent.width - parent.spacing) / 2
            spacing: 16

            // ===== Audio (output device + per-app sliders) =====
            // Same layout as the Connectivity card: shared Card shell, header
            // with summary + chevron, click toggles the body. The old
            // per-app playback sliders below the output picker.
            // Hover wrapper: Card forwards direct children to its content
            // Column, so the HoverHandler lives on this plain Item (it
            // monitors its parent = the whole card bounds).
            Item {
                width: parent.width
                height: audioCard.height
                // Hover-to-expand: collapsed by default, opens while hovered.
                // Leave collapses unless a slider is dragged or a device
                // popup is open (the popup is a separate window, so hover
                // is lost while picking).
                HoverHandler {
                    id: audioHover
                    onHoveredChanged: {
                        if (hovered) {
                            body.audioOpen = true;
                        } else if (!outCombo.popup.visible && body.appPressed === 0 && !masterSlider.pressed) {
                            body.audioOpen = false;
                        }
                    }
                }
                Card {
                    id: audioCard
                    width: parent.width
                    contentMargins: 12
                    contentSpacing: 8
                    height: contentMargins * 2 + audioHeadRow.height + (audioBody.visible ? contentSpacing + audioBody.height : 0)
                    Behavior on height {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }

                    // Header: icon + title + master slider (visible collapsed),
                    // chevron pinned right; click toggles. Row children are
                    // vertically centered so the collapsed card reads as one row.
                    Item {
                        width: parent.width
                        height: audioHeadRow.height
                        Row {
                            id: audioHeadRow
                            width: parent.width - 22
                            spacing: 8
                            Text {
                                id: audioIcon
                                anchors.verticalCenter: parent.verticalCenter
                                text: VolumeWatcher.volumeIcon
                                color: Theme.fg
                                font.family: "JetBrainsMono NFP"
                                font.pixelSize: 18
                            }
                            Text {
                                id: audioTitle
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Audio"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                            }
                            AppSlider {
                                id: masterSlider
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(0, parent.width - audioIcon.width - audioTitle.width - audioPct.width - parent.spacing * 3)
                                from: 0
                                to: 1
                                stepSize: 0.01
                                Component.onCompleted: masterSlider.value = body.controlSink?.audio?.volume ?? 0
                                onMoved: if (body.controlSink?.audio)
                                    body.controlSink.audio.volume = masterSlider.value
                            }
                            Binding {
                                target: masterSlider
                                property: "value"
                                value: body.controlSink?.audio?.volume ?? 0
                                when: !masterSlider.pressed
                            }
                            Text {
                                id: audioPct
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round((body.controlSink?.audio?.volume ?? 0) * 100) + "%"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: body.audioOpen ? "\uf106" : "\uf107"
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
                            onClicked: body.audioOpen = !body.audioOpen
                        }
                    }

                    // Body: output subsection, divider, input subsection.
                    Column {
                        id: audioBody
                        width: parent.width
                        spacing: 10
                        visible: body.audioOpen || outCombo.popup.visible || body.appPressed > 0

                        // ----- Output -----
                        Column {
                            width: parent.width
                            spacing: 6
                            Text {
                                text: "Output"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                            }
                            AppComboBox {
                                id: outCombo
                                width: parent.width
                                model: body.outputDeviceNames.length > 0 ? body.outputDeviceNames : ["No output devices"]
                                enabled: body.outputDeviceNames.length > 0
                                currentIndex: Math.max(0, body.outputIndex)
                                onActivated: i => {
                                    body.selectOutput(i);
                                    if (!audioHover.hovered)
                                        body.audioOpen = false;
                                }
                            }
                        }

                        // ----- Applications -----
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.border
                        }
                        Column {
                            width: parent.width
                            spacing: 6
                            Text {
                                text: "Applications"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                            }
                            Column {
                                width: parent.width
                                spacing: 8
                                Repeater {
                                    model: body.appStreams
                                    delegate: Column {
                                        required property var modelData
                                        width: parent.width
                                        spacing: 4
                                        Row {
                                            width: parent.width
                                            spacing: 8
                                            Text {
                                                text: body.streamLabel(modelData)
                                                color: Theme.fg
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize - 2
                                                elide: Text.ElideRight
                                                verticalAlignment: Text.AlignVCenter
                                                width: Math.max(0, parent.width - appPct.width - appMute.width - parent.spacing * 2)
                                            }
                                            Text {
                                                id: appPct
                                                text: Math.round((modelData.audio?.volume ?? 0) * 100) + "%"
                                                color: Theme.muted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize - 2
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            AppCheckBox {
                                                id: appMute
                                                text: "Mute"
                                                checked: modelData.audio?.muted ?? false
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize - 2
                                                onToggled: if (modelData.audio)
                                                    modelData.audio.muted = checked
                                            }
                                        }
                                        AppSlider {
                                            id: appSlider
                                            width: parent.width
                                            from: 0
                                            to: 1
                                            stepSize: 0.01
                                            Component.onCompleted: appSlider.value = modelData.audio?.volume ?? 0
                                            onMoved: if (modelData.audio)
                                                modelData.audio.volume = appSlider.value
                                            onPressedChanged: body.appPressed += pressed ? 1 : -1
                                        }
                                        Binding {
                                            target: appSlider
                                            property: "value"
                                            value: modelData.audio?.volume ?? 0
                                            when: !appSlider.pressed
                                        }
                                    }
                                }
                            }
                            Text {
                                visible: body.appStreams.length === 0
                                text: "No apps playing audio"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }
                    }
                }
            }

            // ===== Connectivity (Network + Bluetooth share one dropdown) =====
            // Shared Card shell + AppCheckBox/AppButton + Theme-only styling.
            // Card needs an explicit height (Rectangle); it tracks the header
            // plus the open body, mirroring the contentRow.height pattern above.
            // Hover wrapper: see the audio card above — the handler must
            // not be a direct Card child.
            Item {
                width: parent.width
                height: connCard.height
                // Hover-to-expand: collapsed by default, opens while hovered.
                HoverHandler {
                    id: connHover
                    onHoveredChanged: body.connectivityOpen = hovered
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
                                text: body.connSummary
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
                            text: body.connectivityOpen ? "\uf106" : "\uf107"
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
            }
        }

        // ===== Right column: actions + brightness + power =====
        Column {
            id: rightCol
            width: (parent.width - parent.spacing) / 2
            spacing: 16

            // ===== Action buttons (shared AppButton cells, 2x2) =====
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 10
                rowSpacing: 10
                // Theme toggle
                AppButton {
                    width: (parent.width - parent.columnSpacing) / 2
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
                    width: (parent.width - parent.columnSpacing) / 2
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
                // Game Mode: always applies the Hyprland preset; gamemoded and
                // powerprofilesctl are optional integrations.
                AppButton {
                    width: (parent.width - parent.columnSpacing) / 2
                    height: 46
                    cornerRadius: Theme.radius
                    idleBg: Theme.surface
                    icon: "\u{F11B}"
                    pixelSize: Theme.fontSize + 2
                    toggle: true
                    checked: Settings.gameModeEnabled
                    tooltipText: Settings.gameModeEnabled ? "Disable Game Mode" : "Enable Game Mode"
                    onClicked: Settings.applyGameMode(!Settings.gameModeEnabled)
                }
                // Keyboard layout — shows the current layout code, click cycles
                AppButton {
                    width: (parent.width - parent.columnSpacing) / 2
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
                    width: parent.width
                    height: implicitHeight
                    stretchCells: true
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
        }
    }
}
