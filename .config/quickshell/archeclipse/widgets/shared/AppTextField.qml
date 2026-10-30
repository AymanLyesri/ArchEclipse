// THE shared single-line text input: themed background + accent focus ring, replacing the
// copy-pasted TextField blocks. All Controls TextField properties work and stay overridable.
import QtQuick
import QtQuick.Controls
import qs.theme

TextField {
    id: root

    property int cornerRadius: Theme.radius
    property color fillColor: Theme.bg

    font.pixelSize: Theme.fontSize
    font.family: Theme.fontFamily
    color: Theme.fg
    placeholderTextColor: Theme.fgDim
    selectionColor: Theme.surfaceActive
    selectedTextColor: Theme.fg
    leftPadding: 10
    rightPadding: 10

    background: Rectangle {
        color: root.fillColor
        radius: root.cornerRadius
        border.color: root.activeFocus ? Theme.accent : Theme.border
        border.width: 1
    }
}
