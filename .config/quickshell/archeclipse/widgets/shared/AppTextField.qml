// THE shared single-line text input for the whole shell: themed background
// with an accent focus ring and sane defaults — replaces the copy-pasted
// TextField + background Rectangle blocks (identical visuals everywhere).
// All Controls TextField properties (text, placeholderText, echoMode,
// validator, inputMethodHints, accepted/textChanged signals, ...) work as
// usual; only the styling defaults are set here and stay overridable.
import QtQuick
import QtQuick.Controls
import qs.theme

TextField {
    id: root

    property int cornerRadius: 6
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
