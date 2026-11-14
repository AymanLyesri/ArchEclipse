import QtQuick
import qs.theme

// Depth plate: flat fill, no gradient overlay.
// `level` walks the ladder (0 flat, 1 card, 2 row, 3 overlay) so containers read as one material.
Rectangle {
    id: root

    property int level: 1
    // Optional wash layered instead of the ladder fill (selection, accent focus).
    property color tint: "transparent"
    // Flat fill only, no gradient overlay.
    property bool lit: false // kept for compat, unused
    // Soft accent glow along the top edge, for the one surface that owns focus.
    property bool glow: false

    readonly property color levelColor: {
        if (root.level <= 0)
            return "transparent";
        if (root.level === 1)
            return Theme.surface;
        if (root.level === 2)
            return Theme.surfaceRaised;
        return Theme.surfaceOverlay;
    }

    radius: Theme.radius
    color: root.tint.a > 0 ? root.tint : root.levelColor
    border.width: 0

    Behavior on color {
        CAnim {}
    }

    // Gradient overlay removed: flat fill only.

    // Accent bloom under the top edge - one focused surface, never a decorative border.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 1
        height: 1
        radius: Theme.radius
        visible: root.glow
        color: Theme.rgba(Theme.accent, 0.45)
    }
}
