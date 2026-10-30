import QtQuick
import Quickshell.Hyprland
import qs.theme
import qs.services

// Bottom workspace strip: 10 bars, 5px tall, across the bar width; a switch,
// hover or special-open expands it to show app icons (ring wave from focus).
Item {
    id: root

    // Each Bar creates its own strip. Keep workspace focus, special-workspace
    // state, and client alerts tied to the monitor that owns this instance.
    property string monitorName: ""

    property int count: 10
    property real barHeight: 3
    property real iconSize: 11
    property real btnSpacing: 4
    // Horizontal inset of the strip Row so the end buttons don't flush against
    // the pill's straight edges.
    property real edgeMargin: 6
    property real hitHeight: 6
    // Gap between a slot's icon holder and its bar (Column spacing).
    property real iconSpacing: 1
    // --- wave reveal tuning ---
    // Each ring out adds `waveStep` from a floor fitting icon + bar; `maxRings` caps the ramp.
    property real headroom: 0
    property real waveStep: 4
    property real waveDelay: 50
    property int maxRings: 6
    property int peekDuration: 1000
    // Width of the special slot relative to a normal one.
    property real specialRatio: 0.55
    // Bottom edge of the never-growing pill, in strip coordinates: hang
    // backgrounds must paint only below it or they double-blend darker.
    property real pillOuterPad: 4
    readonly property real pillFlush: root.hitHeight + root.pillOuterPad

    // --- derived wave geometry ---
    // Normal slots map 1-5 → 0-4, the narrow special takes 5, 6-10 follow as 6-10.
    function slotIndex(wid) {
        return wid <= 5 ? wid - 1 : wid;
    }
    // Button the wave radiates from: hover wins, then special focus, else the
    // nearest edge (slot MouseAreas track it, the strip HoverHandler clears it).
    property int hoverAnchor: -1
    readonly property int focusIndex: {
        if (root.hoverAnchor >= 0)
            return root.hoverAnchor;
        if (root.specialFocusedHere)
            return 5;
        return Math.max(0, Math.min(root.count, root.slotIndex(root.focusedId)));
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
    // Edge-latched hover peek: a HoverHandler fires on a fresh item under a still
    // cursor (every island switch recreates this widget) — only real edges count.
    property bool hoverPeek: false
    // Settle gate: ignore all auto-expand triggers for a beat after
    // creation so recreation/refresh transients can't pop the strip.
    property bool _ready: false
    // True while icons are revealed.
    readonly property bool showIcons: root.expanded || root.hoverPeek
    // Wave/alarm gate for the window input mask + bar hover chaining: hangs sit
    // outside the pill, so clicks need their own region; `_hangHold` outlives it.
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
    readonly property bool stripExpanded: root.waveIdx >= 0 || root.hasBlinks || root._hangHold || root.specialOpen
    readonly property bool stripHovered: stripHover.hovered
    // Px the buttons hang below the pill; Bar.qml extends the clip by this while
    // the wave is up.
    readonly property real stripHang: root.expandedHeight - root.hitHeight
    // The strip Row spans the full wave extent below the pill — the mask
    // region item for the hanging buttons (root itself is only 6px tall).
    readonly property Item waveHitbox: strip
    // 0 collapsed → 1 at this button's target; drives icon opacity so a waiting
    // button is invisible rather than short, and fades with its own collapse.
    function revealProgress(reveal, target) {
        return Math.max(0, Math.min(1, (reveal - root.hitHeight) / Math.max(1, target - root.hitHeight)));
    }

    // --- new-client blink: 3 blinks on unfocused workspaces ---
    // Count increase arms 6 half-blinks at 220ms; map wid → ticks, reassigned whole.
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
                // A new client on an unfocused workspace rides its own button
                // alone — no strip-wide reveal, no conflict with a running wave.
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
    // waveIdx (outermost revealed) and hideIdx walk one step per waveDelay; re-entry rewinds hideIdx.
    property int waveIdx: -1
    property int hideIdx: -1
    Timer {
        id: waveTimer
        interval: root.waveDelay
        repeat: true
        running: false
        onTriggered: {
            if (root.showIcons) {
                if (root.hideIdx >= 0)
                    root.hideIdx--;
                else if (root.waveIdx < root.maxRings)
                    root.waveIdx++;
            } else if (root.hideIdx < root.waveIdx) {
                root.hideIdx++;
            }
            const done = root.showIcons && root.waveIdx >= root.maxRings && root.hideIdx < 0;
            const hiddenDone = !root.showIcons && root.hideIdx >= root.waveIdx;
            if (done || hiddenDone)
                waveTimer.stop();
            // Fully retracted: clear the hover peak and hold the clip one more
            // flight so the last tab finishes its fold.
            if (hiddenDone) {
                root.waveIdx = -1;
                root.hideIdx = -1;
                root.hoverAnchor = -1;
                root._hangHold = true;
                hangHoldTimer.restart();
            }
        }
    }
    onShowIconsChanged: {
        // Ring 0 shows/folds first, then the stepper walks the rest; mid-speed it
        // keeps going from the current index.
        if (root.showIcons) {
            if (root.waveIdx < 0)
                root.waveIdx = 0;
        } else {
            root.hideIdx = 0;
        }
        waveTimer.restart();
    }

    // Layout vs geometry: the Column sees only the collapsed strip, so the pill
    // never resizes; the hang lives on `strip` below (Bar.qml wires waveHitbox).
    implicitHeight: hitHeight

    readonly property var localMonitor: {
        Hyprland.monitors.values;
        if (!root.monitorName)
            return null;
        return Hyprland.monitors.values.find(m => m.name === root.monitorName) ?? null;
    }
    // activeWorkspace stays local when the pointer focuses another monitor;
    // focusedWorkspace is only the startup/hotplug fallback.
    readonly property var localWorkspace: {
        const active = root.localMonitor?.activeWorkspace;
        if (active)
            return active;
        return Hyprland.focusedMonitor?.name === root.monitorName ? Hyprland.focusedWorkspace : null;
    }
    readonly property int focusedId: root.localWorkspace?.id ?? 1
    onFocusedIdChanged: {
        // Entering special is not a numbered switch: only the special tab hangs;
        // leaving it lands on a real workspace and peeks normally.
        if (!root.specialFocusedHere)
            root.requestExpand();
        // A real switch re-peaks the wave even while the mouse leaves: clearing
        // here is one coherent retarget, not the old double animation.
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
        return Hyprland.toplevels.values.filter(t => t.monitor?.name === root.monitorName && ((t.workspace?.name ?? "") + "").startsWith("special"));
    }
    readonly property var specialWs: {
        Hyprland.workspaces.values;
        const found = Hyprland.workspaces.values.find(w => w.monitor?.name === root.monitorName && ((w.name ?? "") + "").startsWith("special"));
        return found ?? null;
    }
    readonly property bool specialOccupied: root.specialTops.length > 0
    readonly property bool specialActive: root.specialWs?.active ?? false
    // "Opened" = visible on this monitor; the fallbacks stay monitor-scoped while
    // the special workspace object is absent.
    readonly property bool specialFocusedHere: ((root.localWorkspace?.name ?? "") + "").startsWith("special")
    readonly property bool specialHasFocus: Hyprland.activeToplevel?.monitor?.name === root.monitorName && ((Hyprland.activeToplevel?.workspace?.name ?? "") + "").startsWith("special")
    readonly property bool specialOpen: root.specialActive || root.specialFocusedHere || root.specialHasFocus
    onSpecialOpenChanged: {
        // Special toggling never peeks the wave; the tab hangs on its own. On
        // close, grab the one-flight hold so the fold plays under the clip.
        if (!root.specialOpen) {
            root._hangHold = true;
            hangHoldTimer.restart();
        }
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

            // Ring distance from the focus button; each ring out adds `waveStep`,
            // capped at `maxRings`.
            readonly property int ring: Math.min(root.maxRings, Math.abs(root.slotIndex(slot.wid) - root.focusIndex))
            readonly property real targetH: root.expandedHeight - root.waveStep * slot.ring
            // Stepper-driven: revealed at waveIdx, folded at hideIdx; only the size
            // change animates, so reveal/collapse order can never invert.
            property real reveal: slot.alerting ? slot.targetH : ((slot.ring <= root.waveIdx && slot.ring > root.hideIdx) ? slot.targetH : root.hitHeight)
            Behavior on reveal {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }
            readonly property real revealT: root.revealProgress(slot.reveal, slot.targetH)

            width: strip.normalW
            height: strip.height

            // TOP-anchored and clipped: the animating height carries the button
            // down; bottom-anchoring made every button ride the same edge.
            Item {
                id: revealBox
                width: slot.width
                height: slot.reveal
                anchors.top: parent.top
                clip: true

                // Single fill below the pill (never over a painted translucent
                // region — that double-blends): flush top, rounded bottom.
                Canvas {
                    // AT the flush line, not revealBox y=0: topMargin shifts the
                    // fill below the pill so it never double-blends.
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

                    // The reveal box clips the icon while the wave runs; an alerting
                    // button shows it even collapsed (the blink drives opacity).
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
                                duration: Theme.anim.defaultEffects
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.anim.defaultEffects
                            }
                        }
                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.anim.small
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }

            MouseArea {
                // Clicks/hover only over the revealed extent — the slot is the full
                // wave height and would swallow empty space; anchor clears on leave only.
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
        // Full wave extent from the strip's top: the root is only 6px tall, so
        // this row deliberately hangs below the pill.
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
                    // Anchor stays while collapsing (clearing retargets every button
                    // mid-flight, reads as lag); cleared silently on hiddenDone.
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

            // Same wave as the slots at index 5; its bar is 1px taller, hence +1.
            readonly property int ring: Math.min(root.maxRings, Math.abs(5 - root.focusIndex))
            readonly property real targetH: root.expandedHeight - root.waveStep * specialSlot.ring + 1
            readonly property bool open: root.specialOpen
            // Open special overrides the wave: this tab hangs alone, the rest stays
            // collapsed unless hover/switch unfolds it.
            property real reveal: specialSlot.open ? specialSlot.targetH : ((specialSlot.ring <= root.waveIdx && specialSlot.ring > root.hideIdx) ? specialSlot.targetH : root.hitHeight)
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
                        height: (root.showIcons || root.specialOpen) ? root.iconSize + 2 : 0

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
                        height: root.barHeight
                        radius: (root.barHeight + 1) / 2
                        color: Theme.accent
                        opacity: root.specialOpen ? 1.0 : root.specialOccupied ? 0.8 : 0.45
                        border.color: Theme.accent
                        border.width: root.specialOpen ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.anim.defaultEffects
                            }
                        }
                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.anim.small
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
