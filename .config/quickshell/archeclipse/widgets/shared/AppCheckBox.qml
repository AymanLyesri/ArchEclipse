import QtQuick
import QtQuick.Controls
import qs.theme

// Shared single checkbox: a raised well that fills with accent when checked. No resting
// outline, so a row of checkboxes stays quiet next to the switches it sits with.
CheckBox {
    id: root

    indicator: Rectangle {
        implicitWidth: 18
        implicitHeight: 18
        x: root.leftPadding
        y: parent.height / 2 - height / 2
        radius: Theme.radius
        color: root.checked ? Theme.accent : (root.hovered ? Theme.surfaceOverlay : Theme.surfaceRaised)
        border.width: root.visualFocus ? 2 : 0
        border.color: Theme.focusRing

        Behavior on color {
            CAnim {}
        }

        Text {
            anchors.centerIn: parent
            text: Icons.checkMarked
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            color: Theme.pickOn(Theme.accent, Theme.accentFg, Theme.bg)
            visible: root.checked
            scale: root.checked ? 1 : 0.6
            opacity: root.checked ? 1 : 0

            Behavior on scale {
                Anim { type: Anim.FastSpatial }
            }
            Behavior on opacity {
                Anim { type: Anim.FastEffects }
            }
        }
    }

    contentItem: Text {
        text: root.text
        font: root.font
        color: Theme.fg
        verticalAlignment: Text.AlignVCenter
        leftPadding: root.indicator.width + root.spacing
    }
}
