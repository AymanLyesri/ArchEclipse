import QtQuick
import qs.services
import qs.widgets.bar.islands
import qs.widgets.controlPanel

// Control island: quick-settings body inline in the bar pill.
// Same unfold pattern as SearchIsland — the pill grows (width via
// the pill transition, height snapped on the window) while this body unfolds.
//
// Focus: OnDemand (no keyboard grab) so the user can type elsewhere while
// it is open. Clicking a slider focuses the surface, then Esc dismisses.
// Leave: the island closes itself after the reveal-out delay once the
// cursor exits.
// Pulse states (volume/brightness keys) render through this same island;
// hovering one pins it persistent so it doesn't close mid-drag.
Column {
    id: root
    width: controlBody.width
    spacing: 0

    // Island owner passes the bar's monitor; body falls back to focused.
    property string monitorName: ""

    // Expand driver: 0 -> 1 on creation unfolds the body.
    property real expand: 0
    Component.onCompleted: expand = 1

    // Hover pin (stable container — content never swaps under the cursor
    // while open). Pins whichever control-family state is showing — the
    // pulse that opened it, or "control" itself — persistently, so hover
    // never flips the resolved state and replays the swap motion;
    // leaving arms the reveal-out close timer, which also clears the pulses.
    IslandHoverPin {
        id: hoverPin
        stateName: (BarState.state === "volume" || BarState.state === "brightness") ? BarState.state : "control"
        extraStates: ["volume", "brightness"]
        // Slider drags press the mouse (dropping HoverHandler.hovered), so
        // hold the island open for the length of the drag. ComboBox popups
        // render outside hover bounds too, so hold while one is open.
        holdOpen: controlBody.adjusting || controlBody.popupOpen
    }

    // Volume/brightness changes reset the reveal-out close timer: without
    // this a leave armed before the adjustment would shut the panel
    // mid-adjustment. Skipped while hovered (hover already pins it —
    // arming a close while hovered would fire into an attended panel)
    // and when no close is pending (don't arm a no-op timer for a
    // closed island).
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

    // Esc dismiss once the surface has focus (click a slider first).
    IslandEscClose {
        states: ["control", "volume", "brightness"]
    }

    IslandExpandClip {
        expand: root.expand
        contentHeight: controlBody.height

        ControlPanelBody {
            id: controlBody
            anchors.top: parent.top
            monitorName: root.monitorName
        }
    }
}
