import QtQuick
import QtQuick.Controls
import qs.theme

// Shared iOS-style switch replacing raw checkboxes in settings rows: same contract as
// AppCheckBox (checked + onToggled), so call sites only swap the type.
Switch {
    id: root

    // Basic style insets the indicator by 6 px, which left the track short of the row's right
    // edge (sliders/inputs are flush there); zero padding makes the track the whole control.
    padding: 0
    spacing: 0
    implicitWidth: indicator.implicitWidth
    implicitHeight: indicator.implicitHeight

    indicator: Rectangle {
        id: track

        implicitWidth: 38
        implicitHeight: 22
        x: root.leftPadding
        y: root.height / 2 - height / 2
        radius: height / 2
        // A filled neutral track reads as a control at a glance; the outline is hover/focus
        // feedback only, so neither state depends on a hairline that vanishes on light cards.
        color: root.checked ? Theme.accent : Theme.track
        border.width: root.visualFocus ? 2 : 1
        border.color: root.visualFocus ? Theme.fg : (root.hovered && !root.checked ? Theme.fgDim : "transparent")

        Behavior on color {
            CAnim {}
        }
        Behavior on border.color {
            CAnim {}
        }

        Rectangle {
            id: knob

            // Off uses the full foreground: a bg-coloured knob disappears on the neutral
            // track in exactly one of the two variants, and pickOn cannot see the track.
            x: root.checked ? parent.width - width - 2 : 2
            y: (parent.height - height) / 2
            width: 18
            height: 18
            radius: width / 2
            color: root.checked ? Theme.pickOn(Theme.accent, Theme.accentFg, Theme.bg) : Theme.fg

            Behavior on x {
                Anim { type: Anim.FastEffects }
            }
            Behavior on color {
                CAnim {}
            }
        }
    }

    opacity: root.enabled ? 1 : Theme.opacity.disabled
}
