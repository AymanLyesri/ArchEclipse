import QtQuick
import qs.theme

// Shared badge pill: single overlay badge with content-sized width.
// Used by the AppImage and AppVideo badge overlays (top-right).
// Short texts keep the legacy 24px look; longer ones (e.g. wallhaven
// "2560x1440" dimensions) expand to fit instead of clipping.
Rectangle {
    id: root

    property string text: ""

    width: Math.max(24, badgeLabel.implicitWidth + 12)
    height: 18
    radius: Theme.radius
    color: Theme.accent
    visible: root.text !== ""

    Text {
        id: badgeLabel
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: 9
        font.family: Theme.fontFamily
        color: "white"
    }
}
