import QtQuick
import qs.widgets.bar.islands
import qs.widgets.media

// Player island now shows the full MediaWidget (cover art, track info,
// controls, seek bar) instead of the old title-only ticker.
// Size derives from the MediaWidget's implicit size — no hardcoded
// width/height here.
Item {
    id: root
    property int islandMargins: 4

    // Expand driver: 0 -> 1 on creation unfolds the body; the Bar
    // exit driver plays 1 -> 0 on close before swapping content.
    property real expand: 0
    Component.onCompleted: expand = 1

    implicitWidth: media.implicitWidth + islandMargins * 2
    implicitHeight: clip.height + islandMargins * 2
    width: implicitWidth
    height: implicitHeight

    IslandExpandClip {
        id: clip
        expand: root.expand
        contentHeight: media.implicitHeight
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.islandMargins
        anchors.leftMargin: root.islandMargins
        anchors.rightMargin: root.islandMargins

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
