import QtQuick
import qs.theme
import qs.widgets.shared

// Icon cell for the side-pill stadiums (record / screenshot), 20px,
// background-less glyph — now the shared AppButton cell.
//
// The islands' own files are load-bearing here: they document (probe-proven)
// that hover-reading churn inside the stadiums made the reveal flap. So the
// cell is maximally inert — the AppButton actions run, but its hover
// machinery is fully off:
//   quiet "true"          → hoverEnabled off + no hover scale bump;
//   hoverBg "transparent" → the stadium look stays background-less;
//   showTooltip "false"   → the tooltip popup's input grab reads as
//                           hover-out to the pill's pin and hides the
//                           stadium mid-hover, so hints stay off here.
// tooltipText REMAINS REQUIRED (set by the callers) — it just isn't shown.
AppButton {
    id: modeButton

    width: 20
    height: 20
    implicitWidth: width
    implicitHeight: height

    property string glyph: ""
    icon: glyph

    pixelSize: Theme.fontSizeSmall
    hoverBg: "transparent"
    showTooltip: false
    quiet: true
}
