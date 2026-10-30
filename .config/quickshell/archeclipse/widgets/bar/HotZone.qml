import QtQuick
import Quickshell
import qs.theme
import qs.services

// Hot-zone strips at the bar's ends reveal the left/right islands on hover (per-side lock +
// hotZone toggle); click also reveals, for touch. State is monitor-scoped.
Rectangle {
    id: root

    property string side: "left"
    property string monitorName: ""
    property real size: 5
    property bool enabledHotZone: true
    property bool panelLock: false

    anchors.left: side === "left" ? parent.left : undefined
    anchors.right: side === "right" ? parent.right : undefined
    anchors.top: Settings.barOrientation ? parent.top : undefined
    anchors.bottom: Settings.barOrientation ? undefined : parent.bottom

    width: size
    height: parent.height
    color: preview ? Qt.alpha(Theme.danger, 0.4) : "transparent"

    property bool preview: false

    // Dwell before hover opens: both strips sit at the bar ends, so a cursor crossing used to
    // swap islands instantly. Clicks stay immediate; Settings.revealInPressure 0 = instant.
    property int dwellMs: Settings.revealInPressure
    Timer {
        id: dwellTimer
        interval: root.dwellMs
        repeat: false
        onTriggered: {
            if (root.panelLock || !root.enabledHotZone)
                return;
            root.showIsland();
        }
    }

    // Also track hover on the zone itself for preview mode (debug)
    MouseArea {
        anchors.fill: parent
        hoverEnabled: root.enabledHotZone
        onEntered: {
            // Per-side lock gate (was: either panel's lock blocked both sides)
            if (root.panelLock || !root.enabledHotZone)
                return;
            dwellTimer.restart();
        }
        onExited: {
            dwellTimer.stop();
        }
        onClicked: {
            if (root.panelLock || !root.enabledHotZone)
                return;
            dwellTimer.stop();
            root.showIsland();
        }
    }

    function showIsland() {
        if (root.side === "left")
            BarState.activate("left", 0, root.monitorName);
        else
            BarState.activate("right", 0, root.monitorName);
    }
}
