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
import qs.widgets.weather

// Port of widgets/bar/Bar.tsx — the floating ArchEclipse bar pill.
PanelWindow {
    id: root

    // NOTE: `screen` is intentionally NOT redeclared here. `PanelWindow`
    // inherits `screen` from QsWindow; a `required property ShellScreen
    // screen` in this subtype would shadow it, so `screen: modelData`
    // (shell.qml) would bind the shadow and never reach the real window —
    // every variant's layer surface then defaults to the same output,
    // stacking all bars on one monitor (reported 2026-10-16/17).
    readonly property string monitorName: {
        const hmon = Hyprland.monitorFor(screen);
        if (hmon && hmon.name)
            return hmon.name;
        // fallback: try to get monitor name from screen
        return screen?.name ?? "unknown";
    }
    // Full monitor height for the side islands (they stretch the whole
    // vertical screen, like the old edge panels did). Must use logical
    // screen.height (DIPs) so fractional display scaling does not blow up
    // the height past the physical window and push panels off-screen.
    readonly property int screenHeight: {
        if (screen && screen.height > 0)
            return screen.height;
        const hmon = Hyprland.monitorFor(screen);
        if (hmon && hmon.height > 0) {
            const scale = (hmon.scale && hmon.scale > 0) ? hmon.scale : 1.0;
            return Math.round(hmon.height / scale);
        }
        return 1080;
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
    // (the control island stays OnDemand so typing elsewhere keeps working).
    // Bound to monitor-scoped search membership (not resolved state) so the grab
    // releases the same tick deactivate() runs — resolved state lags ~100ms
    // behind (debounceResolve), which kept Exclusive held while a freshly
    // launched app mapped, stealing its focus back to the bar.
    WlrLayershell.keyboardFocus: BarState.isOpenFor("search", root.monitorName) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusiveZone: Settings.barLock ? root.barHeight : -1
    // Toast breakthrough: while toasts are up the whole window jumps to
    // the Overlay layer (above fullscreen windows), then drops back to
    // Top when they clear. notifPill is declared below — QML resolves
    // the forward reference at component completion.
    WlrLayershell.layer: notifPill.hasContent ? WlrLayer.Overlay : WlrLayer.Top
    color: "transparent"
    aboveWindows: true

    // In-bar popovers that extend OUTSIDE the pill (tray overflow list). They
    // register their item here (Tray.qml) so the input mask below covers them;
    // otherwise every click on the popover falls through to the window behind.
    property var trayPopupItem: null

    // Click-through everywhere except the pills + edge hot-zones. The
    // window is a full-width, full-height transparent surface — without
    // a mask it eats every click outside the pills.
    mask: Region {
        item: pill
        // Workspace wave hang: while the strip is expanded its buttons hang
        // BELOW the (never-growing) pill, outside the pill's own region —
        // give the strip its own region so clicks land there. Nulled the
        // moment the wave is fully down so the full-height surface stays
        // click-through under the settled bar.
        Region {
            item: {
                var it = currentPageLoader.item;
                return (it && it.stripExpanded) ? it.waveHitbox : null;
            }
        }
        Region {
            item: root.trayPopupItem
        }
        // Regions track item geometry even when the item is hidden, so
        // null the item while its pill is closed — otherwise the
        // full-height surface eats clicks across the hidden pill's area.
        Region {
            item: leftPanelPill.visible ? leftPanelPill : null
        }
        Region {
            item: rightPanelPill.visible ? rightPanelPill : null
        }
        // The two side pills (weather left, media + recording right) are
        // their own entries — the main pill's Region above never covers them.
        Region {
            item: leftSidePill.visible ? leftSidePill : null
        }
        Region {
            item: rightSidePill.visible ? rightSidePill : null
        }
        Region {
            item: mediaPill.visible ? mediaPill : null
        }
        Region {
            item: osdPill.visible ? osdPill : null
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
        // Empty right-side hover zone (idle record-circle reveal): must
        // enter the input mask or the full-height surface passes the
        // pointer through and the HoverHandler never fires. The band is
        // pill-height, so the surface stays click-through above/below it.
        Region {
            item: recHotZone
        }
    }

    readonly property int barHeight: 28
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
        const localState = BarState.stateFor(root.monitorName);
        if (localState === "search" || localState === "control" || localState === "overview" || localState === "wallpaper" || BarState.isOpenFor("left", root.monitorName) || BarState.isOpenFor("right", root.monitorName))
            return true;
        const override = (BarState.barShown || {})[monitorName];
        if (override !== undefined)
            return override;
        BarState.hyprlandTick; // reap the reactive dependency
        return BarState.barVisibleFor(monitorName);
    }

    // Workspace wave hang (px) — reaches into the current DefaultBar page
    // when the strip is expanded; the pillClip extends by this so the
    // hanging buttons render below the still pill. 0 otherwise.
    readonly property real waveHang: {
        var it = currentPageLoader.item;
        return (it && it.stripExpanded && it.stripHang !== undefined) ? it.stripHang : 0;
    }

    // Animated variant of waveHang for pushing the pills that dock BELOW
    // the main pill (media OSD, volume/brightness OSD, notification
    // toasts) out from under the hanging buttons: they slide down and
    // back instead of jumping with the gate. Never written imperatively,
    // so the binding drives every change through the Behavior.
    property real waveHangPush: root.waveHang
    Behavior on waveHangPush {
        Anim {
            duration: Theme.anim.small
        }
    }

    // --- hover: expand on enter, collapse after leave delay (motion
    // controller on the bar pill; leave arms a 250ms timer that collapses
    // only if the pointer is still off AND no popup is open) ---
    // The workspace wave hang (buttons below the still pill) is outside
    // pillHover's geometry — chain the strip HoverHandler so hovering
    // a hanging button keeps the bar open.
    readonly property bool stripHovered: {
        var it = currentPageLoader.item;
        return it && it.stripHovered !== undefined ? it.stripHovered : false;
    }
    property bool hovered: pillHover.hovered || root.stripHovered
    // Documentation capture: expose the captured pill, not always the
    // main one — side-pill shots must frame the side pill (and image
    // inspection must walk its tree, not the bar strip's).
    readonly property var captureItem: BarState.isOpenFor("left", root.monitorName) && leftLoader.item ? leftLoader.item : (BarState.isOpenFor("right", root.monitorName) && rightLoader.item ? rightLoader.item : pill)
    function captureGeometry() {
        if (BarState.isOpenFor("left", root.monitorName))
            return root.sideCaptureGeometry(leftPanelPill, "left");
        if (BarState.isOpenFor("right", root.monitorName))
            return root.sideCaptureGeometry(rightPanelPill, "right");
        const p = pill.mapToItem(root.contentItem, 0, 0);
        return {
            visible: root.visible,
            displayed: stack.current,
            rect: {
                x: p.x,
                y: p.y,
                w: pill.width,
                h: pill.height
            }
        };
    }
    function sideCaptureGeometry(pillItem, name) {
        const g = pillItem.mapToItem(root.contentItem, 0, 0);
        return {
            visible: root.visible,
            displayed: name,
            rect: {
                x: g.x,
                y: g.y,
                w: pillItem.width,
                h: pillItem.height
            }
        };
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
            if (!root.hovered && BarState.popupCountFor(root.monitorName) <= 0 && !Settings.barDefault)
                BarState.deactivate("default");
            const localState = BarState.stateFor(root.monitorName);
            if (localState !== "search" && localState !== "control" && localState !== "overview" && localState !== "wallpaper" && !BarState.isOpenFor("left", root.monitorName) && !BarState.isOpenFor("right", root.monitorName) && !Settings.barLock && !root.hovered && BarState.popupCountFor(root.monitorName) <= 0)
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
            const localState = BarState.stateFor(root.monitorName);
            if (localState === "search" || localState === "control" || localState === "overview" || localState === "wallpaper" || BarState.isOpenFor("left", root.monitorName) || BarState.isOpenFor("right", root.monitorName)) {
                idleTimer.restart();
                return;
            }
            // Watchdog: don't trust the hover read alone (reveals
            // can fire without an enter/leave cycle). Ask Hyprland where the
            // cursor actually is; if it is over the bar band or a popup is
            // open, keep waiting. If position is unknown, DON'T conceal
            // blindly — restart the check.
            if (BarState.popupCountFor(root.monitorName) > 0) {
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
                if (!root.hovered && BarState.popupCountFor(root.monitorName) <= 0)
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
            var monW = (screen && screen.width > 0) ? screen.width : ((mon.width > 0 && mon.scale > 0) ? Math.round(mon.width / mon.scale) : mon.width);
            var monH = root.screenHeight;
            var monX = (mon.scale && mon.scale > 0) ? Math.round(mon.x / mon.scale) : mon.x;
            var monY = (mon.scale && mon.scale > 0) ? Math.round(mon.y / mon.scale) : mon.y;
            if (x < monX || x > monX + monW)
                return true;
            var onBar = Settings.barOrientation ? y <= monY + h : y >= monY + monH - h;
            return !onBar;
        } catch (e) {
            return undefined;
        }
    }

    Item {
        id: stripRoot
        anchors.fill: parent

        // ---- the pill ----
        Item {
            id: pill
            // Pushed-center: the island panels dock to the screen edges and
            // the side pills chain off the main pill (leftSidePill left,
            // rightSidePill right — recording-pill pattern) — the main pill
            // centers in the remaining space — never fixed-center,
            // never overlapping. `x` itself carries NO Behavior: it tracks
            // per-frame (rigidly coupled to width animations). Discrete
            // open/close pushes animate through leftPush/rightPush with the
            // same easing as the width, so everything moves as one unit.
            // TEST-ONLY: side pills (weather/media) don't push the main pill;
            // side panels still do.
            property real leftPush: (leftPanelPill.flag ? 8 + leftPanelPill.width + 8 : 0)
            Behavior on leftPush {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
            property real rightPush: (rightPanelPill.flag ? rightPanelPill.width + 8 : 0)
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
            height: pill.targetHeight
            // Height target as a property so the Behavior's enable gate below
            // has something to re-evaluate against (same reason targetWidth
            // exists for the width glide).
            readonly property real targetHeight: Math.max(root.barHeight, stack.height + stack.effPad * 2)
            // Shrink-only glide: when the target sits below the current
            // height (closes), ease down; when growing, track the unfolding
            // content rigidly per-frame — gliding there would chase a moving
            // target and lag behind it (verified via probe).
            Behavior on height {
                enabled: pill.height > pill.targetHeight
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
            // Glide for state swaps — but track rigidly while the default
            // bar's own content animates the width (the volume/brightness
            // slider reveal). That glide is already the motion, so easing
            // here would chase a target that moves every frame: a Behavior
            // retargeting per frame never catches up and the bar edge
            // trails the content (the trap the shrink-only height Behavior
            // above documents). Suspended via stack.rigidApplied.
            Behavior on width {
                enabled: pill.widthAnimReady && !stack.rigidApplied
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
            // Retry the suspension each frame: a request that arrives while
            // the pill is still catching up from an earlier glide must wait
            // for convergence, never snap the edge to the target.
            onWidthChanged: stack.syncRigid()
            onTargetWidthChanged: stack.syncRigid()
            // (Radii/color moved into PillBackground below: body + both
            // screen-edge flares must be ONE fill, never separate shapes.)

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
            property real targetWidth: Math.max(stack.width + stack.effPad * 2, 100)
            // Single-fill background: body + both screen-edge flares in
            // one path/fill — separate shapes either hairline (abutted)
            // or double-blend (overlapped, surface is translucent).
            PillBackground {
                id: pillBg
                bodyWidth: pill.width
                bodyHeight: pill.height
                topBar: Settings.barOrientation
                x: -flare
            }
            // Content clip (previously clip:true on the pill Rectangle):
            // cuts content spilling past the still-gliding pill edge. The
            // background above intentionally overhangs for the flares.
            // Height extends by the workspace-wave hang while the strip is
            // expanded: the wave buttons live BELOW the never-growing pill
            // (intentionally outside it) and must not be clipped away —
            // but only then, so the clip stays tight for width glides.
            Item {
                id: pillClip
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: pill.height + root.waveHang
                clip: true

                // ---- state stack (one beat) ----
                // Content swaps the same frame the state resolves; the pill
                // width glides under it while the island unfolds — background
                // and content animate as one unit, like the side pills.
                Item {
                    id: stack
                    // Per-state outer inset: default rests tighter (4), all
                    // other islands use Theme.islandPad (8). Pill width/height
                    // above derive from this so the surround stays exact.
                    // volume/brightness/player/recording render DefaultBar in
                    // the main stack (their UI lives in the OSD/media
                    // floaters and the right side pill), so they keep the
                    // default inset —
                    // otherwise opening the OSD flips effPad 4->8 and the
                    // bar visibly grows.
                    property bool showsDefault: stack.current === "default" || stack.current === "volume" || stack.current === "brightness" || stack.current === "player" || stack.current === "recording" || stack.current === "network"
                    property int effPad: stack.showsDefault ? 4 : Theme.islandPad
                    // Docked to the bar edge (top for a top bar, bottom for a
                    // bottom bar) — never centered: centering lets content drift
                    // vertically while the pill height glides. Edge margin is
                    // effPad so the settled surround matches the pill
                    // sizing (stack + effPad * 2) exactly.
                    anchors.top: Settings.barOrientation ? parent.top : undefined
                    anchors.bottom: Settings.barOrientation ? undefined : parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: stack.effPad
                    anchors.bottomMargin: stack.effPad

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

                    // Latch: the heavy wallpaper island is created once (primed
                    // async at boot so the first open binds warm shared data)
                    // and then kept alive across closes — reopens only toggle
                    // visibility, so image decodes, aspect caches, scroll and
                    // tab state survive.
                    property bool wallpaperPrimed: true

                    // The state actually shown on this monitor.
                    // (A Connections-guarded variant was tried and removed: the
                    // binding updates before signal handlers run, so any
                    // s === displayed guard exits early forever and branch logic
                    // placed there silently never executes — root-caused via
                    // probe 2026-09-24. All swap logic lives in onCurrentChanged
                    // + bindings below.)
                    property string displayed: BarState.stateFor(root.monitorName)

                    // Requested by the default bar page while its inner content
                    // animates the pill's width (volume/brightness slider
                    // reveal). `rigidApplied` is what actually suspends the
                    // pill's glide, and only once the pill has converged on the
                    // target — suspending mid-glide would snap the edge instead
                    // of tracking it. Released on every state swap and when the
                    // page unloads, so an interrupted glide can't strand it.
                    property bool rigidWidth: false
                    property bool rigidApplied: false
                    function syncRigid() {
                        if (!stack.rigidWidth) {
                            stack.rigidApplied = false;
                            return;
                        }
                        if (!stack.rigidApplied && Math.abs(pill.width - pill.targetWidth) <= 1)
                            stack.rigidApplied = true;
                    }
                    onRigidWidthChanged: stack.syncRigid()

                    // The live item for a shown state (cached wallpaper via
                    // its Loader, transient islands via currentPageLoader).

                    property string current: stack.displayed
                    // Note: control resolves to controlPage; volume/brightness
                    // render in the bottom OSD pill (like player in the media
                    // pill) and recording in its side pill, so the main stack
                    // shows default content for those — no swap churn.
                    // (Recording maps to defaultPage for the same reason.)
                    onCurrentChanged: {
                        // Leaving default (or any swap) mid-slider-glide: the old
                        // page is about to be torn down, so the pill goes back to
                        // easing for the swap itself.
                        stack.rigidWidth = false;
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

                    // Wallpaper lives here permanently (async-cached): created at
                    // boot in the background, then visibility-toggled so decodes,
                    // aspect caches and scroll survive closes. Async so the boot
                    // prime never janks the first frame; visible toggles the
                    // already-built subtree (no paint cost hidden).
                    Loader {
                        id: wallpaperCacheLoader
                        active: stack.wallpaperPrimed
                        visible: stack.current === "wallpaper"
                        asynchronous: true
                        sourceComponent: wallpaperPage
                        onLoaded: {
                            if (item && item["monitorName"] !== undefined)
                                item.monitorName = root.monitorName;
                            // Boot prime builds hidden with expand 1 (island's
                            // own onCompleted unfolds); fold silently while hidden
                            // so the first open unfolds 0 -> 1 visibly.
                            if (stack.current !== "wallpaper" && item && item["expand"] !== undefined)
                                item.expand = 0;
                        }
                    }

                    Loader {
                        id: currentPageLoader
                        // Handles the small transient states only — left/right
                        // live in their own panels, recording in the right side pill,
                        // wallpaper in the cached Loader above (show an empty
                        // page here so the transient Loader never instantiates
                        // and destroys it on open/close).
                        sourceComponent: {
                            switch (stack.current) {
                            case "default":
                                return defaultPage;
                            case "volume":
                                // Volume lives in the bottom OSD pill beside
                                // the media pill — the main stack shows default
                                // content so pulses never hijack the bar.
                                return defaultPage;
                            case "brightness":
                                // Same as volume above.
                                return defaultPage;
                            case "recording":
                                // Recording lives in the right side pill beside
                                // the main pill — the main stack shows default
                                // content so the bar is never hijacked.
                                return defaultPage;
                            case "player":
                                // Player lives in the bottom media pill at the
                                // opposite screen edge — the main stack shows
                                // default content so the bar is never hijacked.
                                return defaultPage;
                            case "weather":
                                return weatherPage;
                            case "network":
                                // Network lives in the left side pill beside the
                                // main pill — the main stack shows default content
                                // so the bar is never hijacked (same as player).
                                return defaultPage;
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
                            // DefaultBar suspends the pill's width glide while its
                            // sliders animate their own (see stack.rigidWidth).
                            if (item && item["barStack"] !== undefined)
                                item.barStack = stack;
                        }
                    }

                    Component {
                        id: defaultPage
                        DefaultBar {
                            monitorName: root.monitorName
                        }
                    }
                    Component {
                        id: weatherPage
                        WeatherIsland {}
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
                        WallpaperIsland {
                            monitorName: root.monitorName
                            screen: root.screen
                        }
                    }
                    Component {
                        id: emptyPage
                        Item {}
                    }
                }
            } // pillClip
        }

        Component {
            id: leftPage
            LeftIsland {
                screenHeight: root.screenHeight
                monitorName: root.monitorName
                screen: root.screen
            }
        }
        Component {
            id: rightPage
            RightIsland {
                screenHeight: root.screenHeight
                monitorName: root.monitorName
            }
        }

        // ---- left side pill (independent of the main pill) ----
        // Owns the left island in a forever-alive cached Loader: created
        // lazily on first open, then visibility-toggled so tab/scroll/
        // chat/booru state survives closes.
        Item {
            id: leftPanelPill
            // Docked to the left screen edge, outermost; the main pill yields.
            // Transparent positioning shell — the surface background lives
            // inside the unfold clip below so the panel wipes as one unit.
            x: 8
            y: Settings.barOrientation ? 0 : parent.height - height
            width: Settings.panelWidthFor("left", root.monitorName)
            height: Math.max(400, root.screenHeight - 15)
            visible: leftPanelPill.shown && root.barVisible
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
            property bool flag: BarState.isOpenFor("left", root.monitorName)
            onFlagChanged: leftPanelPill.setShown(leftPanelPill.flag)
            Component.onCompleted: leftPanelPill.setShown(leftPanelPill.flag)
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
                // The fold waiting on this timer runs at the island's actual
                // clip duration (per islandAnimStyle/animScale) — any close
                // timer here uses the same mapping, so leftClip is the source.
                interval: leftClip.expandDuration
                onTriggered: leftPanelPill.shown = false
            }
            IslandExpandClip {
                id: leftClip
                expand: leftPanelPill.openT
                contentHeight: leftPanelPill.height
                // One fillet wider on each side so the edge fillets live
                // inside the unfold wipe (attached) instead of beside it.
                x: -Theme.radius
                width: leftPanelPill.width + Theme.radius * 2
                anchors.top: Settings.barOrientation ? parent.top : undefined
                anchors.bottom: Settings.barOrientation ? undefined : parent.bottom
                // Single-fill background (body + flares, one fill — see
                // pillBg above); content Loader sits over the body area.
                PillBackground {
                    id: pillBgL
                    bodyWidth: leftPanelPill.width
                    bodyHeight: leftPanelPill.height
                    topBar: Settings.barOrientation
                    // Outer (screen-side) flare shares the sidebar rail
                    // background so it reads as the rail's extension.
                    leftFlare: true
                    leftFlareColor: Theme.bg
                    x: 0
                    y: Settings.barOrientation ? 0 : leftClip.height - leftPanelPill.height
                }
                Loader {
                    id: leftLoader
                    x: pillBgL.flare
                    y: Settings.barOrientation ? 0 : leftClip.height - leftPanelPill.height
                    width: leftPanelPill.width
                    height: leftPanelPill.height
                    active: leftPanelPill.primed
                    visible: leftPanelPill.visible
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

        // ---- right side pill (independent of the main pill) ----
        Item {
            id: rightPanelPill
            // Docked to the right screen edge, outermost; the main pill
            // and recording yield. Transparent shell — background lives
            // inside the unfold clip, like leftPanelPill.
            x: parent.width - width - 8
            y: Settings.barOrientation ? 0 : parent.height - height
            width: Settings.panelWidthFor("right", root.monitorName)
            height: Math.max(400, root.screenHeight - 15)
            visible: rightPanelPill.shown && root.barVisible
            property bool primed: false
            // Open/close transition, same pattern as leftPanelPill above.
            property bool shown: false
            property bool flag: BarState.isOpenFor("right", root.monitorName)
            onFlagChanged: rightPanelPill.setShown(rightPanelPill.flag)
            Component.onCompleted: rightPanelPill.setShown(rightPanelPill.flag)
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
                interval: leftClip.expandDuration
                onTriggered: rightPanelPill.shown = false
            }
            IslandExpandClip {
                id: rightClip
                expand: rightPanelPill.openT
                contentHeight: rightPanelPill.height
                // One fillet wider on each side so the edge fillets live
                // inside the unfold wipe (attached) instead of beside it.
                x: -Theme.radius
                width: rightPanelPill.width + Theme.radius * 2
                anchors.top: Settings.barOrientation ? parent.top : undefined
                anchors.bottom: Settings.barOrientation ? undefined : parent.bottom
                // Single-fill background (body + flares, one fill — see
                // pillBg above); content Loader sits over the body area.
                PillBackground {
                    id: pillBgR
                    bodyWidth: rightPanelPill.width
                    bodyHeight: rightPanelPill.height
                    topBar: Settings.barOrientation
                    // Outer (screen-side) flare shares the sidebar rail
                    // background so it reads as the rail's extension.
                    rightFlare: true
                    rightFlareColor: Theme.bg
                    x: 0
                    y: Settings.barOrientation ? 0 : rightClip.height - rightPanelPill.height
                }
                Loader {
                    id: rightLoader
                    x: pillBgR.flare
                    y: Settings.barOrientation ? 0 : rightClip.height - rightPanelPill.height
                    width: rightPanelPill.width
                    height: rightPanelPill.height
                    active: rightPanelPill.primed
                    visible: rightPanelPill.visible
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

        // ---- left side pill (weather) ----
        // Transparent container chained LEFT of the main pill (recording-pill
        // pattern). Full-height shell on the main pill's own band with the
        // fills centered inside, so an 18px fill reads with an equal margin
        // above and below instead of hugging the bar's edge. Contents live in
        // one Row; every entry keeps its own surface — the container draws no
        // background. x tracks per-frame (no Behavior — rigidly coupled to the
        // main pill's own motion); the main pill yields via leftPush.
        Item {
            id: leftSidePill
            x: pill.x - width - Theme.sidePillMargin
            y: Settings.barOrientation ? Theme.sidePillMargin / 2 : parent.height - height - Theme.sidePillMargin / 2
            // grows (Behavior-free — the pill's own height Behavior drives it
            // per-frame) when a side pill unfolds, so the click-mask Region
            // tracks the expanded pill
            height: Math.max(root.barHeight, (root.barHeight - Theme.sidePillHeight) / 2 + weatherButton.height)
            width: leftSideContents.implicitWidth
            visible: root.barVisible
            Row {
                id: leftSideContents
                anchors.horizontalCenter: parent.horizontalCenter
                // pinned to the band edge so pill growth always extends away
                // from the screen edge (down for top bars, up for bottom bars)
                anchors.top: Settings.barOrientation ? parent.top : undefined
                anchors.bottom: Settings.barOrientation ? undefined : parent.bottom
                spacing: Theme.spacing
                WeatherButton {
                    id: weatherButton
                    // band-centered when compact (the inset keeps the pill's
                    // compact block centered in the barHeight band); grows
                    // off the band while the launcher island is open
                    anchors.top: Settings.barOrientation ? parent.top : undefined
                    anchors.bottom: Settings.barOrientation ? undefined : parent.bottom
                    anchors.topMargin: (root.barHeight - Theme.sidePillHeight) / 2
                    anchors.bottomMargin: (root.barHeight - Theme.sidePillHeight) / 2
                    monitorName: root.monitorName
                    expanded: BarState.isOpenFor("search", root.monitorName)
                }

                // network pulse — horizontal wipe piece: it appears on
                // network change (BarState "network", 3s hold re-armed by
                // the widget's own hover/click) and never touches the main
                // stack. The piece's width rides the wipe so the Row
                // reflows smoothly; reveal is right-pinned, growing
                // leftward (left side pills wipe right -> left).
                Item {
                    id: networkPiece
                    anchors.top: Settings.barOrientation ? parent.top : undefined
                    anchors.bottom: Settings.barOrientation ? undefined : parent.bottom
                    width: netClip.width
                    height: root.barHeight
                    visible: networkPiece.shown
                    readonly property real targetWidth: netLoader.item ? netLoader.item.implicitWidth : 140
                    property bool shown: false
                    property bool flag: BarState.isOpenFor("network", root.monitorName)
                    onFlagChanged: networkPiece.setShown(networkPiece.flag)
                    Component.onCompleted: networkPiece.setShown(networkPiece.flag)
                    property real openT: 0
                    function setShown(open) {
                        if (open) {
                            netCloseTimer.stop();
                            shown = true;
                            openT = 1;
                        } else {
                            if (!shown)
                                return;
                            openT = 0;
                            netCloseTimer.restart();
                        }
                    }
                    Timer {
                        id: netCloseTimer
                        interval: leftClip.expandDuration
                        onTriggered: networkPiece.shown = false
                    }
                    IslandExpandClip {
                        id: netClip
                        horizontal: true
                        fromLeft: false
                        expand: networkPiece.openT
                        contentWidth: networkPiece.targetWidth
                        anchors.right: parent.right
                        anchors.top: parent.top
                        Item {
                            width: networkPiece.targetWidth
                            height: networkPiece.height
                            anchors.right: parent.right
                            anchors.top: parent.top
                            Loader {
                                id: netLoader
                                anchors.centerIn: parent
                                active: networkPiece.shown
                                sourceComponent: networkPiecePage
                                onLoaded: {
                                    if (item && item["monitorName"] !== undefined)
                                        item.monitorName = root.monitorName;
                                }
                            }
                        }
                    }
                    Component {
                        id: networkPiecePage
                        NetworkWidget {}
                    }
                }
            }
        }

        // hover zone on the empty right side of the bar: hovering the dead
        // area right of the main pill reveals the record circle in the right
        // side pill. Suppressed while the right island panel is open — the
        // cursor dwells at the edge to open that panel and must not pop it.
        Item {
            id: recHotZone
            x: pill.x + pill.width
            y: pill.y
            width: parent.width - x
            height: pill.height
            HoverHandler {
                id: recHover
                enabled: !BarState.isOpenFor("right", root.monitorName)
            }
        }

        // ---- right side pill (media + recording) ----
        // Same contract as leftSidePill, chained right of the main pill; the
        // right island panel sits outermost after it. Left to right: the mini
        // media fill (hidden while no player has a title), then the recording
        // fill. Each is its own surface 8px apart; the container is
        // transparent and takes its width from the Row, so a content going
        // away pulls the container in by exactly its own width + the spacing,
        // and the main pill glides after it (rightPush Behavior).
        Item {
            id: rightSidePill
            // Rigid chain right of the main pill (no Behavior).
            x: pill.x + pill.width + Theme.sidePillMargin
            y: Settings.barOrientation ? Theme.sidePillMargin / 2 : parent.height - height - Theme.sidePillMargin / 2
            // grows per-frame (Behavior-free — media's own height Behavior
            // drives it) so the click-mask Region tracks the expanded pill
            height: Math.max(root.barHeight, mediaPiece.height)
            width: rightSideContents.implicitWidth
            // Read the contents' OWN inputs, never a child's `visible`:
            // Qt Quick propagates `visible = false` into every descendant
            // when the parent hides, so a parent binding on a child's
            // `visible` latches itself off permanently (measured: media
            // had a title, still reported visible=false for good).
            visible: root.barVisible && (mediaPiece.hasPlayable || recordingPiece.shown)
            Row {
                id: rightSideContents
                anchors.horizontalCenter: parent.horizontalCenter
                // pinned to the band edge (see leftSidePill) so pill growth
                // always extends away from the screen edge
                anchors.top: Settings.barOrientation ? parent.top : undefined
                anchors.bottom: Settings.barOrientation ? undefined : parent.bottom
                spacing: Theme.spacing

                // mini media status (app icon + play state + track title):
                // hover/click pulses the player island, middle-click toggles
                // playback (MediaPill owns both behaviours). Wiped left -> right
                // like the recording piece; the wrapper's width rides the clip
                // so the Row reflows smoothly on both edges.
                Item {
                    id: mediaPiece
                    anchors.top: Settings.barOrientation ? parent.top : undefined
                    anchors.bottom: Settings.barOrientation ? undefined : parent.bottom
                    width: mediaWipe.width
                    // covers the band and media's vertical growth
                    height: Math.max(root.barHeight, (root.barHeight - Theme.sidePillHeight) / 2 + sideMedia.height)
                    readonly property bool hasPlayable: sideMedia.hasPlayable
                    property bool shown: false
                    property bool flag: sideMedia.hasPlayable
                    onFlagChanged: mediaPiece.setShown(mediaPiece.flag)
                    Component.onCompleted: mediaPiece.setShown(mediaPiece.flag)
                    property real openT: 0
                    function setShown(open) {
                        if (open) {
                            mediaPieceCloseTimer.stop();
                            shown = true;
                            openT = 1;
                        } else {
                            if (!shown)
                                return;
                            openT = 0;
                            mediaPieceCloseTimer.restart();
                        }
                    }
                    Timer {
                        id: mediaPieceCloseTimer
                        interval: leftClip.expandDuration
                        onTriggered: mediaPiece.shown = false
                    }
                    IslandExpandClip {
                        id: mediaWipe
                        horizontal: true
                        fromLeft: true
                        expand: mediaPiece.openT
                        contentWidth: sideMedia.width
                        anchors.left: parent.left
                        anchors.top: parent.top
                        Item {
                            width: sideMedia.width
                            height: mediaPiece.height
                            anchors.left: parent.left
                            anchors.top: parent.top
                            MediaPill {
                                id: sideMedia
                                // band-centered when compact, grows off the
                                // band edge while the launcher island is open
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: Settings.barOrientation ? parent.top : undefined
                                anchors.bottom: Settings.barOrientation ? undefined : parent.bottom
                                anchors.topMargin: (root.barHeight - Theme.sidePillHeight) / 2
                                anchors.bottomMargin: (root.barHeight - Theme.sidePillHeight) / 2
                                monitorName: root.monitorName
                                expanded: BarState.isOpenFor("search", root.monitorName)
                            }
                        }
                    }
                }

                // recording status — horizontal wipe piece (right side pills
                // wipe left -> right): fixed-height body, the clip's width
                // animates (expand 1 -> 0 on close, hide after the wipe;
                // reopen mid-wipe cancels the hide) and the Row reflows on
                // the animated width so nothing jumps.
                Item {
                    id: recordingPiece
                    anchors.top: Settings.barOrientation ? parent.top : undefined
                    anchors.bottom: Settings.barOrientation ? undefined : parent.bottom
                    width: recWipeClip.width
                    height: root.barHeight
                    visible: recordingPiece.shown
                    readonly property real targetWidth: recLoader.item ? recLoader.item.implicitWidth : 190
                    // recording on THIS monitor, or the idle circle revealed
                    // by hovering the empty right zone
                    // `starting` pins the piece open through the ~2s pgrep
                    // lag after a start click — it must not fold away
                    // before wf-recorder is actually up.
                    readonly property bool recFlag: (ScreenRecorder.isRecording || ScreenRecorder.starting) && ScreenRecorder.targetMonitors.includes(root.monitorName)
                    property bool shown: false
                    property bool flag: recHover.hovered || recFlag
                    onFlagChanged: {
                        if (recordingPiece.flag) {
                            recCloseConfirm.stop();
                            recordingPiece.setShown(true);
                        } else {
                            // probes: recHover flaps while the pointer sits
                            // on the island (delivery churn, static zone) and
                            // each fold's openT wipe re-churns the re-eval —
                            // a self-sustain. Require the absence to persist
                            // before folding so one-frame flips are swallowed.
                            recCloseConfirm.restart();
                        }
                    }
                    Component.onCompleted: recordingPiece.setShown(recordingPiece.flag)
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
                        id: recCloseConfirm
                        // island-standard 1s leave grace: only a genuinely
                        // left pointer may fold the piece — any shorter hover
                        // stutter is swallowed and never touches the wipe
                        interval: 1000
                        onTriggered: if (!recordingPiece.flag)
                            recordingPiece.setShown(false)
                    }
                    Timer {
                        id: recCloseTimer
                        interval: leftClip.expandDuration
                        onTriggered: recordingPiece.shown = false
                    }
                    IslandExpandClip {
                        id: recWipeClip
                        horizontal: true
                        fromLeft: true
                        expand: recordingPiece.openT
                        contentWidth: recordingPiece.targetWidth
                        anchors.left: parent.left
                        anchors.top: parent.top
                        Item {
                            width: recordingPiece.targetWidth
                            height: recordingPiece.height
                            anchors.left: parent.left
                            anchors.top: parent.top
                            Loader {
                                id: recLoader
                                anchors.centerIn: parent
                                active: recordingPiece.shown
                                sourceComponent: recordingPage
                                onLoaded: {
                                    if (item && item["monitorName"] !== undefined)
                                        item.monitorName = root.monitorName;
                                }
                            }
                        }
                    }
                }

                // screenshot piece — same wipe-piece mechanics as the
                // recording piece, reveal parked on the empty right-zone
                // hover only (no persistent state to pin). Folds after the
                // island-standard 1s leave grace: hover-delivery flaps must
                // never start a wipe (each wipe re-churns the re-eval —
                // probe-proven self-sustain on the record piece).
                Item {
                    id: screenshotPiece
                    anchors.top: Settings.barOrientation ? parent.top : undefined
                    anchors.bottom: Settings.barOrientation ? undefined : parent.bottom
                    width: shotWipeClip.width
                    height: root.barHeight
                    visible: screenshotPiece.shown
                    readonly property real targetWidth: shotLoader.item ? shotLoader.item.implicitWidth : 190
                    property bool shown: false
                    property bool flag: recHover.hovered
                    onFlagChanged: {
                        if (screenshotPiece.flag) {
                            shotCloseConfirm.stop();
                            screenshotPiece.setShown(true);
                        } else {
                            // require the leave to persist (probe-proven
                            // transient flap must not start a wipe)
                            shotCloseConfirm.restart();
                        }
                    }
                    property real openT: 0
                    function setShown(open) {
                        if (open) {
                            shotCloseTimer.stop();
                            shown = true;
                            openT = 1;
                        } else {
                            if (!shown)
                                return;
                            openT = 0;
                            shotCloseTimer.restart();
                        }
                    }
                    Timer {
                        id: shotCloseConfirm
                        interval: 1000
                        onTriggered: if (!screenshotPiece.flag)
                            screenshotPiece.setShown(false)
                    }
                    Timer {
                        id: shotCloseTimer
                        interval: leftClip.expandDuration
                        onTriggered: screenshotPiece.shown = false
                    }
                    IslandExpandClip {
                        id: shotWipeClip
                        horizontal: true
                        fromLeft: true
                        expand: screenshotPiece.openT
                        contentWidth: screenshotPiece.targetWidth
                        anchors.left: parent.left
                        anchors.top: parent.top
                        Item {
                            width: screenshotPiece.targetWidth
                            height: screenshotPiece.height
                            anchors.left: parent.left
                            anchors.top: parent.top
                            Loader {
                                id: shotLoader
                                anchors.centerIn: parent
                                active: screenshotPiece.shown
                                sourceComponent: screenshotPage
                                onLoaded: {
                                    if (item && item["monitorName"] !== undefined)
                                        item.monitorName = root.monitorName;
                                }
                            }
                        }
                    }
                }
            }
            Component {
                id: recordingPage
                RecordingIsland {}
            }
            Component {
                id: screenshotPage
                ScreenshotIsland {}
            }
        }

        // ---- media pill (centered floater below the main pill) ----
        // Owns the PlayerIsland (full MediaWidget) so track-change pulses
        // never hijack the main pill: visible only while BarState resolves
        // "player" (2.5s pulse on track change / hover dwell / click, hover
        // pins via the island's own IslandHoverPin). Positioned like
        // NotificationPopups — centered under the main pill — and stacked
        // below toasts when both show. Hidden with the bar
        // (fullscreen/conceal). The island's own expand clip carries the
        // unfold; close folds first (expand 1 -> 0) and hides when the
        // fold completes. Reopen mid-fold retargets expand to 1.
        Item {
            id: mediaPill
            width: mediaLoader.item ? mediaLoader.item.implicitWidth : 408
            height: mediaLoader.item ? mediaLoader.item.implicitHeight : 0
            // Centered under the main pill, clamped 8px inside the edges.
            // x tracks rigidly (no Behavior — coupled to width animations).
            x: Math.max(8, Math.min(parent.width - width - 8, pill.x + (pill.width - width) / 2))
            // Below the main pill like toasts; toasts stack underneath this
            // pill when both show (see the props pushed into notifPill).
            y: Settings.barOrientation ? pill.y + pill.height + 8 + root.waveHangPush : pill.y - height - 8
            visible: mediaPill.shown && root.barVisible
            property bool shown: false
            property bool flag: BarState.isOpenFor("player", root.monitorName)
            onFlagChanged: mediaPill.setShown(mediaPill.flag)
            Component.onCompleted: mediaPill.setShown(mediaPill.flag)
            function setShown(open) {
                if (open) {
                    mediaCloseTimer.stop();
                    if (!shown) {
                        // Fresh open: the Loader (re)creates PlayerIsland,
                        // whose own onCompleted unfolds expand 0 -> 1.
                        shown = true;
                    } else if (mediaLoader.item && mediaLoader.item["expand"] !== undefined) {
                        // Reopen mid-fold: cancel the fold and unfold again.
                        mediaLoader.item.expand = 1;
                    }
                } else {
                    if (!shown)
                        return;
                    // Fold first; the hide timer below unmaps when done.
                    if (mediaLoader.item && mediaLoader.item["expand"] !== undefined)
                        mediaLoader.item.expand = 0;
                    mediaCloseTimer.restart();
                }
            }
            Timer {
                id: mediaCloseTimer
                interval: leftClip.expandDuration
                onTriggered: mediaPill.shown = false
            }
            Loader {
                id: mediaLoader
                anchors.fill: parent
                active: mediaPill.shown
                asynchronous: false
                sourceComponent: mediaPlayerPage
                onLoaded: {
                    if (item && item["monitorName"] !== undefined)
                        item.monitorName = root.monitorName;
                }
            }
            Component {
                id: mediaPlayerPage
                PlayerIsland {}
            }
        }

        // ---- OSD pill (centered floater below the main pill) ----
        // Owns the OsdIsland (full VolumeSection collapsed until hovered,
        // or the brightness slider) so volume/brightness key pulses never
        // hijack the main pill: visible only while BarState resolves
        // "volume"/"brightness" (reveal-out pulse, hover pins via the
        // island's own IslandHoverPin). Positioned like the media pill —
        // centered under the main pill, docked below it when both show —
        // and stacked above toasts when all show. Hidden with the bar
        // (fullscreen/conceal). The island's own expand clip carries the
        // unfold; close folds first (expand 1 -> 0) and hides when the
        // fold completes. Reopen mid-fold retargets expand to 1.
        Item {
            id: osdPill
            width: osdLoader.item ? osdLoader.item.implicitWidth : 400
            height: osdLoader.item ? osdLoader.item.implicitHeight : 0
            // Centered under the main pill, clamped 8px inside the edges.
            // x tracks rigidly (no Behavior — coupled to width animations).
            x: Math.max(8, Math.min(parent.width - width - 8, pill.x + (pill.width - width) / 2))
            // Below the main pill like toasts; below the media pill when
            // both show (see the props pushed into notifPill).
            y: Settings.barOrientation ? (mediaPill.visible ? mediaPill.y + mediaPill.height + 8 : pill.y + pill.height + 8) + root.waveHangPush : (mediaPill.visible ? mediaPill.y - height - 8 : pill.y - height - 8)
            visible: osdPill.shown && root.barVisible
            property bool shown: false
            // Membership, not resolved state: the resolved state holds one
            // island at a time, so a main-pill switch (search/control/…)
            // would unmap the OSD mid-pulse. Membership survives switches
            // (same reason the keyboard grab above reads monitor state) and
            // clears exactly when the hold timer, hover-leave, or Esc
            // deactivates the pulse.
            property bool flag: BarState.isOpenFor("volume", root.monitorName) || BarState.isOpenFor("brightness", root.monitorName)
            onFlagChanged: osdPill.setShown(osdPill.flag)
            Component.onCompleted: osdPill.setShown(osdPill.flag)
            function setShown(open) {
                if (open) {
                    osdCloseTimer.stop();
                    if (!shown) {
                        // Fresh open: the Loader (re)creates OsdIsland,
                        // whose own onCompleted unfolds expand 0 -> 1.
                        shown = true;
                    } else if (osdLoader.item && osdLoader.item["expand"] !== undefined) {
                        // Reopen mid-fold: cancel the fold and unfold again.
                        osdLoader.item.expand = 1;
                    }
                } else {
                    if (!shown)
                        return;
                    // Fold first; the hide timer below unmaps when done.
                    if (osdLoader.item && osdLoader.item["expand"] !== undefined)
                        osdLoader.item.expand = 0;
                    osdCloseTimer.restart();
                }
            }
            Timer {
                id: osdCloseTimer
                interval: leftClip.expandDuration
                onTriggered: osdPill.shown = false
            }
            Loader {
                id: osdLoader
                anchors.fill: parent
                active: osdPill.shown
                asynchronous: false
                sourceComponent: osdPage
                onLoaded: {
                    if (item && item["monitorName"] !== undefined)
                        item.monitorName = root.monitorName;
                }
            }
            Component {
                id: osdPage
                OsdIsland {}
            }
        }

        // ---- notification pill (centered below the main pill) ----
        // Tracks the main pill geometry (pillX/pillY/pillW/pillH) so
        // toasts move with it. Stays clickable/mapped on toasts alone:
        // the window visible flag below ORs barVisible with
        // notifPill.hasContent.
        NotificationPopups {
            id: notifPill
            monitorName: root.monitorName
            pillX: pill.x
            pillY: pill.y
            pillW: pill.width
            pillH: pill.height
            topBar: Settings.barOrientation
            mediaVisible: mediaPill.visible
            mediaY: mediaPill.y
            mediaH: mediaPill.height
            osdVisible: osdPill.visible
            osdY: osdPill.y
            osdH: osdPill.height
            waveHang: root.waveHangPush
        }

        // ---- hot zones (left/right island reveal strips) ----
        HotZone {
            id: leftHot
            side: "left"
            monitorName: root.monitorName
            size: Settings.leftPanelHotZoneSize
            enabled: Settings.leftPanelHotZone
            panelLock: Settings.panelLockFor("left", root.monitorName)
        }
        HotZone {
            id: rightHot
            side: "right"
            monitorName: root.monitorName
            size: Settings.rightPanelHotZoneSize
            enabled: Settings.rightPanelHotZone
            panelLock: Settings.panelLockFor("right", root.monitorName)
        }
    }

    // The toast pill maps on toasts alone so notifications survive a
    // concealed bar (the old separate window always did).
    visible: barVisible || notifPill.hasContent
}
