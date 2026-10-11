import QtQuick
import qs.theme
import qs.services
import qs.widgets.bar.islands
import qs.widgets.overview

// Overview island: workspace overview grid inline in the bar pill.
// Closes on hover-leave (leave delay follows Settings.revealOutPressure),
// via the toggle, or on Esc. Card clicks focus + close; tile clicks
// focus and keep it open.
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

    // Hover-leave close (delay follows reveal-out pressure via the
    // IslandHoverPin default) + Esc dismiss.
    // No creation arm: the island stays open until first hovered-out,
    // toggled, or Escaped.
    IslandHoverPin {
        stateName: "overview"
        armOnCreation: false
    }
    IslandEscClose {
        states: ["overview"]
    }
}
