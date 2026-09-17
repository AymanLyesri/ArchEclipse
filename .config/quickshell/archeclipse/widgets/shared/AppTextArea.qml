// THE shared multi-line text input for the whole shell: themed background
// with an accent focus ring and sane defaults — mirrors AppTextField for
// single-line inputs and AppComboBox popups (same bg/border/radius language).
// All Controls TextArea properties (text, placeholderText, wrapMode,
// textChanged signals, ...) work as usual; only the styling defaults are
// set here and stay overridable.
import QtQuick
import QtQuick.Controls
import qs.theme

TextArea {
    id: root

    property int cornerRadius: Theme.radius
    property color fillColor: Theme.surface

    font.pixelSize: Theme.fontSize
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
