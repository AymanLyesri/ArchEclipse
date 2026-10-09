import QtQuick
import qs.services
import qs.theme
import qs.widgets.bar.islands
import qs.widgets.controlPanel
import qs.widgets.shared

// Volume/brightness OSD pill: shows the full VolumeSection or the
// brightness section collapsed until hovered, floating centered below
// the main pill like the media pill — never hijacks the main pill.
// Full quick-settings stay on explicit toggleControl (ControlIsland).
Item {
    id: root
    property int islandMargins: 4

    // Expand driver: 0 -> 1 on creation unfolds the body.
    property real expand: 0
    Component.onCompleted: expand = 1

    // Which OSD to show (volume pulses and brightness pulses are mutually
    // exclusive in BarState, so only one shows at a time). Membership, not
    // resolved state: a main-pill island switch must not flip the content
    // under a visible OSD.
    readonly property string mode: ("brightness" in BarState.activeStates) ? "brightness" : "volume"

    // Dynamic brightness icon (3-level thresholds, mirrors ControlPanelBody).
    readonly property string brightnessIcon: {
        const bri = Brightness.screen;
        if (bri > 0.75)
            return "\u{F00E0}";
        if (bri > 0.5)
            return "\u{F00DF}";
        return "\u{F00DE}";
    }

    // True while the user is dragging a slider: IslandHoverPin.monitor
    // drops while pressed, so hold the pill open for the drag length.
    readonly property bool adjusting: (root.mode === "volume" && volSection.adjusting) || (root.mode === "brightness" && brightSlider.pressed)

    implicitWidth: bodyCol.width + islandMargins * 2
    implicitHeight: clip.height + islandMargins * 2
    width: implicitWidth
    height: implicitHeight

    IslandExpandClip {
        id: clip
        expand: root.expand
        contentHeight: bodyCol.height
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.islandMargins
        anchors.leftMargin: root.islandMargins
        anchors.rightMargin: root.islandMargins

        Column {
            id: bodyCol
            width: parent.width
            spacing: 0

            // Full volume section, collapsed (header only) until hovered —
            // VolumeSection owns its own sectionOpen hover expand.
            VolumeSection {
                id: volSection
                width: parent.width
                visible: root.mode === "volume"
            }

            // Brightness section (mirrors ControlPanelBody): icon + slider.
            Card {
                width: parent.width
                visible: root.mode === "brightness"
                contentMargins: 12
                contentSpacing: 8
                Row {
                    width: parent.width
                    spacing: 8
                    Text {
                        id: brightIcon
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.brightnessIcon
                        color: Theme.fg
                        font.family: "JetBrainsMono NFP"
                        font.pixelSize: 18
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
                        value: Brightness.screen
                        onMoved: Brightness.setScreen(brightSlider.value)
                    }
                    Binding {
                        target: brightSlider
                        property: "value"
                        value: Brightness.screen
                        when: !brightSlider.pressed
                    }
                    Text {
                        id: brightPct
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(Brightness.screen * 100) + "%"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }
        }
    }

    // Pin while hovered so the pulse hold timer doesn't close it
    // mid-interaction. Covers both pulses so a rival switch keeps the pin.
    // 2.5s linger (like the player pill): the OSD stays readable a beat
    // after the last keypress, not just the 1s open-grace.
    IslandHoverPin {
        id: hoverPin
        stateName: ("brightness" in BarState.activeStates) ? "brightness" : "volume"
        extraStates: ["volume", "brightness"]
        leaveDelay: 2500
        openGrace: 2500
        holdOpen: root.adjusting
    }

    // Volume/brightness changes reset the close timer (same as the old
    // ControlIsland poke): without this a leave armed before the key
    // repeat would shut the pill mid-adjustment. Skipped while hovered.
    function pokeHideTimer() {
        if (hoverPin.hovered || !hoverPin.running)
            return;
        hoverPin.restart();
    }
    Connections {
        target: BarState
        function onVolumeEventsChanged() { root.pokeHideTimer(); }
        function onBrightnessEventsChanged() { root.pokeHideTimer(); }
    }

    IslandEscClose {
        states: ["volume", "brightness"]
    }
}
