import QtQuick
import QtQuick.Controls
import qs.theme

// Shared themed slider (sibling of AppButton) — all bar sliders use this
// instead of raw Controls.Slider. Extends Slider so from/to/stepSize/value
// and the onMoved contract pass straight through; only the look is themed.
Slider {
    id: root

    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 4
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: 4
        radius: 2
        color: Theme.bg
        Rectangle {
            width: parent.width * root.visualPosition
            height: parent.height
            radius: 2
            color: Theme.accent
        }
    }

    handle: Rectangle {
        implicitWidth: 14
        implicitHeight: 14
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: 14
        height: 14
        radius: width / 2
        color: root.pressed ? Theme.accent : Theme.fg
    }
}
