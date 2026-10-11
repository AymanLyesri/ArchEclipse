import QtQuick
import qs.widgets.bar.islands
import qs.widgets.shared

// System-monitor island — in-bar expansion of the ResourceMonitor rings.
// Content is shared with the right panel (SystemResourcesContent); this
// wrapper only adds island sizing + hover pinning so the pulse can't
// close it mid-read.
Item {
    id: root
    property int islandWidth: 440

    // Expand driver: 0 -> 1 on creation unfolds the body; the Bar
    // exit driver plays 1 -> 0 on close before swapping content.
    property real expand: 0
    Component.onCompleted: expand = 1

    // Flush inside the pill: the bar's Theme.islandPad is the only inset.
    implicitWidth: islandWidth
    implicitHeight: clip.height
    width: implicitWidth
    height: implicitHeight

    IslandExpandClip {
        id: clip
        expand: root.expand
        contentHeight: content.height
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        SystemResourcesContent {
            id: content
            anchors.top: parent.top
            width: parent.width
        }
    }

    // Pin while hovered so the pulse doesn't close it mid-read.
    // (The pin self-arms its leave timer at creation.)
    IslandHoverPin {
        stateName: "system"
    }
}
