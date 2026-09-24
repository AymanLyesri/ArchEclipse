import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs.theme
import qs.services
import qs.widgets.bar
import qs.widgets.bar.islands
import qs.widgets.launcher
import qs.widgets.shared

// Port of widgets/bar/Bar.tsx — the floating ArchEclipse bar pill.
PanelWindow {
    id: root

    required property ShellScreen screen
    readonly property string monitorName: {
        const hmon = Hyprland.monitorFor(screen);
        if (hmon && hmon.name)
            return hmon.name;
        // fallback: try to get monitor name from screen
        return screen?.name ?? "unknown";
    }
    // Full monitor height for the side islands (they stretch the whole
    // vertical screen, like the old edge panels did).
    readonly property int screenHeight: {
        const hmon = Hyprland.monitorFor(screen);
        return (hmon && hmon.height > 0) ? hmon.height : 1080;
    }

    // --- window geometry / layer ---
    // Always a full-width overlay strip (top or bottom edge): side pills
    // are independent overlays beside the main pill, never exclusive
    // zones, so anchors never change.
    anchors {
        left: true
        right: true
        top: Settings.barOrientation
        bottom: !Settings.barOrientation
    }

    // layer-shell keyboard grab while the search island is open
    // (the control island stays OnDemand so typing elsewhere keeps working)
    WlrLayershell.keyboardFocus: BarState.state === "search" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusiveZone: Settings.barLock ? root.barHeight : -1
    color: "transparent"
    aboveWindows: true

    // Click-through everywhere except the pills + edge hot-zones. The
    // window is a full-width, full-height transparent surface — without
    // a mask it eats every click outside the pills.
    mask: Region {
        item: pill
        Region {
            item: leftPill
        }
        Region {
            item: rightPill
        }
        Region {
            item: secondaryPill
        }
        Region {
            item: leftHot
        }
        Region {
            item: rightHot
        }
    }

    readonly property int barHeight: 32
    // Snap the layer surface to content (no Behavior here — animating the
    // PanelWindow renegotiates with the compositor every frame and stutters).
    // Inner content (pill width transition + island expand transition) carries motion.
    // Height tracks the tallest visible pill so tall side pills never
    // clip; width stays on the main pill (stretched full-width mode
    // ignores both, so this is safe).
    implicitHeight: Math.max(pill.height, leftPill.visible ? leftPill.height : 0, rightPill.visible ? rightPill.height : 0, secondaryPill.visible ? secondaryPill.height : 0)
    implicitWidth: pill.width

    // visibility: fullscreen focused client hides; search pins; override wins;
    // otherwise lock/smart-hide geometric room-check.
    // fullscreenClient = focusedClient with fullscreen === 2.
    readonly property bool fullscreenActive: {
        const mon = Hyprland.monitorFor(screen);
        const ws = mon?.activeWorkspace;
        if (!ws)
            return false;
        const wsId = ws.id ?? ws;
        const tops = Hyprland.toplevels.values.filter(t => (t.workspace?.id ?? t.workspace) === wsId);
        // Any fullscreen client on this monitor's active workspace occupies
        // the bar band (hyprctl clients fullscreen: 2 = fullscreen, 3 = maximized?)
        return tops.some(t => {
            const fs = t.lastIpcObject?.fullscreen;
            return fs === 2 || fs === 3;
        });
    }
    // Re-evaluate when Hyprland geometry events arrive (clients move/resize).
    readonly property bool roomCheckLive: BarState.hyprlandTick >= 0

    readonly property bool barVisible: {
        if (fullscreenActive)
            return false;
        if (BarState.state === "search" || BarState.state === "control" || BarState.state === "overview" || BarState.state === "wallpaper" || BarState.leftOpen || BarState.rightOpen)
            return true;
        const override = (BarState.barShown || {})[monitorName];
        if (override !== undefined)
            return override;
        BarState.hyprlandTick; // reap the reactive dependency
        return BarState.barVisibleFor(monitorName);
    }

    // --- hover: expand on enter, collapse after leave delay (motion
    // controller on the bar pill; leave arms a 250ms timer that collapses
    // only if the pointer is still off AND no popup is open) ---
    property bool hovered: pillHover.hovered
    // Documentation capture: expose the captured pill, not always the
    // main one — side-pill shots must frame the side pill (and image
    // inspection must walk its tree, not the bar strip's).
    readonly property var captureItem: BarState.leftOpen && leftLoader.item ? leftLoader.item : (BarState.rightOpen && rightLoader.item ? rightLoader.item : pill)
    function captureGeometry() {
        if (BarState.leftOpen)
            return root.sideCaptureGeometry(leftPill, "left");
        if (BarState.rightOpen)
            return root.sideCaptureGeometry(rightPill, "right");
        const p = pill.mapToItem(root.contentItem, 0, 0);
        return {visible: root.visible, displayed: stack.current,
            rect: {x: p.x, y: p.y, w: pill.width, h: pill.height}};
    }
    function sideCaptureGeometry(pillItem, name) {
        const g = pillItem.mapToItem(root.contentItem, 0, 0);
        return {visible: root.visible, displayed: name,
            rect: {x: g.x, y: g.y, w: pillItem.width, h: pillItem.height}};
    }
    Component.onDestruction: Registry.unregister("capture-bar-" + root.monitorName)
    Component.onCompleted: {
        Registry.register("capture-bar-" + root.monitorName, root);
        if (Settings.barDefault)
            BarState.activate("default");
    }
    onHoveredChanged: {
        if (hovered) {
            BarState.activate("default");
            hideTimer.stop();
        } else {
            hideTimer.restart();
        }
    }
    Timer {
        id: hideTimer
        interval: 250
        onTriggered: {
            // Leave handler: collapse default (guarded by hover+popup),
            // then conceal the bar when unlocked and search isn't pinning it.
            if (!root.hovered && BarState.popupCount <= 0 && !Settings.barDefault)
                BarState.deactivate("default");
            if (BarState.state !== "search" && BarState.state !== "control" && BarState.state !== "overview" && BarState.state !== "wallpaper" && !BarState.leftOpen && !BarState.rightOpen && !Settings.barLock && !root.hovered && BarState.popupCount <= 0)
                BarState.concealBar(root.monitorName);
        }
    }

    // idle watchdog for hover-reveal overrides
    Connections {
        target: BarState
        function onBarShownChanged() {
            if (BarState.barShown[root.monitorName] === true)
                idleTimer.restart();
            else
                idleTimer.stop();
        }
    }
    Timer {
        id: idleTimer
        interval: 1500
        running: (BarState.barShown || {})[root.monitorName] === true
        onTriggered: {
            if (Settings.barLock)
                return;
            if (BarState.state === "search" || BarState.state === "control" || BarState.state === "overview" || BarState.state === "wallpaper" || BarState.leftOpen || BarState.rightOpen) {
                idleTimer.restart();
                return;
            }
            // Watchdog: don't trust the hover read alone (reveals
            // can fire without an enter/leave cycle). Ask Hyprland where the
            // cursor actually is; if it is over the bar band or a popup is
            // open, keep waiting. If position is unknown, DON'T conceal
            // blindly — restart the check.
            if (BarState.popupCount > 0) {
                idleTimer.restart();
                return;
            }
            root.verifyCursorOffBar();
        }
    }

    // pointerOnBar(): cursorpos vs monitor band geometry.
    property var _cursorProc: null
    function verifyCursorOffBar() {
        if (root._cursorProc)
            return;
        var p = Qt.createQmlObject('import Quickshell.Io; Process { command: ["hyprctl", "cursorpos"] }', root);
        root._cursorProc = p;
        var out = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root);
        p.stdout = out;
        out.onStreamFinished.connect(() => {
            var proc = root._cursorProc;
            root._cursorProc = null;
            var stillOff = root.cursorOffBar(out.text);
            if (stillOff === true) {
                if (!root.hovered && BarState.popupCount <= 0)
                    BarState.concealBar(root.monitorName);
            } else if (stillOff === false) {
                idleTimer.restart();
            } else {
                // unknown — don't conceal blindly
                idleTimer.restart();
            }
            out.destroy();
            proc.destroy();
        });
        p.running = true;
    }
    // Returns true = cursor verifiably off bar, false = on bar,
    // undefined = can't tell.
    function cursorOffBar(cursorText) {
        try {
            var parts = (cursorText || "").trim().split(",");
            if (parts.length < 2)
                return undefined;
            var x = parseInt(parts[0], 10);
            var y = parseInt(parts[1], 10);
            if (isNaN(x) || isNaN(y))
                return undefined;
            var mon = Hyprland.monitorFor(screen);
            if (!mon)
                return undefined;
            var h = root.barHeight;
            if (x < mon.x || x > mon.x + mon.width)
                return true;
            var onBar = Settings.barOrientation ? y <= mon.y + h : y >= mon.y + mon.height - h;
            return !onBar;
        } catch (e) {
            return undefined;
        }
    }

    Item {
        id: stripRoot
        anchors.fill: parent

        // ---- the pill ----
        Rectangle {
            id: pill
            // Pushed-center: side pills dock to the screen edges and the
            // main pill centers in the remaining space — never fixed-center,
            // never overlapping. `x` itself carries NO Behavior: it tracks
            // per-frame (rigidly coupled to width animations). Discrete
            // open/close pushes animate through leftPush/rightPush with the
            // same easing as the width, so everything moves as one unit.
            property real leftPush: leftPill.visible ? 8 + leftPill.width + 8 : 0
            Behavior on leftPush {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
            property real rightPush: (rightPill.visible ? rightPill.width + 8 : 0) + (secondaryPill.visible ? secondaryPill.width + 8 : 0)
            Behavior on rightPush {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
            property real pillX: {
                var rightStart = rightPush > 0 ? parent.width - 8 - rightPush : parent.width;
                return leftPush + Math.max(0, (rightStart - leftPush - pill.width) / 2);
            }
            x: pillX
            y: Settings.barOrientation ? 0 : parent.height - height
            // Grows with content: 32 for normal states, tall when the
            // search island (input + launcher) is shown.
            height: Math.max(root.barHeight, stack.height + 10)
            // Bound to targetWidth + transition: a plain NumberAnimation
            // (duration + easing curve, no bounce/velocity) keeps state
            // changes predictable — the pill eases between widths instead
            // of overshooting.
            width: targetWidth
            property bool widthAnimReady: false
            Component.onCompleted: widthAnimReady = true
            Behavior on width {
                enabled: pill.widthAnimReady
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
            bottomRightRadius: Theme.radius
            bottomLeftRadius: Theme.radius
            color: Theme.surface

            // Hover detection lives on the pill itself (stable container).
            // The motion controller is on the bar pill — hot-zone
            // strips at the bar ends must NOT trigger expand.
            HoverHandler {
                id: pillHover
            }

            // Width target (grow-first/shrink-first sequencing).
            // widthOverride pins the target during grow-first sequencing.
            property real widthOverride: -1
            property real targetWidth: widthOverride >= 0 ? widthOverride : Math.max(stack.width + 10, 100)

            // ---- state stack with crossfade ----
            // When GROWING, animate
            // the width first and swap content 100ms later; when SHRINKING,
            // swap content first and animate after 100ms. This keeps the
            // pill from clipping big content or collapsing under small one.
            Item {
                id: stack
                anchors.centerIn: parent

                // Size from implicit* only — never .height/.width/childrenRect.
                // Those depend on stack's assigned size and create binding loops.
                property real activeWidth: {
                    var it = currentPageLoader.item;
                    return it ? (it.implicitWidth || 0) : 0;
                }

                onActiveWidthChanged: {
                    if (activeWidth > 0) {
                        stack.width = activeWidth;
                    }
                }

                property real activeHeight: {
                    var hit = currentPageLoader.item;
                    return hit ? (hit.implicitHeight || 0) : 0;
                }

                onActiveHeightChanged: {
                    if (activeHeight > 0) {
                        stack.height = activeHeight;
                    }
                }

                // The state actually shown (lags BarState.state by 100ms on grow)
                property string displayed: BarState.state
                property string pending: ""
                // Exit driver: while an island folds closed (expand 1 -> 0)
                // `exitingFrom` holds its name so cached Loaders stay
                // visible until exitTimer swaps in the pending state.
                property string exitingFrom: ""
                // Measured widths per state
                property var widthCache: ({})

                // The live item for a shown state (cached islands via
                // their Loaders, transient islands via currentPageLoader
                // while `displayed` still names them), or null.
                function exitItemFor(stateName) {
                    if (stateName === stack.displayed)
                        return currentPageLoader.item;
                    return null;
                }
                function exitCapable(stateName) {
                    var it = stack.exitItemFor(stateName);
                    return it !== null && it !== undefined && it["expand"] !== undefined;
                }
                function driveExit(stateName) {
                    var it = stack.exitItemFor(stateName);
                    if (it && it["expand"] !== undefined)
                        it.expand = 0;
                }

                Connections {
                    target: BarState
                    function onStateChanged() {
                        var s = BarState.state;
                        if (s === stack.displayed) {
                            stack.pending = "";
                            swapTimer.stop();
                            // Reopened mid-exit: cancel the close, unfold again.
                            if (stack.exitingFrom !== "") {
                                var resume = stack.exitingFrom;
                                stack.exitingFrom = "";
                                exitTimer.stop();
                                var rit = stack.exitItemFor(resume);
                                if (rit && rit["expand"] !== undefined)
                                    rit.expand = 1;
                            }
                            return;
                        }
                        // A new state supersedes any in-flight exit.
                        exitTimer.stop();
                        stack.exitingFrom = "";
                        // Same page family (volume -> control on hover-pin,
                        // volume <-> brightness across key presses): swap
                        // instantly with no grow/shrink sequencing — the
                        // Loader resolves the same component, so there is
                        // nothing to animate.
                        if (stack.pageFamily(s) === stack.pageFamily(stack.displayed)) {
                            stack.pending = "";
                            swapTimer.stop();
                            pill.widthOverride = -1;
                            stack.displayed = s;
                            return;
                        }
                        var cachedw = stack.widthCache[s];
                        if (cachedw !== undefined && cachedw > pill.width) {
                            // Growing: expand first, swap content after 100ms
                            // (Behavior on pill.width carries the motion).
                            stack.pending = s;
                            pill.widthOverride = cachedw + 10;
                            swapTimer.restart();
                        } else if (stack.pageFamily(s) === "default" && stack.exitCapable(stack.displayed)) {
                            // Closing back to the bar: fold the outgoing
                            // island (expand 1 -> 0) before swapping, so
                            // closes animate instead of vanishing. The
                            // s === displayed guard above cancels this if
                            // the island reopens mid-exit.
                            stack.pending = s;
                            stack.exitingFrom = stack.displayed;
                            pill.widthOverride = -1;
                            stack.driveExit(stack.displayed);
                            exitTimer.restart();
                        } else {
                            // Shrinking or unknown: swap now, width follows
                            stack.pending = "";
                            swapTimer.stop();
                            pill.widthOverride = -1;
                            stack.displayed = s;
                        }
                    }
                }
                Timer {
                    id: swapTimer
                    interval: 100
                    onTriggered: {
                        if (stack.pending !== "") {
                            stack.displayed = stack.pending;
                            stack.pending = "";
                        }
                        pill.widthOverride = -1;
                    }
                }
                // Exit timer: fires once the outgoing island's fold
                // (expand 1 -> 0, Emphasized normal) has completed.
                Timer {
                    id: exitTimer
                    interval: Theme.anim.normal
                    onTriggered: {
                        if (stack.pending !== "" && stack.exitingFrom !== "") {
                            stack.displayed = stack.pending;
                            stack.pending = "";
                            stack.exitingFrom = "";
                        }
                        pill.widthOverride = -1;
                    }
                }

                property string current: stack.displayed
                // Page family: volume/brightness/control all render
                // through controlPage, so transitions within the family
                // must not replay the swap churn (grow-first width
                // sequencing + crossfade) — same content, no reveal.
                // recording renders through the secondary pill (its main
                // stack entry maps to defaultPage), so it joins the
                // default family for the same reason.
                function pageFamily(s) {
                    if (s === "volume" || s === "brightness" || s === "control")
                        return "control";
                    if (s === "recording")
                        return "default";
                    return s;
                }
                property string lastFamily: "default"
                onCurrentChanged: {
                    var fam = stack.pageFamily(current);
                    if (fam !== stack.lastFamily)
                        fade.restart();
                    stack.lastFamily = fam;
                }
                readonly property string previous: ""

                SequentialAnimation {
                    id: fade
                    PropertyAction {
                        target: stack
                        property: "opacity"
                        value: 1
                    }
                    Anim {
                        target: stack
                        property: "opacity"
                        from: 0
                        to: 1
                        type: Anim.DefaultEffects
                    }
                }

                Loader {
                    id: currentPageLoader
                    // Handles the small transient states only — left/right
                    // live in their own side pills, recording in its own.
                    sourceComponent: {
                        switch (stack.current) {
                        case "default":
                            return defaultPage;
                        case "volume":
                            return controlPage;
                        case "brightness":
                            return controlPage;
                        case "recording":
                            // Recording lives in the secondary pill beside
                            // the main pill — the main stack shows default
                            // content so the bar is never hijacked.
                            return defaultPage;
                        case "player":
                            return playerPage;
                        case "weather":
                            return weatherPage;
                        case "network":
                            return networkPage;
                        case "search":
                            return searchPage;
                        case "system":
                            return systemPage;
                        case "control":
                            return controlPage;
                        case "overview":
                            return overviewPage;
                        case "wallpaper":
                            return wallpaperPage;
                        default:
                            return defaultPage;
                        }
                    }
                    // Feed the per-state width registry.
                    onLoaded: {
                        if (item && item["monitorName"] !== undefined)
                            item.monitorName = root.monitorName;
                        if (item && item["screenHeight"] !== undefined)
                            item.screenHeight = root.screenHeight;
                        // Recording is owned by the secondary pill — don't
                        // pollute its width cache with default-page metrics.
                        if (stack.current === "recording")
                            return;
                        var mw = item ? Math.max(item.width || 0, item.implicitWidth || 0) : 0;
                        if (mw > 0) {
                            var c = Object.assign({}, stack.widthCache);
                            c[stack.current] = mw;
                            stack.widthCache = c;
                        }
                    }
                }

                Component {
                    id: defaultPage
                    DefaultBar {}
                }
                Component {
                    id: playerPage
                    PlayerIsland {}
                }
                Component {
                    id: weatherPage
                    WeatherIsland {}
                }
                Component {
                    id: networkPage
                    NetworkWidget {}
                }
                Component {
                    id: searchPage
                    SearchIsland {}
                }
                Component {
                    id: systemPage
                    SystemMonitorIsland {}
                }
                Component {
                    id: controlPage
                    ControlIsland {}
                }
                Component {
                    id: overviewPage
                    OverviewIsland {}
                }
                Component {
                    id: wallpaperPage
                    WallpaperIsland {}
                }
            }
        }

        Component {
            id: leftPage
            LeftIsland {}
        }
        Component {
            id: rightPage
            RightIsland {}
        }

        // ---- left side pill (independent of the main pill) ----
        // Owns the left island in a forever-alive cached Loader: created
        // lazily on first open, then visibility-toggled so tab/scroll/
        // chat/booru state survives closes.
        Rectangle {
            id: leftPill
            // Docked to the left screen edge, outermost; the main pill yields.
            x: 8
            y: Settings.barOrientation ? 0 : parent.height - height
            width: Settings.leftPanelWidth
            height: Math.max(400, root.screenHeight - 15)
            visible: BarState.leftOpen && root.barVisible
            bottomRightRadius: Theme.radius
            bottomLeftRadius: Theme.radius
            color: Theme.surface
            property bool primed: false
            onVisibleChanged: {
                if (visible) {
                    if (!leftPill.primed) {
                        leftPill.primed = true;
                    } else {
                        if (leftLoader.item && leftLoader.item["cancelPendingHide"] !== undefined)
                            leftLoader.item.cancelPendingHide();
                        if (leftLoader.item && leftLoader.item["expand"] !== undefined) {
                            leftLoader.item.expand = 0;
                            (function (target) {
                                Qt.callLater(function () {
                                    if (target)
                                        target.expand = 1;
                                });
                            })(leftLoader.item);
                        }
                    }
                }
            }
            Loader {
                id: leftLoader
                anchors.fill: parent
                active: leftPill.primed
                visible: leftPill.visible
                asynchronous: false
                sourceComponent: leftPage
                onLoaded: {
                    if (item && item["monitorName"] !== undefined)
                        item.monitorName = root.monitorName;
                    if (item && item["screenHeight"] !== undefined)
                        item.screenHeight = root.screenHeight;
                    if (item && item["screen"] !== undefined)
                        item.screen = root.screen;
                }
            }
        }

        // ---- right side pill (independent of the main pill) ----
        Rectangle {
            id: rightPill
            // Docked to the right screen edge, outermost; the main pill
            // and recording yield.
            x: parent.width - width - 8
            y: Settings.barOrientation ? 0 : parent.height - height
            width: Settings.rightPanelWidth
            height: Math.max(400, root.screenHeight - 15)
            visible: BarState.rightOpen && root.barVisible
            bottomRightRadius: Theme.radius
            bottomLeftRadius: Theme.radius
            color: Theme.surface
            property bool primed: false
            onVisibleChanged: {
                if (visible) {
                    if (!rightPill.primed) {
                        rightPill.primed = true;
                    } else {
                        if (rightLoader.item && rightLoader.item["cancelPendingHide"] !== undefined)
                            rightLoader.item.cancelPendingHide();
                        if (rightLoader.item && rightLoader.item["expand"] !== undefined) {
                            rightLoader.item.expand = 0;
                            (function (target) {
                                Qt.callLater(function () {
                                    if (target)
                                        target.expand = 1;
                                });
                            })(rightLoader.item);
                        }
                    }
                }
            }
            Loader {
                id: rightLoader
                anchors.fill: parent
                active: rightPill.primed
                visible: rightPill.visible
                asynchronous: false
                sourceComponent: rightPage
                onLoaded: {
                    if (item && item["monitorName"] !== undefined)
                        item.monitorName = root.monitorName;
                    if (item && item["screenHeight"] !== undefined)
                        item.screenHeight = root.screenHeight;
                }
            }
        }

        // ---- secondary pill (recording) ----
        // Chained right of the main pill; the right pill sits outermost
        // after it. Owns the recording island so ScreenRecorder never
        // hijacks the main pill: visible only while recording, hidden
        // with the bar (fullscreen/conceal). Glides when pushed.
        Rectangle {
            id: secondaryPill
            // Rigid chain right of the main pill (no Behavior — tracks
            // per-frame, coupled to the main pill's own motion).
            x: pill.x + pill.width + 8
            y: Settings.barOrientation ? 0 : parent.height - height
            height: root.barHeight
            width: secondaryLoader.item ? (secondaryLoader.item.implicitWidth + 10) : 190
            visible: ScreenRecorder.isRecording && root.barVisible
            bottomRightRadius: Theme.radius
            bottomLeftRadius: Theme.radius
            color: Theme.surface

            Loader {
                id: secondaryLoader
                anchors.centerIn: parent
                active: secondaryPill.visible
                sourceComponent: secondaryRecordingPage
            }
            Component {
                id: secondaryRecordingPage
                RecordingIsland {}
            }
        }

        // ---- hot zones (left/right island reveal strips) ----
        HotZone {
            id: leftHot
            side: "left"
            size: Settings.leftPanelHotZoneSize
            enabled: Settings.leftPanelHotZone
            panelLock: Settings.leftPanelLock
        }
        HotZone {
            id: rightHot
            side: "right"
            size: Settings.rightPanelHotZoneSize
            enabled: Settings.rightPanelHotZone
            panelLock: Settings.rightPanelLock
        }
    }

    visible: barVisible
}
