// THE shared tooltip for the whole shell: bar pills, panel buttons, grid
// tiles, form fields — every hover hint looks identical. Extends the
// Controls ToolTip (no behavior reimplemented); only the look is themed to
// the ArchEclipse popup convention (AppComboBox popup / meta strips:
// opaque Theme.bg, 1px Theme.border, 6px radius) plus a short fade.
//
//   AppTooltip {
//       visible: hoverHandler.hovered
//       text: "Do the thing"
//   }
//
// delay defaults to 600ms (the shell-wide convention); override per
// instance only when a different timing is needed (e.g. delay: 400).
import QtQuick
import QtQuick.Controls
import qs.theme

ToolTip {
    id: root

    property int cornerRadius: 6

    delay: 600

    leftPadding: 10
    rightPadding: 10
    topPadding: 6
    bottomPadding: 6

    background: Rectangle {
        color: Theme.bg
        radius: root.cornerRadius
        border.color: Theme.border
        border.width: 1
    }
    contentItem: Text {
        text: root.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.fg
        // Tooltips may contain lightweight markup such as <b>...</b>.
        // Explicit RichText prevents the tags from being shown literally.
        textFormat: Text.RichText
    }

    enter: Transition {
        Anim {
            property: "opacity"
            from: 0
            to: 1
            type: Anim.FastEffects
        }
    }
    exit: Transition {
        Anim {
            property: "opacity"
            from: 1
            to: 0
            type: Anim.FastEffects
        }
    }
}
