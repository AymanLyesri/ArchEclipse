import QtQuick
import qs.widgets.bar.islands
import qs.widgets.media

// Player island shows the full MediaWidget (art, track info, controls, seek bar) instead of
// a title ticker; size derives from its implicit size, so nothing is hardcoded here.
Item {
    id: root

    property string monitorName: ""

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

    // Pin while hovered, but never arm the grace at creation: the Loader recreates this island
    // per open, so a hover/click reveal would be killed ~1s later.
    IslandHoverPin {
        stateName: "player"
        monitorName: root.monitorName
        armOnCreation: false
    }
}
