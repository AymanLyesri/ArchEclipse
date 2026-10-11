import QtQuick
import qs.widgets.bar.islands
import qs.widgets.media

// Player island now shows the full MediaWidget (cover art, track info,
// controls, seek bar) instead of the old title-only ticker.
// Size derives from the MediaWidget's implicit size — no hardcoded
// width/height here.
Item {
    id: root

    // Expand driver: 0 -> 1 on creation unfolds the body; the Bar
    // exit driver plays 1 -> 0 on close before swapping content.
    property real expand: 0
    Component.onCompleted: expand = 1

    // Flush inside the pill: the bar's Theme.islandPad is the only inset.
    // (MediaWidget's own 12px stays — that is padding inside its surface.)
    implicitWidth: media.implicitWidth
    implicitHeight: clip.height
    width: implicitWidth
    height: implicitHeight

    IslandExpandClip {
        id: clip
        expand: root.expand
        contentHeight: media.implicitHeight
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        MediaWidget {
            id: media
            anchors.top: parent.top
            width: parent.width
        }
    }

    // Pin while hovered so the 2.5s pulse doesn't close it mid-interaction.
    // (The pin self-arms its leave timer at creation.)
    IslandHoverPin {
        stateName: "player"
    }
}
