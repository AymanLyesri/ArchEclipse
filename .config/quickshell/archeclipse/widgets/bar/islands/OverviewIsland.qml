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

    implicitWidth: islandWidth + islandMargins * 2
    implicitHeight: content.height + islandMargins * 2
    width: implicitWidth
    height: implicitHeight

    OverviewBody {
        id: content
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: root.islandMargins
        width: root.islandWidth
        monitorName: root.monitorName
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
