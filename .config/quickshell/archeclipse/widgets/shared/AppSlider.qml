import QtQuick
import QtQuick.Controls
import qs.theme

// Shared themed slider (sibling of AppButton): extends Slider so from/to/stepSize/value and
// the onMoved contract pass through; only the look is themed. The rail is a recessed track and
// the fill is the accent — the handle is the only raised element, so the row reads as a groove.
Slider {
    id: root

    implicitHeight: 24

    // Optional reset point. Null/undefined (the default) changes nothing: no tick, no snapping.
    property var defaultValue: null
    // Snap zone in value units, so it behaves the same at any slider width.
    property real snapThreshold: Math.abs(root.to - root.from) * 0.03

    readonly property bool hasDefault: root.defaultValue !== null && root.defaultValue !== undefined && !isNaN(root.defaultValue) && root.defaultValue >= Math.min(root.from, root.to) && root.defaultValue <= Math.max(root.from, root.to)
    readonly property real defaultFraction: root.hasDefault && root.to !== root.from ? Math.max(0, Math.min(1, (root.defaultValue - root.from) / (root.to - root.from))) : 0
    readonly property bool atDefault: root.hasDefault && Math.abs(root.value - root.defaultValue) < 1e-9

    // Snap only while the user drags: programmatic/bound values are never pulled toward the
    // marker. A Connections object (not onValueChanged) so a consumer's own onValueChanged
    // handler cannot shadow it. Assigning here happens before Slider emits moved(), so onMoved
    // consumers always see the snapped value.
    Connections {
        target: root
        function onValueChanged() {
            if (!root.pressed || !root.hasDefault)
                return;
            if (Math.abs(root.value - root.defaultValue) <= root.snapThreshold)
                root.value = root.defaultValue;
        }
    }

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

        // Marker sits above the fill and never moves with the handle. Accent when the value is
        // exactly at the default, muted otherwise, so it stays legible at either end.
        Rectangle {
            visible: root.hasDefault
            width: 2
            height: 10
            radius: 1
            // Clamped inside the track so an edge default (0 or max) is still fully visible.
            x: Math.max(0, Math.min(parent.width - width, parent.width * root.defaultFraction - width / 2))
            y: (parent.height - height) / 2
            color: root.atDefault ? Theme.accent : Theme.fgDim
            opacity: root.enabled ? (root.atDefault ? 0.9 : 0.55) : Theme.opacity.disabled

            Behavior on color {
                CAnim {}
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
