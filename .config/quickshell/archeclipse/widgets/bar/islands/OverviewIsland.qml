import QtQuick
import qs.theme
import qs.services
import qs.widgets.bar.islands
import qs.widgets.overview

// Overview island: the workspace grid inline in the bar pill. Closes on hover-leave (delay
// follows revealOutPressure), the toggle or Esc; card clicks focus and close, tiles keep it open.
Item {
    id: root
    property int islandWidth: 920

    // Island owner passes the bar's monitor; body falls back to focused.
    property string monitorName: ""

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

        OverviewBody {
            id: content
            anchors.top: parent.top
            width: parent.width
            monitorName: root.monitorName
        }
    }

    // Hover-leave close (delay via the IslandHoverPin default) + Esc. No creation arm: it stays
    // open until first hovered-out, toggled or Escaped.
    IslandHoverPin {
        stateName: "overview"
        monitorName: root.monitorName
        armOnCreation: false
    }
    IslandEscClose {
        states: ["overview"]
        monitorName: root.monitorName
    }
}
