import QtQuick
import qs.theme

// Shared overlay badge: content-sized width so short texts keep the compact look and long ones
// (wallhaven dimensions) expand instead of clipping. A dark scrim keeps it legible over any
// thumbnail, which is why it is not derived from the palette.
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
