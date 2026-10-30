import QtQuick
import qs.services
import qs.theme

// Shared island hover-pin: hover stops the 1s leave timer and pins the state, leaving restarts it.
// NOTE: the root IS the HoverHandler — wrapping it in an Item deadens hover (AGENTS pitfall 6).
HoverHandler {
    id: root
    property string stateName: ""
    property string monitorName: ""
    property var extraStates: []
    // Leave delay before the state deactivates (defaults to
    // Settings.revealOutPressure; callers may override).
    property int leaveDelay: Settings.revealOutPressure
    // Arm at creation (default true: an island the cursor never reaches still closes). Set
    // false for islands that stay open until first hovered-out, toggled or Escaped.
    property bool armOnCreation: true
    property alias running: leaveTimer.running
    // External hold (a slider drag inside the island): while true it never closes. HoverHandler
    // is only hovered with no button pressed, so a drag would otherwise arm the leave timer.
    property bool holdOpen: false
    onHoldOpenChanged: {
        if (root.holdOpen) {
            leaveTimer.stop();
        } else if (!root.hovered) {
            leaveTimer.restart();
        }
    }
    onHoveredChanged: {
        if (root.hovered) {
            leaveTimer.stop();
            // First hover ends the open-grace: later leaves use the
            // configured delay from here on.
            leaveTimer.interval = root.leaveDelay;
            if (root.stateName !== "")
                BarState.activate(root.stateName, 0, root.monitorName);
        } else if (!root.holdOpen) {
            leaveTimer.restart();
        }
    }
    // Timer is a *property value*, not a child: HoverHandler has no default property, so a
    // nested object fails at load ("Cannot assign to non-existent default property").
    property Timer leaveTimer: Timer {
        id: leaveTimer
        interval: root.leaveDelay
        onTriggered: {
            if (BarState.tourHoldFor(root.monitorName))
                return;
            BarState.deactivate(root.stateName, root.monitorName);
            for (let i = 0; i < root.extraStates.length; i++)
                BarState.deactivate(root.extraStates[i], root.monitorName);
        }
    }
    function stop() { leaveTimer.stop(); }
    function restart() { leaveTimer.restart(); }
    // Arm with the open-grace. Creation arms through this, and long-lived pins (ControlCard)
    // call it on every open so a grace that expired while idle is fresh again.
    function arm() {
        leaveTimer.interval = root.openGrace;
        leaveTimer.restart();
    }
    // Arm at creation too (unless opted out): without a hover transition the island would stay
    // open forever. The first arm grants the open-grace regardless of leaveDelay.
    property int openGrace: 1000
    Component.onCompleted: {
        if (!root.armOnCreation)
            return;
        root.arm();
    }
}
