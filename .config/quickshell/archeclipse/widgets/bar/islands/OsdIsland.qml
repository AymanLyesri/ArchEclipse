import QtQuick
import qs.services
import qs.theme
import qs.widgets.bar.islands
import qs.widgets.controlPanel
import qs.widgets.shared

// Volume/brightness OSD pill: the full VolumeSection or the collapsed brightness section,
// floating centered below the main pill — never hijacks it. Quick settings stay on ControlCard.
Item {
    id: root

    property string monitorName: ""

    // Expand driver: 0 -> 1 on creation unfolds the body.
    property real expand: 0
    Component.onCompleted: expand = 1

    // Which OSD to show (volume and brightness pulses are mutually exclusive). Membership,
    // not resolved state, so a main-pill switch never flips the content under a visible OSD.
    readonly property string mode: BarState.isOpenFor("brightness", root.monitorName) ? "brightness" : "volume"

    // Dynamic brightness icon (3-level thresholds, mirrors ControlPanelBody).
    readonly property string brightnessIcon: {
        const bri = Brightness.screenFor(root.monitorName);
        if (bri > 0.75)
            return Icons.brightnessHigh;
        if (bri > 0.5)
            return Icons.brightnessMedium;
        return Icons.brightnessLow;
    }

    // Fixed width breaks the width loop (root <- clip <- bodyCol <- root): VolumeSection has
    // no implicit size. 400 matches the Loader fallback so the open frame is exact.
    property int islandWidth: 400

    // True while the user is dragging a slider: IslandHoverPin.monitor
    // drops while pressed, so hold the pill open for the drag length.
    readonly property bool adjusting: (root.mode === "volume" && volSection.adjusting) || (root.mode === "brightness" && brightSlider.pressed)

    implicitWidth: islandWidth
    implicitHeight: clip.height
    width: implicitWidth
    height: implicitHeight

    IslandExpandClip {
        id: clip
        expand: root.expand
        // Explicit child heights: bodyCol is a plain Column (height 0,
        // children overflow by design), so bodyCol.height is always 0.
        contentHeight: root.mode === "brightness" ? brightCard.height : volSection.height
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        Column {
            id: bodyCol
            width: parent.width
            spacing: 0

            // Full volume section, collapsed (header only) until hovered —
            // VolumeSection owns its own sectionOpen hover expand.
            VolumeSection {
                id: volSection
                width: parent.width
                monitorName: root.monitorName
                visible: root.mode === "volume"
            }

            // Brightness section (mirrors ControlPanelBody): icon + slider. Explicit height —
            // Card is a plain Rectangle with no implicit size, so it would measure 0.
            Card {
                id: brightCard
                width: parent.width
                visible: root.mode === "brightness"
                contentMargins: Theme.pad
                contentSpacing: Theme.spacing
                height: contentMargins * 2 + brightRow.height
                Row {
                    id: brightRow
                    width: parent.width
                    spacing: Theme.spacing
                    Text {
                        id: brightIcon
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.brightnessIcon
                        color: Theme.fg
                        font.family: "JetBrainsMono NFP"
                        font.pixelSize: Theme.fs(1.5)
                    }
                    Text {
                        id: brightTitle
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Brightness"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }
                    AppSlider {
                        id: brightSlider
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, parent.width - brightIcon.width - brightTitle.width - brightPct.width - parent.spacing * 3)
                        from: 0
                        to: 1
                        stepSize: 0.01
                        value: Brightness.screenFor(root.monitorName)
                        onMoved: Brightness.setScreen(brightSlider.value, root.monitorName)
                    }
                    Binding {
                        target: brightSlider
                        property: "value"
                        value: Brightness.screenFor(root.monitorName)
                        when: !brightSlider.pressed
                    }
                    Text {
                        id: brightPct
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(Brightness.screenFor(root.monitorName) * 100) + "%"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }
        }
    }

    // Pin while hovered so the hold timer doesn't close it mid-interaction (covers both
    // pulses, so a rival switch keeps it); 2.5s linger keeps the OSD readable on key repeat.
    IslandHoverPin {
        id: hoverPin
        stateName: BarState.isOpenFor("brightness", root.monitorName) ? "brightness" : "volume"
        monitorName: root.monitorName
        extraStates: ["volume", "brightness"]
        leaveDelay: 2500
        openGrace: 2500
        holdOpen: root.adjusting
    }

    // Volume/brightness changes reset the close timer, else a leave armed before the key
    // repeat would shut the pill mid-adjustment. Skipped while hovered.
    function pokeHideTimer() {
        if (hoverPin.hovered || !hoverPin.running)
            return;
        hoverPin.restart();
    }
    Connections {
        target: BarState
        function onVolumeEventsChanged() {
            if (BarState.lastVolumeMonitor === root.monitorName)
                root.pokeHideTimer();
        }
        function onBrightnessEventsChanged() {
            if (BarState.lastBrightnessMonitor === root.monitorName)
                root.pokeHideTimer();
        }
    }

    IslandEscClose {
        states: ["volume", "brightness"]
        monitorName: root.monitorName
    }
}
