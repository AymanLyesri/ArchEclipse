// THE shared multi-line text input: recessed fill, accent focus ring, calm metrics
// (mirrors AppTextField). All Controls TextArea properties work and stay overridable.
import QtQuick
import QtQuick.Controls
import qs.theme

TextArea {
    id: root

    property int cornerRadius: Theme.radius
    property color fillColor: Theme.surfaceRaised

    font.pixelSize: Theme.fontSize
    font.family: Theme.fontFamily
    color: Theme.fg
    placeholderTextColor: Theme.muted
    selectionColor: Theme.surfaceActive
    selectedTextColor: Theme.fg
    wrapMode: TextArea.Wrap
    leftPadding: 12
    rightPadding: 12
    topPadding: 10
    bottomPadding: 10

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
