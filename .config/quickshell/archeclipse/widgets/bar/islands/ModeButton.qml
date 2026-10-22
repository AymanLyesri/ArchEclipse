import QtQuick
import qs.theme

// Icon cell for the side-pill stadiums (record / screenshot): 20px,
// background-less glyph only. Deliberately NO hover machinery and NO
// hover-toggled visuals inside these islands — any of it churned the
// bar hot-zone hover re-eval on entry and made the reveal flap
// (probe-proven); clicks land here, hover readings stay outside.
MouseArea {
    id: modeButton
    width: 20
    height: 20
    property string glyph: ""

    Text {
        anchors.centerIn: parent
        text: modeButton.glyph
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }
}
