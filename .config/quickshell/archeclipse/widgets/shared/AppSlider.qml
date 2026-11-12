import QtQuick
import QtQuick.Controls
import qs.theme

// Shared themed slider: extends Slider so from/to/stepSize/value and onMoved pass through.
// Recessed track + accent fill; the handle is the only raised element, so it reads as a groove.
Slider {
    id: root

    // Vertical mode (equalizer bands): track runs bottom-up, fill from the bottom.
    implicitWidth: root.orientation === Qt.Vertical ? 24 : 200
    implicitHeight: root.orientation === Qt.Vertical ? 200 : 24

    // Optional reset point. Null/undefined (the default) changes nothing: no tick, no snapping.
    property var defaultValue: null
    // Snap zone in value units, so it behaves the same at any slider width.
    property real snapThreshold: Math.abs(root.to - root.from) * 0.03

    readonly property bool hasDefault: root.defaultValue !== null && root.defaultValue !== undefined && !isNaN(root.defaultValue) && root.defaultValue >= Math.min(root.from, root.to) && root.defaultValue <= Math.max(root.from, root.to)
    readonly property real defaultFraction: root.hasDefault && root.to !== root.from ? Math.max(0, Math.min(1, (root.defaultValue - root.from) / (root.to - root.from))) : 0
    readonly property bool atDefault: root.hasDefault && Math.abs(root.value - root.defaultValue) < 1e-9

    // Snap only while dragging, never bound values. A Connections (not onValueChanged) so a
    // consumer handler cannot shadow it; assignment lands before moved(), so onMoved sees it.
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
        implicitWidth: root.orientation === Qt.Vertical ? 4 : 200
        implicitHeight: root.orientation === Qt.Vertical ? 200 : 4
        x: root.orientation === Qt.Vertical ? root.leftPadding + root.availableWidth / 2 - width / 2 : root.leftPadding
        y: root.orientation === Qt.Vertical ? root.topPadding : root.topPadding + root.availableHeight / 2 - height / 2
        width: root.orientation === Qt.Vertical ? 4 : root.availableWidth
        height: root.orientation === Qt.Vertical ? root.availableHeight : 4
        radius: 2
        color: Theme.track

        // visualPosition is 0 at the top for vertical sliders, so the fill grows bottom-up.
        Rectangle {
            width: root.orientation === Qt.Vertical ? parent.width : parent.width * root.visualPosition
            height: root.orientation === Qt.Vertical ? parent.height * (1 - root.visualPosition) : parent.height
            y: root.orientation === Qt.Vertical ? parent.height - height : 0
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
            width: root.orientation === Qt.Vertical ? 10 : 2
            height: root.orientation === Qt.Vertical ? 2 : 10
            radius: 1
            // Clamped inside the track so an edge default (0 or max) is still fully visible.
            x: root.orientation === Qt.Vertical ? (parent.width - width) / 2 : Math.max(0, Math.min(parent.width - width, parent.width * root.defaultFraction - width / 2))
            y: root.orientation === Qt.Vertical ? Math.max(0, Math.min(parent.height - height, parent.height * (1 - root.defaultFraction) - height / 2)) : (parent.height - height) / 2
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
        x: root.orientation === Qt.Vertical ? root.leftPadding + root.availableWidth / 2 - width / 2 : root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.orientation === Qt.Vertical ? root.topPadding + root.visualPosition * (root.availableHeight - height) : root.topPadding + root.availableHeight / 2 - height / 2
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
