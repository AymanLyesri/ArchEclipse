import QtQuick
import Quickshell.Hyprland
import qs.theme
import qs.services

// Bottom workspace strip: 10 bars, 5px tall, stretched across the bar width.
// Empty = greyed out (muted, low opacity), occupied = full opacity.
// On genuine workspace switch, strip hover, or special-open the strip
// expands in height and reveals each workspace's app icon, then collapses
// back after peekDuration. Auto-expands are settle-gated so bar-island
// switches (which recreate this widget) never pop it open by themselves.
//
// The reveal is a wave: every button reveals independently, the focused one
// to full height and each ring further out to a progressively shorter travel
// (height), delayed by ring so the reveal rolls outward from focus and
// retracts inward. Buttons hang off the strip's FIXED top edge; each one's
// own animating height carries it downward, so a shorter button reads as
// having travelled less — and the pill's background never moves: the root
// item's implicitHeight stays collapsed for the Column while its actual
// height covers the wave hang below the pill (Bar.qml masks the hang for
// clicks while the wave is up).
//
// The special workspace sits in the middle (between 5 and 6): narrower
// than a normal slot and always accent-tinted so it stands out.
Item {
    id: root

    // Each Bar creates its own strip. Keep workspace focus, special-workspace
    // state, and client alerts tied to the monitor that owns this instance.
    property string monitorName: ""

    property int count: 10
    property real barHeight: 4
    property real iconSize: 11
    property real btnSpacing: 4
    // Horizontal inset of the strip Row within the widget: a little air
    // on the left and right so the end buttons don't flush against the
    // pill's straight edges.
    property real edgeMargin: 6
    property real hitHeight: 6
    // Gap between a slot's icon holder and its bar (Column spacing).
    property real iconSpacing: 2
    // --- wave reveal tuning ---
    // Every button reveals independently: the focused one gets the full
    // height and each ring out from it adds `waveStep` px, starting from a
    // floor that already fits icon + bar with `headroom` to spare (so the
    // shortest button never clips). `maxRings` caps the ramp, which keeps
    // the strip a stable height no matter where focus sits.
    property real headroom: 0
    property real waveStep: 4
    property real waveDelay: 50
    property int maxRings: 4
    property int peekDuration: 1000
    // Width of the special slot relative to a normal one.
    property real specialRatio: 0.55
    // Bottom edge of the never-growing pill, in strip coordinates:
    // strip top + collapsed strip + the stack's outer pad (effPad is 4 in
    // every state that renders this strip — see Bar.qml stack.showsDefault).
    // Button hang backgrounds must only paint BELOW this line: painting it
    // over the pill's own translucent surface double-blends darker.
    property real pillOuterPad: 4
    readonly property real pillFlush: root.hitHeight + root.pillOuterPad

    // --- derived wave geometry ---
    // Strip position of a normal slot: 1-5 are indices 0-4, then the
    // narrow special slot takes index 5, then 6-10 follow as 6-10.
    function slotIndex(wid) {
        return wid <= 5 ? wid - 1 : wid
    }
    // Index of the button the wave radiates from. A hovered button takes
    // priority (the wave peaks where the mouse is, tracked by the slots'
    // MouseAreas and reset by the strip's HoverHandler on leave); special
    // focus anchors on the special slot; focus outside the strip clamps
    // to the nearest edge so the nearest buttons still come out tallest.
    property int hoverAnchor: -1
    readonly property int focusIndex: {
        if (root.hoverAnchor >= 0)
            return root.hoverAnchor
        if (root.specialFocusedHere)
            return 5
        return Math.max(0, Math.min(root.count, root.slotIndex(root.focusedId)))
    }
    // Full height of a button's content (icon holder + gap + bar).
    readonly property real contentMin: root.iconSize + root.iconSpacing + root.barHeight
    // Shortest button: its own content plus `headroom`, so the ring that is
    // furthest from focus still never clips.
    readonly property real floorHeight: root.contentMin + root.headroom
    // Tallest button (ring 0, the focused one) — also the strip's own
    // expanded height, so the pill's bottom edge rests on it.
    readonly property real expandedHeight: root.floorHeight + root.waveStep * root.maxRings

    property bool expanded: false
    // Edge-latched hover peek: a HoverHandler fires hoveredChanged when a
    // fresh item appears under a stationary cursor — and every bar-island
    // switch recreates this widget — which would pop the strip open with
    // no real hover. Latching only genuine enter edges while settled
    // avoids that.
    property bool hoverPeek: false
    // Settle gate: ignore all auto-expand triggers for a beat after
    // creation so recreation/refresh transients can't pop the strip.
    property bool _ready: false
    // True while icons are revealed.
    readonly property bool showIcons: root.expanded || root.hoverPeek
    // Wave/alarm state for the window input mask + bar hover chaining
    // (Bar.qml). The hanging buttons live outside the pill rectangle, so
    // clicks there need their own mask region while any hang is up: either
    // the wave stepper or a blinking (new-client) button. `_hangHold`
    // keeps the window open one extra flight after the gate clears, so the
    // LAST collapsing tab (ring 0 — the longest) plays out its full 250ms
    // fold instead of being snapped away the instant waveIdx hits -1.
    readonly property bool hasBlinks: Object.keys(root.blinking).length > 0
    property bool _hangHold: false
    Timer {
        id: hangHoldTimer
        interval: 280
        onTriggered: root._hangHold = false
    }
    onHasBlinksChanged: {
        if (!root.hasBlinks) {
            root._hangHold = true;
            hangHoldTimer.restart();
        }
    }
    readonly property bool stripExpanded: root.waveIdx >= 0 || root.hasBlinks || root._hangHold
    readonly property bool stripHovered: stripHover.hovered
    // How far, in px, the wave buttons hang below the pill while expanded
    // (strip top is hitHeight above the pill's bottom edge): the clip in
    // Bar.qml extends by this while the wave is up.
    readonly property real stripHang: root.expandedHeight - root.hitHeight
    // The strip Row spans the full wave extent below the pill — the mask
    // region item for the hanging buttons (root itself is only 6px tall).
    readonly property Item waveHitbox: strip
    // Reveal progress of one button, 0 collapsed -> 1 at that button's own
    // target. Drives icon opacity so a button still waiting on its wave delay
    // is invisible rather than just short, and so the icon fades with its own
    // delayed collapse instead of popping out when the strip starts closing.
    function revealProgress(reveal, target) {
        return Math.max(0, Math.min(1, (reveal - root.hitHeight) / Math.max(1, target - root.hitHeight)))
    }

    // --- new-client blink: 3 blinks on unfocused workspaces ---
    // Tracks client counts per monitor and workspace; a count increase on a
    // non-focused workspace on this monitor arms 6 half-blinks (3 full cycles)
    // at 220ms cadence. Map wid -> remaining ticks; reassigned whole
    // so dependents re-evaluate (QML var-map pattern).
    property var _counts: ({})
    property bool _countsInit: false
    property var blinking: ({})
    property bool blinkPhase: true
    readonly property var clientCounts: {
        Hyprland.toplevels.values;
        const m = {};
        for (let i = 1; i <= root.count; i++)
            m[i] = 0;
        for (const t of Hyprland.toplevels.values) {
            if (t.monitor?.name !== root.monitorName)
                continue;
            const id = t.workspace?.id ?? -1;
            if (id >= 1 && id <= root.count)
                m[id]++;
        }
        return m;
    }
    onClientCountsChanged: {
        const cur = root.clientCounts;
        if (!root._countsInit) {
            root._counts = Object.assign({}, cur);
            root._countsInit = true;
            return;
        }
        const prev = root._counts;
        const nb = Object.assign({}, root.blinking);
        let touch = false;
        for (let i = 1; i <= root.count; i++) {
            const o = prev[i] ?? 0, n = cur[i] ?? 0;
            if (n > o && i !== root.focusedId) {
                // Any new client on an unfocused workspace rides its own
                // button alone (alerting clause in the reveal binding):
                // no strip-wide reveal ever, and no conflict if a wave is
                // already up — the alert simply overrides that button's
                // height until its ticks run out.
                nb[i] = 6;
                touch = true;
            } else if (i === root.focusedId && nb[i] !== undefined) {
                delete nb[i];
                touch = true;
            }
        }
        root._counts = Object.assign({}, cur);
        if (touch)
            root.blinking = nb;
    }
    Timer {
        id: blinkTimer
        interval: 220
        repeat: true
        running: Object.keys(root.blinking).length > 0
        onTriggered: {
            root.blinkPhase = !root.blinkPhase;
            const nb = {};
            for (const k in root.blinking) {
                const r = root.blinking[k] - 1;
                if (r > 0)
                    nb[k] = r;
            }
            root.blinking = nb;
        }
    }

    Timer {
        id: readyTimer
        interval: 400
        onTriggered: root._ready = true
    }
    Component.onCompleted: readyTimer.start()

    function requestExpand() {
        if (!root._ready)
            return;
        root.expanded = true;
        peekTimer.restart();
    }

    // --- wave stepper ---
    // The stagger lives here, not inside the slot animations: waveIdx
    // walks 0 -> maxRings while revealing and maxRings -> -1 while
    // hiding, one step per waveDelay. A button reveals when its ring is
    // <= waveIdx and hides when ring > waveIdx, so the wave rolls
    // outward from focus on the way up and sweeps inward (edges first)
    // on the way down — deterministically, on the restart of every step.
    property int waveIdx: -1
    Timer {
        id: waveTimer
        interval: root.waveDelay
        repeat: true
        running: false
        onTriggered: {
            if (root.showIcons && root.waveIdx < root.maxRings) {
                root.waveIdx++;
            } else if (!root.showIcons && root.waveIdx > -1) {
                root.waveIdx--;
            }
            const done = root.showIcons && root.waveIdx >= root.maxRings;
            const hiddenDone = !root.showIcons && root.waveIdx <= -1;
            if (done || hiddenDone)
                waveTimer.stop();
            // Wave fully retracted: clear the hover peak and hold the
            // clip window open one flight so the last tab finishes its
            // fold (see _hangHold).
            if (hiddenDone) {
                root.hoverAnchor = -1;
                root._hangHold = true;
                hangHoldTimer.restart();
            }
        }
    }
    onShowIconsChanged: {
        // Expanding from fully hidden: ring 0 (focused) shows right away,
        // then the stepper walks the rings. If mid-speed the target is
        // already underneath us, the timer simply keeps going from the
        // current index.
        if (root.showIcons) {
            if (root.waveIdx < 0)
                root.waveIdx = 0;
            waveTimer.restart();
        } else {
            waveTimer.restart();
        }
    }

    // Layout vs geometry split. The DefaultBar Column treats this root as
    // its collapsed strip (implicitHeight = hitHeight, and Column assigns
    // height from implicit since we set none) — so the pill and its
    // background NEVER change size for the wave. The full wave extent
    // lives on the `strip` Row below, which hangs BELOW the pill over the
    // transparent part of the window, each button travelling on its own
    // clock. The hang needs its own input-mask region: Bar.qml wires
    // workspaces.waveHitbox for that.
    implicitHeight: hitHeight

    readonly property var localMonitor: {
        Hyprland.monitors.values;
        if (!root.monitorName)
            return null;
        return Hyprland.monitors.values.find(m => m.name === root.monitorName) ?? null;
    }
    // activeWorkspace stays local even when the pointer focuses another
    // monitor. focusedWorkspace is only a fallback while Hyprland is still
    // resolving this monitor's active workspace during startup/hotplug.
    readonly property var localWorkspace: {
        const active = root.localMonitor?.activeWorkspace;
        if (active)
            return active;
        return Hyprland.focusedMonitor?.name === root.monitorName
            ? Hyprland.focusedWorkspace : null;
    }
    readonly property int focusedId: root.localWorkspace?.id ?? 1
    onFocusedIdChanged: {
        root.requestExpand();
        // A genuine switch re-peaks the wave at the new workspace, even
        // when the mouse is on its way out of the strip: clear the stale
        // hover anchor here (silent while collapsed; if tabs are in
        // flight it is a single coherent retarget, not the double
        // animation a leave-cleared anchor produced).
        root.hoverAnchor = -1;
        if (root.blinking[root.focusedId] !== undefined) {
            const nb = Object.assign({}, root.blinking);
            delete nb[root.focusedId];
            root.blinking = nb;
        }
    }
    Timer {
        id: peekTimer
        interval: root.peekDuration
        onTriggered: root.expanded = false
    }

    // per-workspace snapshot (reactive): [{id, occupied, icon}]
    readonly property var wsData: {
        Hyprland.toplevels.values;
        Hyprland.workspaces.values;
        const out = [];
        for (let i = 1; i <= root.count; i++) {
            const tops = Hyprland.toplevels.values.filter(t => (t.workspace?.id ?? -1) === i);
            out.push({
                id: i,
                occupied: tops.length > 0,
                icon: tops.length > 0 ? WorkspaceIcons.forToplevel(tops[0]) : WorkspaceIcons.emptyIcon
            });
        }
        return out;
    }

    // --- special workspace (reactive) ---
    readonly property var specialTops: {
        Hyprland.toplevels.values;
        Hyprland.workspaces.values;
        return Hyprland.toplevels.values.filter(t =>
            t.monitor?.name === root.monitorName && ((t.workspace?.name ?? "") + "").startsWith("special"));
    }
    readonly property var specialWs: {
        Hyprland.workspaces.values;
        const found = Hyprland.workspaces.values.find(w =>
            w.monitor?.name === root.monitorName && ((w.name ?? "") + "").startsWith("special"));
        return found ?? null;
    }
    readonly property bool specialOccupied: root.specialTops.length > 0
    readonly property bool specialActive: root.specialWs?.active ?? false
    // "Opened" = visible on this monitor. The focused-workspace and active-
    // toplevel fallbacks also stay monitor-scoped when the special workspace
    // object is absent while empty.
    readonly property bool specialFocusedHere: ((root.localWorkspace?.name ?? "") + "").startsWith("special")
    readonly property bool specialHasFocus: Hyprland.activeToplevel?.monitor?.name === root.monitorName
        && ((Hyprland.activeToplevel?.workspace?.name ?? "") + "").startsWith("special")
    readonly property bool specialOpen: root.specialActive || root.specialFocusedHere || root.specialHasFocus
    onSpecialOpenChanged: {
        // Peek the strip so the highlight + icon are actually seen.
        if (root.specialOpen)
            root.requestExpand();
    }
    readonly property string specialIconText: root.specialOccupied ? WorkspaceIcons.forToplevel(root.specialTops[0]) : WorkspaceIcons.specialIcon

    // Shared normal-slot delegate so left (1-5) and right (6-10) halves
    // stay identical.
    Component {
        id: wsSlot
        Item {
            id: slot
            required property var modelData
            readonly property int wid: modelData
            readonly property bool focused: root.focusedId === wid
            readonly property bool occupied: {
                const d = root.wsData[wid - 1];
                return d ? d.occupied : false;
            }
            readonly property bool alerting: root.blinking[slot.wid] !== undefined
            readonly property string iconText: {
                const d = root.wsData[wid - 1];
                return d ? d.icon : WorkspaceIcons.emptyIcon;
            }

            // Wave: ring distance from the focused button, and the height
            // this button reveals to. The focused one is tallest; every ring
            // out adds `waveStep`, capped at `maxRings`.
            readonly property int ring: Math.min(root.maxRings, Math.abs(root.slotIndex(slot.wid) - root.focusIndex))
            readonly property real targetH: root.expandedHeight - root.waveStep * slot.ring
            // Reveal driven by the wave stepper: this button is "revealed" once
            // waveIdx reaches its ring. The Behaviour animates only the
            // size change — the stagger itself comes from when the wave
            // stepper flips the target, so reveal and collapse order can
            // never invert the way a self-delayed PauseAnimation did.
            property real reveal: slot.alerting ? root.expandedHeight : ((slot.ring <= root.waveIdx) ? slot.targetH : root.hitHeight)
            Behavior on reveal {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }
            readonly property real revealT: root.revealProgress(slot.reveal, slot.targetH)

            width: strip.normalW
            height: strip.height

            // TOP-anchored and clipped: the button hangs off the strip's
            // fixed top edge and its own animating height carries it
            // downward — a shorter button travels less and stops sooner.
            // Gluing it to the strip's bottom edge instead made every
            // button ride the same moving edge (what read as "all buttons
            // reveal down at the same time").
            Item {
                id: revealBox
                width: slot.width
                height: slot.reveal
                anchors.top: parent.top
                clip: true

                // Per-button hang background — single-fill tab below the
                // pill (PillBackground.qml's rule: one fill, never paint
                // over an already-painted translucent region; that's what
                // double-blended darker at the intersection). Straight
                // top edge flush with the pill's bottom edge, rounded
                // bottom corners, same Theme.surface fill as the pill.
                // Collapsed is a no-op (height clamps to 0).
                Canvas {
                    // Canvas top must sit AT the flush line, not at the
                    // revealBox top (y=0): topMargin shifts the fill into
                    // the below-pill region so it never double-blends.
                    anchors.top: parent.top
                    anchors.topMargin: root.pillFlush
                    anchors.left: parent.left
                    width: slot.width
                    height: Math.max(0, slot.reveal - root.pillFlush)
                    property color fill: Theme.surface
                    onFillChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onVisibleChanged: {
                        if (visible)
                            requestPaint();
                    }
                    onPaint: {
                        const ctx = getContext("2d");
                        if (!ctx)
                            return;
                        const w = width;
                        const h = height;
                        const r = Math.min(Theme.radius, w / 2, h / 2);
                        if (w <= 0 || h <= 0)
                            return;
                        ctx.reset();
                        ctx.fillStyle = fill;
                        ctx.beginPath();
                        ctx.moveTo(0, 0);
                        ctx.lineTo(w, 0);
                        ctx.lineTo(w, h - r);
                        ctx.arc(w - r, h - r, r, 0, Math.PI / 2, false);
                        ctx.lineTo(r, h);
                        ctx.arc(r, h - r, r, Math.PI / 2, Math.PI, false);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                Column {
                    anchors.bottom: parent.bottom
                    spacing: root.iconSpacing

                // icon holder — the reveal box clips it while the wave runs.
                // An alerting button shows its icon even with the strip
                // collapsed (independent new-client hang): the blink tick
                // in the text opacity below drives the flicker.
                Item {
                    width: slot.width
                    height: (root.showIcons || slot.alerting) ? root.iconSize : 0

                    Text {
                        anchors.centerIn: parent
                        text: slot.iconText
                        color: slot.alerting ? Theme.accent : slot.focused ? Theme.accent : slot.occupied ? Theme.fg : Theme.muted
                        opacity: slot.revealT * (slot.alerting ? (root.blinkPhase ? 1.0 : 0.15) : ((slot.focused || slot.occupied) ? 1.0 : 0.35))
                        font.family: Theme.fontFamily
                        font.pixelSize: root.iconSize
                    }
                }

                Rectangle {
                    id: bar
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: slot.width
                    height: root.barHeight
                    radius: root.barHeight / 2
                    color: slot.alerting ? Theme.accent : slot.focused ? Theme.accent : slot.occupied ? Theme.fg : Theme.muted
                    opacity: slot.alerting ? (root.blinkPhase ? 1.0 : 0.15) : (slot.focused || slot.occupied) ? 1.0 : 0.35

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                    Behavior on width {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                }
            }

            MouseArea {
                // Click/hover only over the button's own revealed extent —
                // the strip item is always the full wave height (it hangs
                // below the pill over transparent surface), so the slot
                // bounds would swallow clicks on empty space. Hovering
                // re-anchors the wave's peak at this button; anchor clearing
                // lives on the strip's HoverHandler only (exiting into an
                // adjacent button must not flash the anchor back to focus).
                anchors.top: parent.top
                anchors.left: parent.left
                width: slot.width
                height: slot.reveal
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch(`hl.dsp.focus({workspace=${slot.wid}})`)
                onEntered: root.hoverAnchor = root.slotIndex(slot.wid)
            }
        }
    }

    Row {
        id: strip
        // Full wave extent anchored to the strip's top — the parent root
        // is only 6px tall (Column/positioner accounting), so this row
        // deliberately hangs BELOW the pill over the transparent surface.
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: root.edgeMargin
        anchors.right: parent.right
        anchors.rightMargin: root.edgeMargin
        height: root.expandedHeight
        spacing: root.btnSpacing

        HoverHandler {
            id: stripHover
            onHoveredChanged: {
                // Latch genuine enter edges only — a fresh item materializing
                // under a stationary cursor (bar island switch) must not peek.
                if (stripHover.hovered) {
                    if (root._ready)
                        root.hoverPeek = true;
                } else {
                    root.hoverPeek = false;
                    // Anchor stays put while the strip collapses (clearing
                    // here would retarget every button from the hover
                    // profile to the focus profile mid-flight, then again
                    // as the sweep passes — reads as lag). It is cleared
                    // when the wave finishes retracting (waveTimer
                    // hiddenDone), silently, once nothing is visible.
                }
            }
        }
        // 10 normal slots + 1 narrow special slot, 10 gaps total.
        readonly property real normalW: Math.max(0, (strip.width - root.btnSpacing * root.count) / (root.count + root.specialRatio))
        readonly property real specialW: strip.normalW * root.specialRatio

        Repeater {
            model: [1, 2, 3, 4, 5]
            delegate: wsSlot
        }

        // --- special workspace slot: middle, narrower, standout ---
        Item {
            id: specialSlot
            width: strip.specialW
            height: strip.height

            // Same wave as the normal slots: it sits at strip index 5, so
            // it radiates like any other button. Its bar is 1px taller, hence
            // the +1 on the target height.
            readonly property int ring: Math.min(root.maxRings, Math.abs(5 - root.focusIndex))
            readonly property real targetH: root.expandedHeight - root.waveStep * specialSlot.ring + 1
                        // Animated per button: rises to its own target on reveal, back to the
            // collapsed stop on hide.
            property real reveal: (specialSlot.ring <= root.waveIdx) ? specialSlot.targetH : root.hitHeight
            Behavior on reveal {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }
            readonly property real revealT: root.revealProgress(specialSlot.reveal, specialSlot.targetH)

            Item {
                id: specialRevealBox
                width: specialSlot.width
                height: specialSlot.reveal
                anchors.top: parent.top
                clip: true

                // Same single-fill hang tab as the normal slots.
                Canvas {
                    // Same flush offset as the normal-slot tab.
                    anchors.top: parent.top
                    anchors.topMargin: root.pillFlush
                    anchors.left: parent.left
                    width: specialSlot.width
                    height: Math.max(0, specialSlot.reveal - root.pillFlush)
                    property color fill: Theme.surface
                    onFillChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onVisibleChanged: {
                        if (visible)
                            requestPaint();
                    }
                    onPaint: {
                        const ctx = getContext("2d");
                        if (!ctx)
                            return;
                        const w = width;
                        const h = height;
                        const r = Math.min(Theme.radius, w / 2, h / 2);
                        if (w <= 0 || h <= 0)
                            return;
                        ctx.reset();
                        ctx.fillStyle = fill;
                        ctx.beginPath();
                        ctx.moveTo(0, 0);
                        ctx.lineTo(w, 0);
                        ctx.lineTo(w, h - r);
                        ctx.arc(w - r, h - r, r, 0, Math.PI / 2, false);
                        ctx.lineTo(r, h);
                        ctx.arc(r, h - r, r, Math.PI / 2, Math.PI, false);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                Column {
                    anchors.bottom: parent.bottom
                    spacing: root.iconSpacing

                Item {
                    width: specialSlot.width
                    height: root.showIcons ? root.iconSize + 2 : 0

                    Text {
                        anchors.centerIn: parent
                        text: root.specialIconText
                        color: Theme.accent
                        opacity: specialSlot.revealT * (root.specialOpen ? 1.0 : root.specialOccupied ? 0.9 : 0.55)
                        font.family: Theme.fontFamily
                        font.pixelSize: root.iconSize
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: specialSlot.width
                    // Slightly taller bar + accent border so it pops
                    // against the grey normal slots.
                    height: root.barHeight + 1
                    radius: (root.barHeight + 1) / 2
                    color: Theme.accent
                    opacity: root.specialOpen ? 1.0 : root.specialOccupied ? 0.8 : 0.45
                    border.color: Theme.accent
                    border.width: root.specialOpen ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                    Behavior on width {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                }
            }

            MouseArea {
                // Same rule as the normal slots: only the revealed extent.
                anchors.top: parent.top
                anchors.left: parent.left
                width: specialSlot.width
                height: specialSlot.reveal
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("hl.dsp.workspace.toggle_special()")
                onEntered: root.hoverAnchor = 5
            }
        }

        Repeater {
            model: [6, 7, 8, 9, 10]
            delegate: wsSlot
        }
    }
}
