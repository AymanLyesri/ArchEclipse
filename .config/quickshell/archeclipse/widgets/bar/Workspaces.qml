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
// The special workspace sits in the middle (between 5 and 6): narrower
// than a normal slot and always accent-tinted so it stands out.
Item {
    id: root

    property int count: 10
    property real barHeight: 4
    property real iconSize: 16
    property real btnSpacing: 4
    property real hitHeight: 6
    property real expandedHeight: 32
    property int peekDuration: 2000
    // Width of the special slot relative to a normal one.
    property real specialRatio: 0.55

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
    readonly property bool showIcons: root.expanded || root.hoverPeek

    // --- new-client blink: 3 blinks on unfocused workspaces ---
    // Tracks per-workspace client counts; a count increase on a
    // non-focused workspace arms 6 half-blinks (3 full on/off cycles)
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
                nb[i] = 6;
                touch = true;
                root.requestExpand();
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

    implicitHeight: showIcons ? expandedHeight : hitHeight
    Behavior on implicitHeight {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

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
            }
        }
    }

    readonly property int focusedId: Hyprland.focusedWorkspace?.id ?? 1
    onFocusedIdChanged: {
        root.requestExpand();
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
                icon: tops.length > 0 ? WorkspaceIcons.forClientClass(tops[0].lastIpcObject?.class ?? "") : WorkspaceIcons.emptyIcon
            });
        }
        return out;
    }

    // --- special workspace (reactive) ---
    readonly property var specialTops: {
        Hyprland.toplevels.values;
        Hyprland.workspaces.values;
        return Hyprland.toplevels.values.filter(t => ((t.workspace?.name ?? "") + "").startsWith("special"));
    }
    readonly property var specialWs: {
        Hyprland.workspaces.values;
        const found = Hyprland.workspaces.values.find(w => ((w.name ?? "") + "").startsWith("special"));
        return found ?? null;
    }
    readonly property bool specialOccupied: root.specialTops.length > 0
    readonly property bool specialActive: root.specialWs?.active ?? false
    // "Opened" = visible on screen. Focus moves into the special workspace
    // when it is toggled open, so the focused workspace (and the active
    // toplevel's workspace) is the most reliable reactive signal — the
    // workspace object itself can be missing while empty.
    readonly property bool specialFocusedHere: ((Hyprland.focusedWorkspace?.name ?? "") + "").startsWith("special")
    readonly property bool specialHasFocus: ((Hyprland.activeToplevel?.workspace?.name ?? "") + "").startsWith("special")
    readonly property bool specialOpen: root.specialActive || root.specialFocusedHere || root.specialHasFocus
    onSpecialOpenChanged: {
        // Peek the strip so the highlight + icon are actually seen.
        if (root.specialOpen)
            root.requestExpand();
    }
    readonly property string specialIconText: root.specialOccupied ? WorkspaceIcons.forClientClass(root.specialTops[0].lastIpcObject?.class ?? "") : WorkspaceIcons.specialIcon

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
            readonly property bool alerting: root.blinking[wid] !== undefined
            readonly property string iconText: {
                const d = root.wsData[wid - 1];
                return d ? d.icon : WorkspaceIcons.emptyIcon;
            }

            width: strip.normalW
            height: strip.height

            Column {
                anchors.centerIn: parent
                spacing: 2

                // icon holder — grows/collapses with the peek state
                Item {
                    width: slot.width
                    height: root.showIcons ? root.iconSize + 2 : 0
                    clip: true

                    Behavior on height {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: slot.iconText
                        color: slot.alerting ? Theme.accent : slot.focused ? Theme.accent : slot.occupied ? Theme.fg : Theme.muted
                        opacity: root.showIcons ? (slot.alerting ? (root.blinkPhase ? 1.0 : 0.15) : ((slot.focused || slot.occupied) ? 1.0 : 0.35)) : 0
                        font.family: Theme.fontFamily
                        font.pixelSize: root.iconSize

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }
                        }
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

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch(`hl.dsp.focus({workspace=${slot.wid}})`)
            }
        }
    }

    Row {
        id: strip
        anchors.fill: parent
        spacing: root.btnSpacing
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

            Column {
                anchors.centerIn: parent
                spacing: 2

                Item {
                    width: specialSlot.width
                    height: root.showIcons ? root.iconSize + 2 : 0
                    clip: true

                    Behavior on height {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.specialIconText
                        color: Theme.accent
                        opacity: root.showIcons ? (root.specialOpen ? 1.0 : root.specialOccupied ? 0.9 : 0.55) : 0
                        font.family: Theme.fontFamily
                        font.pixelSize: root.iconSize

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }
                        }
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

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("hl.dsp.workspace.toggle_special()")
            }
        }

        Repeater {
            model: [6, 7, 8, 9, 10]
            delegate: wsSlot
        }
    }
}
