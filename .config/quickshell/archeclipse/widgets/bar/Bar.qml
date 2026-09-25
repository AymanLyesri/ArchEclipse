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
import qs.widgets.notifications
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
        // Regions track item geometry even when the item is hidden, so
        // null the item while its pill is closed — otherwise the
        // full-height surface eats clicks across the hidden pill's area.
        Region {
            item: leftPill.visible ? leftPill : null
        }
        Region {
            item: rightPill.visible ? rightPill : null
        }
        Region {
            item: secondaryPill.visible ? secondaryPill : null
        }
        Region {
            item: notifPill.visible ? notifPill : null
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
    // The surface stays full monitor height at all times — never snapped
    // to content. Snapping (38px <-> ~1065px) on every panel open/close
    // reallocates the layer buffer mid-glide, flashing the static main
    // pill and perturbing width measurement for a frame (expand/collapse
    // flicker). Input stays pill-only via the mask; the zone reservation
    // is unchanged (exclusiveZone above). Stretched full-width mode
    // ignores implicit sizes, so this is safe.
    implicitHeight: root.screenHeight
    implicitWidth: pill.width

    // visibility: search pins; override wins;
    // otherwise lock/smart-hide geometric room-check.
    // Re-evaluate when Hyprland geometry events arrive (clients move/resize).
    readonly property bool roomCheckLive: BarState.hyprlandTick >= 0

    readonly property bool barVisible: {
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
            property real leftPush: leftPill.flag ? 8 + leftPill.width + 8 : 0
            Behavior on leftPush {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
            property real rightPush: (rightPill.flag ? rightPill.width + 8 : 0) + (secondaryPill.flag ? secondaryPill.width + 8 : 0)
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
            // Shrink-only glide: when the target sits below the current
            // height (closes), ease down; when growing, track the unfolding
            // content rigidly per-frame — gliding there would chase a moving
            // target and lag behind it (verified via probe).
            Behavior on height {
                enabled: pill.height > stack.height + 10
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
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

            // Width target: follows the stack content (one-beat transitions —
            // content swaps immediately while the width glides; the island's
            // own clip wipe masks the grow, and `clip` below cuts spill at
            // the animating edge, so no grow-first pin is needed).
            property real targetWidth: Math.max(stack.width + 10, 100)
            // Cut content wider than the (still gliding) pill at the pill
            // edge: opens reveal outward as the pill grows instead of
            // spilling past it. Settled content fits with 5px to spare,
            // so this is a no-op outside transitions.
            clip: true

            // ---- state stack (one beat) ----
            // Content swaps the same frame the state resolves; the pill
            // width glides under it while the island unfolds — background
            // and content animate as one unit, like the side pills.
            Item {
                id: stack
                // Docked to the bar edge (top for a top bar, bottom for a
                // bottom bar) — never centered: centering lets content drift
                // vertically while the pill height glides. 5px edge margin
                // preserves the settled 10px surround exactly.
                anchors.top: Settings.barOrientation ? parent.top : undefined
                anchors.bottom: Settings.barOrientation ? undefined : parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 5
                anchors.bottomMargin: 5

                // Size from implicit* only — never .height/.width/childrenRect.
                // Those depend on stack's assigned size and create binding loops.
                property real activeWidth: {
                    if (stack.current === "wallpaper" && wallpaperCacheLoader.item)
                        return wallpaperCacheLoader.item.implicitWidth || 0;
                    var it = currentPageLoader.item;
                    return it ? (it.implicitWidth || 0) : 0;
                }

                onActiveWidthChanged: {
                    if (activeWidth > 0) {
                        stack.width = activeWidth;
                    }
                }

                property real activeHeight: {
                    if (stack.current === "wallpaper" && wallpaperCacheLoader.item)
                        return wallpaperCacheLoader.item.implicitHeight || 0;
                    var hit = currentPageLoader.item;
                    return hit ? (hit.implicitHeight || 0) : 0;
                }

                onActiveHeightChanged: {
                    if (activeHeight > 0) {
                        stack.height = activeHeight;
                    }
                }

                // Latch: the heavy wallpaper island is created once (lazily,
                // on first open so startup stays fast) and then kept alive
                // across closes — reopens only toggle visibility, so image
                // decodes, aspect caches, scroll and tab state survive.
                property bool wallpaperPrimed: false

                // The state actually shown — bound straight to BarState.state.
                // (A Connections-guarded variant was tried and removed: the
                // binding updates before signal handlers run, so any
                // s === displayed guard exits early forever and branch logic
                // placed there silently never executes — root-caused via
                // probe 2026-09-24. All swap logic lives in onCurrentChanged
                // + bindings below.)
                property string displayed: BarState.state

                // The live item for a shown state (cached wallpaper via
                // its Loader, transient islands via currentPageLoader).

                property string current: stack.displayed
                // Note: volume/brightness/control all resolve to controlPage
                // in the switch below, so pulses across them keep the same
                // Loader item with no swap churn — same content, no reveal.
                // (Recording maps to defaultPage for the same reason.)
                onCurrentChanged: {
                    // Prime the wallpaper cache on first open; the Loader
                    // stays active from then on (created once, kept alive).
                    var firstLoad = false;
                    if (current === "wallpaper" && !stack.wallpaperPrimed) {
                        stack.wallpaperPrimed = true;
                        firstLoad = true;
                    }
                    // Reopen unfold: the island always rests folded (expand 0)
                    // — via the exit fold, or the silent reset below for
                    // fold-skipping direct switches — so a single assignment
                    // unfolds cleanly. (A 0-then-1 replay in the same tick
                    // self-cancels the Behavior: it retargets before anything
                    // renders and nothing moves. Verified via probe.)
                    var wisl = current === "wallpaper" ? wallpaperCacheLoader.item : null;
                    if (wisl && !firstLoad && wisl["expand"] !== undefined)
                        wisl.expand = 1;
                    // Fold-skipping switches (island -> island) hide the cached
                    // island with expand still 1 — reset silently while hidden
                    // so the next reopen unfolds from 0 with one assignment.
                    if (current !== "wallpaper" && wallpaperCacheLoader.item && wallpaperCacheLoader.item["expand"] !== undefined)
                        wallpaperCacheLoader.item.expand = 0;
                }
                readonly property string previous: ""

                // Wallpaper lives here permanently (lazy-cached): created once
                // on first open, then visibility-toggled so decodes, aspect
                // caches and scroll survive closes. Synchronous load so the
                // first open is instant; visible toggles the already-built
                // subtree (no paint cost hidden).
                Loader {
                    id: wallpaperCacheLoader
                    active: stack.wallpaperPrimed
                    visible: stack.current === "wallpaper"
                    asynchronous: false
                    sourceComponent: wallpaperPage
                    onLoaded: {
                        if (item && item["monitorName"] !== undefined)
                            item.monitorName = root.monitorName;
                    }
                }

                Loader {
                    id: currentPageLoader
                    // Handles the small transient states only — left/right
                    // live in their own side pills, recording in its own,
                    // wallpaper in the cached Loader above (show an empty
                    // page here so the transient Loader never instantiates
                    // and destroys it on open/close).
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
                            return emptyPage;
                        default:
                            return defaultPage;
                        }
                    }
                    // Probe pass-through for per-state bodies.
                    onLoaded: {
                        if (item && item["monitorName"] !== undefined)
                            item.monitorName = root.monitorName;
                        if (item && item["screenHeight"] !== undefined)
                            item.screenHeight = root.screenHeight;
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
                Component {
                    id: emptyPage
                    Item {}
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
        Item {
            id: leftPill
            // Docked to the left screen edge, outermost; the main pill yields.
            // Transparent positioning shell — the surface background lives
            // inside the unfold clip below so the panel wipes as one unit.
            x: 8
            y: Settings.barOrientation ? 0 : parent.height - height
            width: Settings.leftPanelWidth
            height: Math.max(400, root.screenHeight - 15)
            visible: leftPill.shown && root.barVisible
            property bool primed: false
            // Open/close transition (mirrors the main-stack exit driver):
            // open shows instantly and the clip unfolds; close folds first
            // (openT 1 -> 0, animated inside IslandExpandClip) and hides
            // when the fold completes. Reopen mid-fold cancels the hide.
            // openT is set discretely — the clip animates it internally
            // (never chase it with a second Behavior). The island's own
            // expand stays pinned at 1 after creation (dormant): a single
            // unfold plays, exactly like a main-stack island.
            property bool shown: false
            property bool flag: BarState.leftOpen
            onFlagChanged: leftPill.setShown(leftPill.flag)
            Component.onCompleted: leftPill.setShown(leftPill.flag)
            property real openT: 0
            function setShown(open) {
                if (open) {
                    leftCloseTimer.stop();
                    if (!primed)
                        primed = true;
                    else if (leftLoader.item && leftLoader.item["cancelPendingHide"] !== undefined)
                        leftLoader.item.cancelPendingHide();
                    shown = true;
                    openT = 1;
                } else {
                    if (!shown)
                        return;
                    openT = 0;
                    leftCloseTimer.restart();
                }
            }
            Timer {
                id: leftCloseTimer
                interval: Theme.anim.normal
                onTriggered: leftPill.shown = false
            }
            IslandExpandClip {
                expand: leftPill.openT
                contentHeight: leftPill.height
                anchors.top: parent.top
                Rectangle {
                    color: Theme.surface
                    width: parent.width
                    height: leftPill.height
                    bottomRightRadius: Theme.radius
                    bottomLeftRadius: Theme.radius
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
            }
        }

        // ---- right side pill (independent of the main pill) ----
        Item {
            id: rightPill
            // Docked to the right screen edge, outermost; the main pill
            // and recording yield. Transparent shell — background lives
            // inside the unfold clip, like leftPill.
            x: parent.width - width - 8
            y: Settings.barOrientation ? 0 : parent.height - height
            width: Settings.rightPanelWidth
            height: Math.max(400, root.screenHeight - 15)
            visible: rightPill.shown && root.barVisible
            property bool primed: false
            // Open/close transition, same pattern as leftPill above.
            property bool shown: false
            property bool flag: BarState.rightOpen
            onFlagChanged: rightPill.setShown(rightPill.flag)
            Component.onCompleted: rightPill.setShown(rightPill.flag)
            property real openT: 0
            function setShown(open) {
                if (open) {
                    rightCloseTimer.stop();
                    if (!primed)
                        primed = true;
                    else if (rightLoader.item && rightLoader.item["cancelPendingHide"] !== undefined)
                        rightLoader.item.cancelPendingHide();
                    shown = true;
                    openT = 1;
                } else {
                    if (!shown)
                        return;
                    openT = 0;
                    rightCloseTimer.restart();
                }
            }
            Timer {
                id: rightCloseTimer
                interval: Theme.anim.normal
                onTriggered: rightPill.shown = false
            }
            IslandExpandClip {
                expand: rightPill.openT
                contentHeight: rightPill.height
                anchors.top: parent.top
                Rectangle {
                    color: Theme.surface
                    width: parent.width
                    height: rightPill.height
                    bottomRightRadius: Theme.radius
                    bottomLeftRadius: Theme.radius
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
            }
        }

        // ---- secondary pill (recording) ----
        // Chained right of the main pill; the right pill sits outermost
        // after it. Owns the recording island so ScreenRecorder never
        // hijacks the main pill: visible only while recording, hidden
        // with the bar (fullscreen/conceal).
        Item {
            id: secondaryPill
            // Rigid chain right of the main pill (no Behavior — tracks
            // per-frame, coupled to the main pill's own motion).
            // Transparent shell — background wipes inside the clip.
            x: pill.x + pill.width + 8
            y: Settings.barOrientation ? 0 : parent.height - height
            height: root.barHeight
            width: secondaryLoader.item ? (secondaryLoader.item.implicitWidth + 10) : 190
            visible: secondaryPill.shown && root.barVisible
            // Open/close transition: the clip unfolds; the Loader
            // deactivates after the fold. Reopen mid-fold cancels the
            // hide. openT is discrete — the clip animates it internally.
            property bool shown: false
            property bool flag: ScreenRecorder.isRecording
            onFlagChanged: secondaryPill.setShown(secondaryPill.flag)
            Component.onCompleted: secondaryPill.setShown(secondaryPill.flag)
            property real openT: 0
            function setShown(open) {
                if (open) {
                    recCloseTimer.stop();
                    shown = true;
                    openT = 1;
                } else {
                    if (!shown)
                        return;
                    openT = 0;
                    recCloseTimer.restart();
                }
            }
            Timer {
                id: recCloseTimer
                interval: Theme.anim.normal
                onTriggered: secondaryPill.shown = false
            }

            IslandExpandClip {
                expand: secondaryPill.openT
                contentHeight: secondaryPill.height
                anchors.top: parent.top
                Item {
                    width: parent.width
                    height: secondaryPill.height
                    Loader {
                        id: secondaryLoader
                        anchors.centerIn: parent
                        active: secondaryPill.shown
                        sourceComponent: secondaryRecordingPage
                    }
                }
            }
            Component {
                id: secondaryRecordingPage
                RecordingIsland {}
            }
        }

        // ---- notification pill (centered below the main pill) ----
        // Owns the toast stack so popups never need a separate window.
        // Stays clickable/mapped on toasts alone: the window visible flag
        // below ORs barVisible with notifPill.hasContent.
        NotificationPopups {
            id: notifPill
            pillX: pill.x
            pillY: pill.y
            pillW: pill.width
            pillH: pill.height
            topBar: Settings.barOrientation
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

    // The toast pill maps on toasts alone so notifications survive a
    // concealed bar (the old separate window always did).
    visible: barVisible || notifPill.hasContent
}
