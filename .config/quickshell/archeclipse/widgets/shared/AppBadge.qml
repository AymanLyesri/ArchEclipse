import QtQuick
import qs.theme

// Content-sized width so long texts (wallhaven dimensions) expand instead of clipping.
// A fixed dark scrim keeps it legible over any thumbnail, so it ignores the palette.
Rectangle {
    id: root

    property string text: ""
    property color ink: Theme.onMediaInk

    width: Math.max(24, badgeLabel.implicitWidth + 12)
    height: 18
    radius: Theme.radius
    // Depth over imagery: a translucent black plate beats a solid palette chip.
    color: Qt.rgba(0, 0, 0, 0.55)
    visible: root.text !== ""

    Text {
        id: badgeLabel
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: Theme.fontSizeBadge
        font.family: Theme.fontFamily
        color: root.ink
    }
}
