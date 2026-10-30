import QtQuick
import qs.theme
import qs.widgets.shared

// Icon cell for the side-pill stadiums: AppButton with hover machinery fully off (hover
// readouts and the tooltip grab flapped the reveal, probe-proven). tooltipText stays required.
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
