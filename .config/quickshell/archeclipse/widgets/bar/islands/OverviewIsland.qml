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
    property int islandMargins: 8
    property int islandWidth: 920

    // Island owner passes the bar's monitor; body falls back to focused.
    property string monitorName: ""

    // Expand driver: 0 -> 1 on creation unfolds the body; the Bar
    // exit driver plays 1 -> 0 on close before swapping content.
    property real expand: 0
    Component.onCompleted: expand = 1

    implicitWidth: islandWidth + islandMargins * 2
    implicitHeight: clip.height + islandMargins * 2
    width: implicitWidth
    height: implicitHeight

    IslandExpandClip {
        id: clip
        expand: root.expand
        contentHeight: content.height
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.islandMargins
        anchors.leftMargin: root.islandMargins
        anchors.rightMargin: root.islandMargins

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
