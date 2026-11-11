import QtQuick
import qs.theme

// Shared depth plate for the whole shell: a stacked translucent fill plus a top-lit gradient
// instead of a 1px outline. `level` walks the theme's depth ladder (0 flat, 1 resting card,
// 2 raised row, 3 floating overlay) so every container in the shell reads as one material.
Rectangle {
    id: root

    property int level: 1
    // Optional wash layered instead of the ladder fill (selection, accent focus).
    property color tint: "transparent"
    // The light-from-above gradient is what sells the depth; turn off on flat bands.
    property bool lit: true
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

    // Top-lit gradient: light catches the upper edge, the base falls into shadow. Clipped by
    // the same radius, so it never draws an outline the corners would betray.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: root.lit && root.level > 0
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(1, 1, 1, 0.05)
            }
            GradientStop {
                position: 0.42
                color: Qt.rgba(1, 1, 1, 0)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(0, 0, 0, 0.05)
            }
        }
    }

    // Accent bloom under the top edge — one focused surface, never a decorative border.
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
