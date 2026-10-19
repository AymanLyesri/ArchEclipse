import QtQuick
import QtQuick.Controls
import qs.theme

// Shared iOS-style switch — replaces raw checkboxes in settings rows.
// Same contract as AppCheckBox (checked + onToggled), so call sites only
// swap the type.
Switch {
    id: root

    indicator: Rectangle {
        implicitWidth: 34
        implicitHeight: 20
        x: root.leftPadding
        y: root.height / 2 - height / 2
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.surface
        border.color: root.checked ? Theme.accent : Theme.border
        border.width: 1

        Rectangle {
            id: knob
            x: root.checked ? parent.width - width - 2 : 2
            width: 16
            height: parent.height - 4
            radius: width / 2
            color: Theme.pickOn(Theme.accent, Theme.accentFg, Theme.bg)
            Behavior on x {
                Anim { type: Anim.FastEffects }
            }
        }
    }

    opacity: root.enabled ? 1 : 0.5
}
