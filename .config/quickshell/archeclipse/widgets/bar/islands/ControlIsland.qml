import QtQuick
import qs.widgets.bar.islands
import qs.widgets.controlPanel

// Control island: quick-settings body inline in the bar pill.
// Same spring-unfold pattern as SearchIsland — the pill grows (width via
// the pill spring, height snapped on the window) while this body unfolds.
//
// Focus: OnDemand (no keyboard grab) so the user can type elsewhere while
// it is open. Clicking a slider focuses the surface, then Esc dismisses.
// Leave: 1s after the cursor exits, the island closes itself.
// Pulse states (volume/brightness keys) render through this same island;
// hovering one pins it persistent so it doesn't close mid-drag.
Column {
    id: root
    width: controlBody.width
    spacing: 0

    // Island owner passes the bar's monitor; body falls back to focused.
    property string monitorName: ""

    // Spring driver: 0 -> 1 on creation unfolds the body.
    property real expand: 0
    Component.onCompleted: expand = 1

    // Hover pin (stable container — content never swaps under the cursor
    // while open). The pin activates "control" persistently on every
    // hover, which subsumes the old volume/brightness->control branch;
    // leaving arms the 1s close timer, which also clears the pulses.
    IslandHoverPin {
        stateName: "control"
        extraStates: ["volume", "brightness"]
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
