import QtQuick
import qs.theme

// Shared badge pill: single overlay badge with content-sized width, so short texts keep the
// legacy 24px look and long ones (wallhaven dimensions) expand instead of clipping.
Rectangle {
    id: root

    property string text: ""

    width: Math.max(24, badgeLabel.implicitWidth + 12)
    height: 18
    radius: Theme.radius
    color: Theme.muted
    opacity: Theme.opacity.hoverDim
    visible: root.text !== ""

    Text {
        id: badgeLabel
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: Theme.fontSizeBadge
        font.family: Theme.fontFamily
        color: Theme.onMediaInk
    }
}
