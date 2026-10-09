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
// Volume/brightness key pulses render in the bottom OSD pill (OsdIsland),
// never here — explicit toggleControl is the only way this opens.
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
    // while open). Pins "control" persistently so hover never flips the
    // resolved state; leaving arms the reveal-out close timer.
    IslandHoverPin {
        id: hoverPin
        stateName: "control"
        // Slider drags press the mouse (dropping HoverHandler.hovered), so
        // hold the island open for the length of the drag. ComboBox popups
        // render outside hover bounds too, so hold while one is open.
        holdOpen: controlBody.adjusting || controlBody.popupOpen
    }

    // Esc dismiss once the surface has focus (click a slider first).
    IslandEscClose {
        states: ["control"]
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
