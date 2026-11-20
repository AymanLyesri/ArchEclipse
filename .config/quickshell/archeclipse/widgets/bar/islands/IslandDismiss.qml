import QtQuick
import qs.services

// Shared dismiss engine for bar islands: one instance per Bar window, sibling of
// the pill. Policies are per-state lists; the surface (the pill) stays the single
// hover source and the cut-out the catcher must never cover.
Item {
    id: root

    // The island surface: the pill. Band geometry reads it rigidly, so the
    // catcher tracks the pill's own open/close growth per frame.
    property Item surface: null
    // Hover input stays owned by the host (Bar.qml's pillHover on the pill
    // itself); the engine adds no second handler and no geometry mirror.
    property bool surfaceHovered: false
    property string monitorName: ""
    // States whose island closes when the pointer leaves the surface. Nothing
    // arms at open: an island the cursor never reaches stays (Esc, toggle and
    // click-outside all still work) — only a real leave closes it.
    property var hoverClose: []
    // States whose island closes on a click outside the surface: the catcher takes every
    // click in the window the chrome does not claim, so a widget (side pill, floater) keeps
    // its own clicks and the island survives them. The host must declare this engine
    // BEFORE the chrome, or the catcher sits on top and swallows those clicks.
    property var clickOutside: []
    property int leaveDelay: 400

    readonly property string state: BarState.stateFor(root.monitorName)
    readonly property bool hoverCloseActive: root.hoverClose.indexOf(root.state) >= 0
    readonly property bool clickOutsideActive: root.clickOutside.indexOf(root.state) >= 0
    readonly property alias catchArea: catcher

    onSurfaceHoveredChanged: {
        if (root.surfaceHovered)
            leaveTimer.stop();
        else if (root.hoverCloseActive)
            leaveTimer.restart();
    }

    // Bare Timer under an Item is fine; keep the id for the handler above.
    Timer {
        id: leaveTimer
        interval: root.leaveDelay
        onTriggered: {
            if (BarState.tourHoldFor(root.monitorName))
                return;
            if (root.hoverCloseActive)
                BarState.deactivate(root.state, root.monitorName);
        }
    }

    // Any state (re)activation clears a pending leave-close: a reopen must not
    // inherit an arm from before it (toggle race inside the leave window).
    Connections {
        target: BarState
        function onPanelStatesByMonitorChanged() {
            leaveTimer.stop();
        }
    }

    function outsidePressed() {
        if (BarState.tourHoldFor(root.monitorName))
            return;
        if (root.clickOutsideActive)
            BarState.deactivate(root.state, root.monitorName);
    }

    // Catcher: four MouseArea bands = the window minus the surface. It sits in the window's
    // lower stacking order (see the declaration-order note above), so chrome that accepts
    // input wins the click; the bands only see what the chrome leaves. The pill area is cut
    // out of them, so island clicks never reach a band.
    Item {
        id: catcher
        anchors.fill: parent
        visible: root.clickOutsideActive
        property real sx: root.surface ? root.surface.x : 0
        property real sy: root.surface ? root.surface.y : 0
        property real sw: root.surface ? root.surface.width : 0
        property real sh: root.surface ? root.surface.height : 0

        MouseArea {
            x: 0
            y: 0
            width: catcher.width
            height: catcher.sy
            onPressed: root.outsidePressed()
        }
        MouseArea {
            x: 0
            y: catcher.sy + catcher.sh
            width: catcher.width
            height: catcher.height - catcher.sy - catcher.sh
            onPressed: root.outsidePressed()
        }
        MouseArea {
            x: 0
            y: catcher.sy
            width: catcher.sx
            height: catcher.sh
            onPressed: root.outsidePressed()
        }
        MouseArea {
            x: catcher.sx + catcher.sw
            y: catcher.sy
            width: catcher.width - catcher.sx - catcher.sw
            height: catcher.sh
            onPressed: root.outsidePressed()
        }
    }
}
