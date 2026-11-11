import QtQuick
import QtQuick.Controls
import qs.theme

// Shared themed slider (sibling of AppButton): extends Slider so from/to/stepSize/value and
// the onMoved contract pass through; only the look is themed. The rail is a recessed track and
// the fill is the accent — the handle is the only raised element, so the row reads as a groove.
Slider {
    id: root

    implicitHeight: 24

    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 4
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: 4
        radius: 2
        color: Theme.track

        Rectangle {
            width: parent.width * root.visualPosition
            height: parent.height
            radius: 2
            color: Theme.accent
            opacity: root.enabled ? 1 : Theme.opacity.disabled

            Behavior on width {
                Anim { type: Anim.FastEffects }
            }
        }
    }

    handle: Rectangle {
        implicitWidth: root.pressed || root.hovered ? 15 : 13
        implicitHeight: implicitWidth
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        radius: width / 2
        // Filled with ink, not accent: an accent ball on an accent fill loses its edge on
        // exactly the checked half of the travel.
        color: root.pressed ? Theme.accent : Theme.fg
        border.width: root.visualFocus ? 2 : 0
        border.color: Theme.focusRing

        Behavior on implicitWidth {
            Anim { type: Anim.FastEffects }
        }
        Behavior on color {
            CAnim {}
        }
    }
}
