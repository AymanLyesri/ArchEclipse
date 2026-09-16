import QtQuick
import qs.services
import qs.theme

// Shared island hover-pin: hover stops the 1s leave timer and pins the
// BarState state persistent; leaving restarts the timer.
//
// NOTE: the root IS the HoverHandler (not an Item wrapper). A handler
// monitors hover for its *parent* item, so wrapping it in a 0x0 Item
// would deaden hover entirely: the pin would never fire and the island
// would close 1s after opening even while hovered. As a non-visual
// child this adds no layout row to Column roots.
HoverHandler {
    id: root
    property string stateName: ""
    property var extraStates: []
    // Leave delay before the state deactivates (defaults to
    // Settings.revealOutPressure; callers may override).
    property int leaveDelay: Settings.revealOutPressure
    // Arm the timer at creation (default true: an island the cursor never
    // reaches still closes). Set false for islands that must stay open
    // until first hovered-out, toggled, or Escaped.
    property bool armOnCreation: true
    property alias running: leaveTimer.running
    onHoveredChanged: {
        if (root.hovered) {
            leaveTimer.stop();
            // First hover ends the open-grace: later leaves use the
            // configured delay from here on.
            leaveTimer.interval = root.leaveDelay;
            if (root.stateName !== "")
                BarState.activate(root.stateName, 0);
        } else {
            leaveTimer.restart();
        }
    }
    // NOTE: Timer is a *property value*, not a child: HoverHandler
    // (like any QObject) has no default property, so a nested child
    // object fails at load ("Cannot assign to non-existent default
    // property"). Cf. SysInfo.qml `property Process compileProc: ...`.
    property Timer leaveTimer: Timer {
        id: leaveTimer
        interval: root.leaveDelay
        onTriggered: {
            BarState.deactivate(root.stateName);
            for (let i = 0; i < root.extraStates.length; i++)
                BarState.deactivate(root.extraStates[i]);
        }
    }
    function stop() { leaveTimer.stop(); }
    function restart() { leaveTimer.restart(); }
    // Arm at creation too (unless opted out): if the cursor never enters,
    // no hover transition fires and the island would stay open forever.
    // (A hover arrival within milliseconds stops it again.)
    // The first arm always grants a 1s open-grace (time to travel to a
    // keybind-opened island) regardless of leaveDelay — see above.
    Component.onCompleted: {
        if (!root.armOnCreation)
            return;
        leaveTimer.interval = 1000;
        leaveTimer.restart();
    }
}
