// THE shared single-line text input: a recessed field, no resting outline, and an accent
// ring that only appears with focus. All Controls TextField properties work and stay overridable.
import QtQuick
import QtQuick.Controls
import qs.theme

TextField {
    id: root

    property int cornerRadius: Theme.radius
    property color fillColor: Theme.surfaceRaised

    font.pixelSize: Theme.fontSize
    font.family: Theme.fontFamily
    color: Theme.fg
    placeholderTextColor: Theme.muted
    selectionColor: Theme.surfaceActive
    selectedTextColor: Theme.fg
    leftPadding: 10
    rightPadding: 10
    implicitHeight: Math.max(30, Theme.fontSize + 18)

    background: Rectangle {
        color: root.activeFocus ? Theme.surfaceOverlay : root.fillColor
        radius: root.cornerRadius
        border.width: root.activeFocus ? 1 : 0
        border.color: Theme.accent

        Behavior on color {
            CAnim {}
        }
    }
}
