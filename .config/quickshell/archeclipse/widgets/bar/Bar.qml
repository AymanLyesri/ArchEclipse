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
    // Side-island vertical exclusivity ("horizontal becomes vertical"):
    // while an island whose exclusivity setting is on is open, the window
    // drops the far-side anchor and reserves the island's width from the
    // docked edge (the same edge + both-perpendiculars anchor pattern the
    // old edge panels used statically) instead of the top strip. Applied
    // atomically with the state change — anchors, margins, zone and the
    // offset zeroing below all commit in the same frame — so there is no
    // staged switch to race the surface resize and glitch. The pill width
    // transition then grows the edge-anchored surface in place (it expands
    // from the docked edge instead of gliding across the screen).
    readonly property bool leftVert: BarState.state === "left" && Settings.leftPanelExclusivity
    readonly property bool rightVert: BarState.state === "right" && Settings.rightPanelExclusivity

    anchors {
        left: !root.rightVert
        right: !root.leftVert
        top: Settings.barOrientation || root.leftVert || root.rightVert
        bottom: !Settings.barOrientation || root.leftVert || root.rightVert
    }
    margins {
        top: 0
        bottom: 0
        left: root.leftVert ? 8 : 0
        right: root.rightVert ? 8 : 0
    }

    // layer-shell keyboard grab while the search island is open
    // (the control island stays OnDemand so typing elsewhere keeps working)
    WlrLayershell.keyboardFocus: BarState.state === "search" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusiveZone: {
        if (root.leftVert || root.rightVert)
            // Island width; the compositor adds the 10px edge margin on
            // top, so the reservation lands exactly on the docked pill.
            return Math.round(pill.targetWidth);
        if (BarState.state === "left" || BarState.state === "right")
            // Side island open as an overlay (its exclusivity setting is
            // off): drop the main bar strip reservation (top or bottom)
            // while the panel is up.
            return -1;
        return Settings.barLock ? root.barHeight : -1;
    }
    color: "transparent"
    aboveWindows: true

    // Click-through everywhere except the pill + edge hot-zones. With
    // exclusivity OFF the window is a full-width, full-height transparent
    // surface (the pill snaps tall for the island) — without a mask it
    // eats every click outside the island. With exclusivity ON the window
    // already hugs the island, so the mask is a no-op there.
    mask: Region {
        item: pill
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
    // NOTE: implicitWidth must track the pill too, not just height — once a
    // side island drops the far-side anchor, the surface sizes to content
    // and an unbound implicitWidth strands it at a stale width (clipped
    // island). Stretched full-width mode ignores both, so this is safe.
    implicitHeight: pill.height
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
        if (BarState.state === "search" || BarState.state === "control" || BarState.state === "overview" || BarState.state === "wallpaper" || BarState.state === "left" || BarState.state === "right")
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
    // Documentation capture: expose the actual pill, not its stretched surface.
    readonly property var captureItem: pill
    function captureGeometry() {
        const p = pill.mapToItem(root.contentItem, 0, 0);
        return {visible: root.visible, displayed: stack.current,
            rect: {x: p.x, y: p.y, w: pill.width, h: pill.height}};
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
            if (BarState.state !== "search" && BarState.state !== "control" && BarState.state !== "overview" && BarState.state !== "wallpaper" && BarState.state !== "left" && BarState.state !== "right" && !Settings.barLock && !root.hovered && BarState.popupCount <= 0)
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
            if (BarState.state === "search" || BarState.state === "control" || BarState.state === "overview" || BarState.state === "wallpaper" || BarState.state === "left" || BarState.state === "right") {
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
            anchors.horizontalCenter: parent.horizontalCenter
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
                // No width transition while a vertical-exclusive island is open:
                // the surface tracks the pill size, so animating it would
                // renegotiate every frame (clipping/tearing). Exclusive
                // opens snap to final geometry instead; the content
                // crossfade + island unfold below carry the motion.
                enabled: pill.widthAnimReady && !root.leftVert && !root.rightVert
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }
            bottomRightRadius: Theme.radius
            bottomLeftRadius: Theme.radius
            color: Theme.surface

            // Island docking: when a side island opens, the pill glides to
            // that screen edge (10px margin, like the old edge panels) and
            // hangs the island there — the bar anchors left/right instead
            // of swapping centered, so bar + island travel as one
            // continuous unit. Driven off BarState.state (not the lagged
            // displayed state) so the glide starts on the same frame as
            // the width transition, with the same duration/curve for one
            // coordinated motion.
            property real shift: shiftTarget
            property real shiftTarget: {
                var s = BarState.state;
                if (s !== "left" && s !== "right")
                    return 0;
                var maxShift = Math.max(0, (parent.width - pill.targetWidth) / 2);
                var docked = Math.max(0, maxShift - 10);
                return s === "left" ? -docked : docked;
            }
            Behavior on shift {
                enabled: pill.widthAnimReady
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }
            anchors.horizontalCenterOffset: (root.leftVert || root.rightVert) ? 0 : shift

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
                    if (stack.current === "left" && leftCacheLoader.item)
                        return leftCacheLoader.item.implicitWidth || 0;
                    if (stack.current === "right" && rightCacheLoader.item)
                        return rightCacheLoader.item.implicitWidth || 0;
                    var it = currentPageLoader.item;
                    return it ? (it.implicitWidth || 0) : 0;
                }

                onActiveWidthChanged: {
                    if (activeWidth > 0) {
                        stack.width = activeWidth;
                        // Keep the grow-first width registry fresh for cached islands
                        if (stack.current === "left" || stack.current === "right") {
                            var c = Object.assign({}, stack.widthCache);
                            if (c[stack.current] !== activeWidth) {
                                c[stack.current] = activeWidth;
                                stack.widthCache = c;
                            }
                        }
                    }
                }

                property real activeHeight: {
                    if (stack.current === "left" && leftCacheLoader.item)
                        return leftCacheLoader.item.implicitHeight || 0;
                    if (stack.current === "right" && rightCacheLoader.item)
                        return rightCacheLoader.item.implicitHeight || 0;
                    var hit = currentPageLoader.item;
                    return hit ? (hit.implicitHeight || 0) : 0;
                }

                onActiveHeightChanged: {
                    if (activeHeight > 0) {
                        stack.height = activeHeight;
                    }
                }

                // Latch: once a side island has opened, its Loader stays
                // active forever — the island is created once (lazily, on
                // first open so startup stays fast) and then kept alive
                // across closes. Reopens only toggle visibility: no
                // rebuild, no refetch, tab/scroll/chat/booru state survives.
                property bool leftPrimed: false
                property bool rightPrimed: false

                // The state actually shown (lags BarState.state by 100ms on grow)
                property string displayed: BarState.state
                property string pending: ""
                // Measured widths per state
                property var widthCache: ({})

                Connections {
                    target: BarState
                    function onStateChanged() {
                        var s = BarState.state;
                        if (s === stack.displayed) {
                            stack.pending = "";
                            swapTimer.stop();
                            return;
                        }
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
                        // Exclusive island open: pin the width target straight
                        // to final geometry through the Loader gap (the width
                        // transition is off while vert, and the target would
                        // otherwise sit on the stale lastWidth, landing the
                        // fresh surface at the wrong size for a frame).
                        // Cached (already-instantiated) islands measure
                        // instantly, so they skip the pin entirely.
                        if ((s === "left" && root.leftVert) || (s === "right" && root.rightVert)) {
                            stack.pending = "";
                            swapTimer.stop();
                            var cached = (s === "left" && leftCacheLoader.item) || (s === "right" && rightCacheLoader.item);
                            if (!cached)
                                pill.widthOverride = (s === "left" ? Settings.leftPanelWidth : Settings.rightPanelWidth) + 10;
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

                property string current: stack.displayed
                // Page family: volume/brightness/control all render
                // through controlPage, so transitions within the family
                // must not replay the swap churn (grow-first width
                // sequencing + crossfade) — same content, no reveal.
                function pageFamily(s) {
                    if (s === "volume" || s === "brightness" || s === "control")
                        return "control";
                    return s;
                }
                property string lastFamily: "default"
                onCurrentChanged: {
                    var fam = stack.pageFamily(current);
                    if (fam !== stack.lastFamily)
                        fade.restart();
                    stack.lastFamily = fam;
                    // Prime the side-island cache on first open; the Loader
                    // stays active from then on (created once, kept alive).
                    // Synchronous load, so the item exists right after.
                    var firstLoad = false;
                    if (current === "left" && !stack.leftPrimed) {
                        stack.leftPrimed = true;
                        firstLoad = true;
                    } else if (current === "right" && !stack.rightPrimed) {
                        stack.rightPrimed = true;
                        firstLoad = true;
                    }
                    var isl = current === "left" ? leftCacheLoader.item : (current === "right" ? rightCacheLoader.item : null);
                    if (isl) {
                        // Kill a hide timer armed before the last close —
                        // it must not fire into this fresh session.
                        if (isl["cancelPendingHide"] !== undefined)
                            isl.cancelPendingHide();
                        // Reopen unfold: the cached island's expand value
                        // stays at 1 while hidden, so replay 0 -> 1 for the
                        // same unfold motion a fresh creation had (deferred
                        // a frame so the 0 commits before the 1 animates).
                        // Fresh creation animates itself — don't restart it.
                        if (!firstLoad && isl["expand"] !== undefined) {
                            isl.expand = 0;
                            (function (target) {
                                Qt.callLater(function () {
                                    if (target)
                                        target.expand = 1;
                                });
                            })(isl);
                        }
                    }
                }
                readonly property string previous: ""

                SequentialAnimation {
                    id: fade
                    PropertyAction {
                        target: stack
                        property: "opacity"
                        value: 1
                    }
                    NumberAnimation {
                        target: stack
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 500
                        easing.type: Easing.InOutQuad
                    }
                }

                // Side islands live here permanently (lazy-cached): the main
                // Loader below only handles the small transient states, so
                // opening left/right never destroys them. Synchronous load
                // (like before) so the first open is instant; visible
                // toggles the already-built subtree (no paint cost hidden).
                Loader {
                    id: leftCacheLoader
                    active: stack.leftPrimed
                    visible: stack.current === "left"
                    asynchronous: false
                    sourceComponent: leftPage
                    onLoaded: {
                        if (item && item["monitorName"] !== undefined)
                            item.monitorName = root.monitorName;
                        if (item && item["screenHeight"] !== undefined)
                            item.screenHeight = root.screenHeight;
                        if (item && item["screen"] !== undefined)
                            item.screen = root.screen;
                        if (stack.displayed === "left")
                            pill.widthOverride = -1;
                        var mw = item ? Math.max(item.width || 0, item.implicitWidth || 0) : 0;
                        if (mw > 0) {
                            var c = Object.assign({}, stack.widthCache);
                            c["left"] = mw;
                            stack.widthCache = c;
                        }
                    }
                }
                Loader {
                    id: rightCacheLoader
                    active: stack.rightPrimed
                    visible: stack.current === "right"
                    asynchronous: false
                    sourceComponent: rightPage
                    onLoaded: {
                        if (item && item["monitorName"] !== undefined)
                            item.monitorName = root.monitorName;
                        if (item && item["screenHeight"] !== undefined)
                            item.screenHeight = root.screenHeight;
                        if (stack.displayed === "right")
                            pill.widthOverride = -1;
                        var mw = item ? Math.max(item.width || 0, item.implicitWidth || 0) : 0;
                        if (mw > 0) {
                            var c = Object.assign({}, stack.widthCache);
                            c["right"] = mw;
                            stack.widthCache = c;
                        }
                    }
                }

                Loader {
                    id: currentPageLoader
                    // Left/right are served by the cached Loaders above —
                    // show an empty page here so the transient Loader never
                    // instantiates (and destroys) them on open/close.
                    sourceComponent: {
                        switch (stack.current) {
                        case "default":
                            return defaultPage;
                        case "volume":
                            return controlPage;
                        case "brightness":
                            return controlPage;
                        case "recording":
                            return recordingPage;
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
                        case "left":
                            return emptyPage;
                        case "right":
                            return emptyPage;
                        default:
                            return defaultPage;
                        }
                    }
                    // Feed the per-state width registry.
                    // Left/right are served by the cached Loaders (which
                    // release their own pin onLoaded), so this must NOT
                    // touch widthOverride — the empty page loads instantly
                    // and would clear the exclusive-open pin before the
                    // async island arrives.
                    onLoaded: {
                        if (item && item["monitorName"] !== undefined)
                            item.monitorName = root.monitorName;
                        if (item && item["screenHeight"] !== undefined)
                            item.screenHeight = root.screenHeight;
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
                    id: recordingPage
                    RecordingIsland {}
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
                Component {
                    id: emptyPage
                    Item {}
                }
                Component {
                    id: leftPage
                    LeftIsland {}
                }
                Component {
                    id: rightPage
                    RightIsland {}
                }
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
