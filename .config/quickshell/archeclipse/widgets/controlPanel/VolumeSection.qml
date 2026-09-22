import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.theme
import qs.services
import qs.widgets.shared

// pavucontrol-style volume section: Playback / Recording / Output / Input.
// Type filters use PwNodeType.toString() strict-compare on purpose: the
// flags overlap (AudioOutStream 21 & AudioInStream 13 == 5), so the old
// `type & PwNodeType.AudioInStream` fallback excluded EVERY stream and the
// application list was always empty despite pavucontrol showing apps.
// `properties` needs a bound node, but `type`/`isStream`/`audio` do not,
// so filtering never depends on bind state. A global PwObjectTracker binds
// all nodes so delegates can read properties/audio/mute freely.
Item {
    id: root
    height: volCard.height

    property bool sectionOpen: false
    property int tabIndex: 0
    property int pressedCount: 0
    property int popupCount: 0
    readonly property bool adjusting: root.pressedCount > 0

    // ---- pipewire model ----
    PwObjectTracker {
        objects: (Pipewire.nodes && Pipewire.nodes.values) ? Pipewire.nodes.values : []
    }
    readonly property PwNode defaultSink: Pipewire.defaultAudioSink
    readonly property PwNode defaultSource: Pipewire.defaultAudioSource
    readonly property var allNodes: (Pipewire.nodes && Pipewire.nodes.values) ? Pipewire.nodes.values : []
    readonly property var outputDevices: root.allNodes.filter(function (n) {
        if (!n || !n.audio || n.isStream)
            return false;
        const t = PwNodeType.toString(n.type);
        return t === "AudioSink" || t === "AudioDuplex";
    })
    readonly property var inputDevices: root.allNodes.filter(function (n) {
        if (!n || !n.audio || n.isStream)
            return false;
        const t = PwNodeType.toString(n.type);
        return t === "AudioSource" || t === "AudioDuplex";
    })
    // Playback = app outputting audio (pavucontrol "Playback" tab).
    readonly property var playbackStreams: root.allNodes.filter(function (n) {
        return n && n.isStream && n.audio && PwNodeType.toString(n.type) === "AudioOutStream";
    })
    // Recording = app capturing audio (pavucontrol "Recording" tab).
    readonly property var recordingStreams: root.allNodes.filter(function (n) {
        return n && n.isStream && n.audio && PwNodeType.toString(n.type) === "AudioInStream";
    })

    function deviceLabel(n) {
        return (n && (n.nickname || n.description || n.name)) || "Unknown";
    }
    function streamTitle(n) {
        if (!n)
            return "Unknown app";
        if (n.properties) {
            const app = n.properties["application.name"];
            if (app)
                return app;
            const media = n.properties["media.name"];
            if (media)
                return media;
        }
        return (n.nickname || n.description || n.name) || "Unknown app";
    }
    function streamSub(n) {
        if (!n || !n.properties)
            return "";
        const app = n.properties["application.name"] || "";
        const media = n.properties["media.name"] || "";
        if (media && media !== app)
            return media;
        return "";
    }
    readonly property var outputNames: root.outputDevices.map(function (n) {
        return root.deviceLabel(n);
    })
    readonly property var inputNames: root.inputDevices.map(function (n) {
        return root.deviceLabel(n);
    })
    function deviceIndex(devices, cur) {
        if (!cur)
            return -1;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i] === cur || (devices[i] && devices[i].name === cur.name))
                return i;
        }
        return -1;
    }
    readonly property int outputIndex: root.deviceIndex(root.outputDevices, root.defaultSink)
    readonly property int inputIndex: root.deviceIndex(root.inputDevices, root.defaultSource)

    // Per-stream routing (pavucontrol device dropdown): pactl sink-input
    // ids are pipewire object.serials, and sink names are PwNode names.
    function streamSerial(s) {
        if (!s || !s.properties)
            return "";
        return s.properties["object.serial"] || "";
    }
    function shellQuote(s) {
        return "'" + String(s ?? "").replace(/'/g, "'\\''") + "'";
    }
    function movePlayback(s, i) {
        const dev = root.outputDevices[i];
        const serial = root.streamSerial(s);
        if (!dev || !serial)
            return;
        Quickshell.execDetached(["bash", "-c", "pactl move-sink-input " + serial + " " + root.shellQuote(dev.name)]);
    }
    function moveRecording(s, i) {
        const dev = root.inputDevices[i];
        const serial = root.streamSerial(s);
        if (!dev || !serial)
            return;
        Quickshell.execDetached(["bash", "-c", "pactl move-source-output " + serial + " " + root.shellQuote(dev.name)]);
    }
    function terminateStream(s) {
        if (s)
            Quickshell.execDetached(["pw-cli", "destroy", String(s.id)]);
    }

    function bumpPressed(pressed) {
        root.pressedCount = Math.max(0, root.pressedCount + (pressed ? 1 : -1));
    }
    function bumpPopup(visible) {
        root.popupCount = Math.max(0, root.popupCount + (visible ? 1 : -1));
    }

    // Hover wrapper: Card forwards direct children to its content Column,
    // so the HoverHandler lives on this plain Item (it monitors its
    // parent = the whole card bounds).
    HoverHandler {
        id: volHover
        onHoveredChanged: {
            if (hovered) {
                root.sectionOpen = true;
            } else if (root.pressedCount === 0 && root.popupCount === 0) {
                root.sectionOpen = false;
            }
        }
    }
    Card {
        id: volCard
        width: parent.width
        contentMargins: 12
        contentSpacing: 8
        height: contentMargins * 2 + headRow.height + (volBody.visible ? contentSpacing + volBody.height : 0)
        Behavior on height {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        // Header: icon + title + master slider, chevron pinned right.
        Item {
            width: parent.width
            height: headRow.height
            Row {
                id: headRow
                width: parent.width - 22
                spacing: 8
                Text {
                    id: volIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: VolumeWatcher.volumeIcon
                    color: Theme.fg
                    font.family: "JetBrainsMono NFP"
                    font.pixelSize: 18
                }
                Text {
                    id: volTitle
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Volume"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
                AppSlider {
                    id: masterSlider
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - volIcon.width - volTitle.width - volPct.width - parent.spacing * 3)
                    from: 0
                    to: 1.5
                    stepSize: 0.01
                    Component.onCompleted: masterSlider.value = root.defaultSink?.audio?.volume ?? 0
                    onMoved: if (root.defaultSink?.audio)
                        root.defaultSink.audio.volume = masterSlider.value
                    onPressedChanged: root.bumpPressed(pressed)
                }
                Binding {
                    target: masterSlider
                    property: "value"
                    value: root.defaultSink?.audio?.volume ?? 0
                    when: !masterSlider.pressed
                }
                Text {
                    id: volPct
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round((root.defaultSink?.audio?.volume ?? 0) * 100) + "%"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
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

        // Body: pavucontrol-style tabs.
        Column {
            id: volBody
            width: parent.width
            spacing: 10
            visible: root.sectionOpen || root.pressedCount > 0 || root.popupCount > 0

            AppSegmentedControl {
                id: tabBar
                width: parent.width
                stretchCells: true
                pixelSize: Theme.fontSize - 1
                model: [
                    {
                        value: 0,
                        label: "Playback" + (root.playbackStreams.length > 0 ? " (" + root.playbackStreams.length + ")" : ""),
                        tooltip: "Per-application output volumes"
                    },
                    {
                        value: 1,
                        label: "Recording" + (root.recordingStreams.length > 0 ? " (" + root.recordingStreams.length + ")" : ""),
                        tooltip: "Per-application capture volumes"
                    },
                    {
                        value: 2,
                        label: "Output",
                        tooltip: "Output devices"
                    },
                    {
                        value: 3,
                        label: "Input",
                        tooltip: "Input devices"
                    }
                ]
                currentIndex: root.tabIndex
                onActivated: i => root.tabIndex = i
            }

            // ----- Playback -----
            Column {
                width: parent.width
                spacing: 8
                visible: root.tabIndex === 0
                Repeater {
                    model: root.playbackStreams
                    delegate: Column {
                        required property var modelData
                        width: parent.width
                        spacing: 4
                        PwObjectTracker {
                            objects: [modelData]
                        }
                        PwNodeLinkTracker {
                            id: playLinks
                            node: modelData
                        }
                        readonly property var linkTarget: {
                            try {
                                const g = playLinks.linkGroups;
                                const arr = (g && g.values) ? g.values : g;
                                if (arr && arr.length > 0)
                                    return arr[0].target;
                            } catch (e) {}
                            return null;
                        }
                        readonly property string targetName: linkTarget ? (linkTarget.nickname || linkTarget.description || linkTarget.name || "") : ""
                        readonly property int targetIndex: {
                            if (!linkTarget)
                                return -1;
                            for (let i = 0; i < root.outputDevices.length; i++) {
                                if (root.outputDevices[i] === linkTarget || root.outputDevices[i].name === linkTarget.name)
                                    return i;
                            }
                            return -1;
                        }
                        readonly property string sub: {
                            const parts = [];
                            const s = root.streamSub(modelData);
                            if (s)
                                parts.push(s);
                            if (targetName)
                                parts.push("on " + targetName);
                            return parts.join(" • ");
                        }
                        Row {
                            width: parent.width
                            spacing: 6
                            Text {
                                id: playName
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.streamTitle(modelData)
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                                elide: Text.ElideRight
                                width: Math.max(0, parent.width - playPct.width - playMute.width - playKill.width - parent.spacing * 3)
                            }
                            Text {
                                id: playPct
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round((modelData.audio?.volume ?? 0) * 100) + "%"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }
                            AppButton {
                                id: playMute
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 26
                                cornerRadius: 6
                                idleBg: Theme.surface
                                icon: modelData.audio?.muted ? "\uf026" : "\uf028"
                                pixelSize: 12
                                toggle: true
                                checked: modelData.audio?.muted ?? false
                                tooltipText: modelData.audio?.muted ? "Unmute" : "Mute"
                                onClicked: if (modelData.audio)
                                    modelData.audio.muted = !modelData.audio.muted
                            }
                            AppButton {
                                id: playKill
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 26
                                cornerRadius: 6
                                idleBg: Theme.surface
                                icon: "\uf00d"
                                pixelSize: 11
                                tooltipText: "Terminate stream"
                                onClicked: root.terminateStream(modelData)
                            }
                        }
                        Text {
                            visible: sub !== ""
                            width: parent.width
                            text: sub
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 3
                            elide: Text.ElideRight
                        }
                        AppSlider {
                            id: playSlider
                            width: parent.width
                            from: 0
                            to: 1.5
                            stepSize: 0.01
                            Component.onCompleted: playSlider.value = modelData.audio?.volume ?? 0
                            onMoved: if (modelData.audio)
                                modelData.audio.volume = playSlider.value
                            onPressedChanged: root.bumpPressed(pressed)
                        }
                        Binding {
                            target: playSlider
                            property: "value"
                            value: modelData.audio?.volume ?? 0
                            when: !playSlider.pressed
                        }
                        AppComboBox {
                            id: playDevCombo
                            width: parent.width
                            model: root.outputNames.length > 0 ? root.outputNames : ["No output devices"]
                            enabled: root.outputNames.length > 0
                            currentIndex: Math.max(0, targetIndex >= 0 ? targetIndex : root.outputIndex)
                            onActivated: i => {
                                root.movePlayback(modelData, i);
                                if (!volHover.hovered)
                                    root.sectionOpen = false;
                            }
                        }
                        Connections {
                            target: playDevCombo.popup
                            function onVisibleChanged() {
                                root.bumpPopup(playDevCombo.popup.visible);
                            }
                        }
                    }
                }
                Text {
                    visible: root.playbackStreams.length === 0
                    text: "No applications playing audio"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
            }

            // ----- Recording -----
            Column {
                width: parent.width
                spacing: 8
                visible: root.tabIndex === 1
                Repeater {
                    model: root.recordingStreams
                    delegate: Column {
                        required property var modelData
                        width: parent.width
                        spacing: 4
                        PwObjectTracker {
                            objects: [modelData]
                        }
                        PwNodeLinkTracker {
                            id: recLinks
                            node: modelData
                        }
                        readonly property var linkSource: {
                            try {
                                const g = recLinks.linkGroups;
                                const arr = (g && g.values) ? g.values : g;
                                if (arr && arr.length > 0)
                                    return arr[0].source;
                            } catch (e) {}
                            return null;
                        }
                        readonly property string sourceName: linkSource ? (linkSource.nickname || linkSource.description || linkSource.name || "") : ""
                        readonly property int sourceIndex: {
                            if (!linkSource)
                                return -1;
                            for (let i = 0; i < root.inputDevices.length; i++) {
                                if (root.inputDevices[i] === linkSource || root.inputDevices[i].name === linkSource.name)
                                    return i;
                            }
                            return -1;
                        }
                        Row {
                            width: parent.width
                            spacing: 6
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.streamTitle(modelData)
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                                elide: Text.ElideRight
                                width: Math.max(0, parent.width - recPct.width - recMute.width - recKill.width - parent.spacing * 3)
                            }
                            Text {
                                id: recPct
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round((modelData.audio?.volume ?? 0) * 100) + "%"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }
                            AppButton {
                                id: recMute
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 26
                                cornerRadius: 6
                                idleBg: Theme.surface
                                icon: modelData.audio?.muted ? "\uf131" : "\uf130"
                                pixelSize: 12
                                toggle: true
                                checked: modelData.audio?.muted ?? false
                                tooltipText: modelData.audio?.muted ? "Unmute" : "Mute"
                                onClicked: if (modelData.audio)
                                    modelData.audio.muted = !modelData.audio.muted
                            }
                            AppButton {
                                id: recKill
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 26
                                cornerRadius: 6
                                idleBg: Theme.surface
                                icon: "\uf00d"
                                pixelSize: 11
                                tooltipText: "Terminate stream"
                                onClicked: root.terminateStream(modelData)
                            }
                        }
                        Text {
                            visible: sourceName !== ""
                            width: parent.width
                            text: "from " + sourceName
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 3
                            elide: Text.ElideRight
                        }
                        AppSlider {
                            id: recSlider
                            width: parent.width
                            from: 0
                            to: 1.5
                            stepSize: 0.01
                            Component.onCompleted: recSlider.value = modelData.audio?.volume ?? 0
                            onMoved: if (modelData.audio)
                                modelData.audio.volume = recSlider.value
                            onPressedChanged: root.bumpPressed(pressed)
                        }
                        Binding {
                            target: recSlider
                            property: "value"
                            value: modelData.audio?.volume ?? 0
                            when: !recSlider.pressed
                        }
                        AppComboBox {
                            id: recDevCombo
                            width: parent.width
                            model: root.inputNames.length > 0 ? root.inputNames : ["No input devices"]
                            enabled: root.inputNames.length > 0
                            currentIndex: Math.max(0, sourceIndex >= 0 ? sourceIndex : root.inputIndex)
                            onActivated: i => {
                                root.moveRecording(modelData, i);
                                if (!volHover.hovered)
                                    root.sectionOpen = false;
                            }
                        }
                        Connections {
                            target: recDevCombo.popup
                            function onVisibleChanged() {
                                root.bumpPopup(recDevCombo.popup.visible);
                            }
                        }
                    }
                }
                Text {
                    visible: root.recordingStreams.length === 0
                    text: "No applications recording audio"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
            }

            // ----- Output devices -----
            Column {
                width: parent.width
                spacing: 8
                visible: root.tabIndex === 2
                Repeater {
                    model: root.outputDevices
                    delegate: Column {
                        required property var modelData
                        width: parent.width
                        spacing: 4
                        PwObjectTracker {
                            objects: [modelData]
                        }
                        readonly property bool isDefault: root.defaultSink != null && (modelData === root.defaultSink || modelData.name === root.defaultSink.name)
                        Row {
                            width: parent.width
                            spacing: 6
                            AppButton {
                                id: outStar
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 26
                                cornerRadius: 6
                                idleBg: Theme.surface
                                icon: "\uf005"
                                pixelSize: 11
                                toggle: true
                                checked: isDefault
                                tooltipText: isDefault ? "Default output" : "Set as default output"
                                onClicked: Pipewire.preferredDefaultAudioSink = modelData
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.deviceLabel(modelData)
                                color: isDefault ? Theme.accent : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                                elide: Text.ElideRight
                                width: Math.max(0, parent.width - outStar.width - outPct.width - outMute.width - parent.spacing * 3)
                            }
                            Text {
                                id: outPct
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round((modelData.audio?.volume ?? 0) * 100) + "%"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }
                            AppButton {
                                id: outMute
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 26
                                cornerRadius: 6
                                idleBg: Theme.surface
                                icon: modelData.audio?.muted ? "\uf026" : "\uf028"
                                pixelSize: 12
                                toggle: true
                                checked: modelData.audio?.muted ?? false
                                tooltipText: modelData.audio?.muted ? "Unmute" : "Mute"
                                onClicked: if (modelData.audio)
                                    modelData.audio.muted = !modelData.audio.muted
                            }
                        }
                        AppSlider {
                            id: outSlider
                            width: parent.width
                            from: 0
                            to: 1.5
                            stepSize: 0.01
                            Component.onCompleted: outSlider.value = modelData.audio?.volume ?? 0
                            onMoved: if (modelData.audio)
                                modelData.audio.volume = outSlider.value
                            onPressedChanged: root.bumpPressed(pressed)
                        }
                        Binding {
                            target: outSlider
                            property: "value"
                            value: modelData.audio?.volume ?? 0
                            when: !outSlider.pressed
                        }
                    }
                }
                Text {
                    visible: root.outputDevices.length === 0
                    text: "No output devices"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
            }

            // ----- Input devices -----
            Column {
                width: parent.width
                spacing: 8
                visible: root.tabIndex === 3
                Repeater {
                    model: root.inputDevices
                    delegate: Column {
                        required property var modelData
                        width: parent.width
                        spacing: 4
                        PwObjectTracker {
                            objects: [modelData]
                        }
                        readonly property bool isDefault: root.defaultSource != null && (modelData === root.defaultSource || modelData.name === root.defaultSource.name)
                        Row {
                            width: parent.width
                            spacing: 6
                            AppButton {
                                id: inStar
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 26
                                cornerRadius: 6
                                idleBg: Theme.surface
                                icon: "\uf005"
                                pixelSize: 11
                                toggle: true
                                checked: isDefault
                                tooltipText: isDefault ? "Default input" : "Set as default input"
                                onClicked: Pipewire.preferredDefaultAudioSource = modelData
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.deviceLabel(modelData)
                                color: isDefault ? Theme.accent : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                                elide: Text.ElideRight
                                width: Math.max(0, parent.width - inStar.width - inPct.width - inMute.width - parent.spacing * 3)
                            }
                            Text {
                                id: inPct
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round((modelData.audio?.volume ?? 0) * 100) + "%"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }
                            AppButton {
                                id: inMute
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 26
                                cornerRadius: 6
                                idleBg: Theme.surface
                                icon: modelData.audio?.muted ? "\uf131" : "\uf130"
                                pixelSize: 12
                                toggle: true
                                checked: modelData.audio?.muted ?? false
                                tooltipText: modelData.audio?.muted ? "Unmute" : "Mute"
                                onClicked: if (modelData.audio)
                                    modelData.audio.muted = !modelData.audio.muted
                            }
                        }
                        AppSlider {
                            id: inSlider
                            width: parent.width
                            from: 0
                            to: 1.5
                            stepSize: 0.01
                            Component.onCompleted: inSlider.value = modelData.audio?.volume ?? 0
                            onMoved: if (modelData.audio)
                                modelData.audio.volume = inSlider.value
                            onPressedChanged: root.bumpPressed(pressed)
                        }
                        Binding {
                            target: inSlider
                            property: "value"
                            value: modelData.audio?.volume ?? 0
                            when: !inSlider.pressed
                        }
                    }
                }
                Text {
                    visible: root.inputDevices.length === 0
                    text: "No input devices"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
            }

            AppButton {
                width: parent.width
                height: 28
                cornerRadius: Theme.chipRadius
                idleBg: Theme.surface
                icon: "\ueb14"
                text: "pavucontrol"
                pixelSize: Theme.fontSize - 2
                tooltipText: "Open pavucontrol"
                onClicked: Quickshell.execDetached(["pavucontrol"])
            }
        }
    }
}
