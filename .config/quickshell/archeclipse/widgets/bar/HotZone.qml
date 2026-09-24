import QtQuick
import Quickshell
import qs.theme
import qs.services

// Hot-zone strips at the bar's left/right ends — reveal the left/right
// islands immediately on hover (no dwell). Per-side lock + hotZone toggle;
// click also reveals (harmless extra, helps touch users).
// The islands live in side pills beside the bar pill (BarState
// leftOpen/rightOpen flags), so hover just reveals the pill in place.
Rectangle {
    id: root

    property string side: "left"
    property real size: 5
    property bool enabledHotZone: true
    property bool panelLock: false

    anchors.left: side === "left" ? parent.left : undefined
    anchors.right: side === "right" ? parent.right : undefined
    anchors.top: Settings.barOrientation ? parent.top : undefined
    anchors.bottom: Settings.barOrientation ? undefined : parent.bottom

    width: size
    height: parent.height
    color: preview ? Qt.rgba(1, 0.33, 0.33, 0.4) : "transparent"

    property bool preview: false

    // Dwell before hover opens the island: the strips sit at both bar
    // ends, so dragging the cursor out of an open island across the bar
    // used to brush the rival strip and instantly swap islands (left ->
    // right with no intent). Intentional hovers dwell; crossings don't.
    // Bound to Settings.revealInPressure (0 = instant). Click still opens
    // immediately (touch users).
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
            BarState.activate("left", 0);
        else
            BarState.activate("right", 0);
    }
}
