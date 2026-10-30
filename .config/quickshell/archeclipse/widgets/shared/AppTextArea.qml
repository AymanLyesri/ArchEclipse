// THE shared multi-line text input: themed background, accent focus ring, sane defaults
// (mirrors AppTextField). All Controls TextArea properties work and stay overridable.
import QtQuick
import QtQuick.Controls
import qs.theme

TextArea {
    id: root

    property int cornerRadius: Theme.radius
    property color fillColor: Theme.surface

    font.pixelSize: Theme.fontSize
    font.family: Theme.fontFamily
    color: Theme.fg
    placeholderTextColor: Theme.fgDim
    selectionColor: Theme.surfaceActive
    selectedTextColor: Theme.fg
    wrapMode: TextArea.Wrap
    leftPadding: 10
    rightPadding: 10
    topPadding: 10
    bottomPadding: 10

    background: Rectangle {
        color: root.fillColor
        radius: root.cornerRadius
        border.color: root.activeFocus ? Theme.accent : Theme.border
        border.width: 1
    }
}
