import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme
import qs.services

// OverviewBody — end-4-style live workspace overview hosted by
// OverviewIsland in the main bar pill (BarState "overview").
//
// All 10 workspaces in a 5×2 grid of monitor-proportioned cards showing
// LIVE window thumbnails (ScreencopyView per toplevel, cf. end-4
// OverviewWindow.qml). Windows drag between cards (DropArea per card →
// `movetoworkspace`); click a window to focus it, middle-click to close
// it, click empty card space to focus that workspace.
//
// Geometry (`at`/`size`) does NOT come from `lastIpcObject` (stale unless
// `Hyprland.refreshToplevels()` is called — see HyprlandToplevel docs) but
// from a `hyprctl clients -j` poll keyed by address, like end-4's
// HyprlandData service. Toplevel add/remove stays reactive via
// `Hyprland.toplevels.values`; capture handles via `HyprlandToplevel.wayland`.
//
// Dispatches go through the Lua `hl.dsp.*` dispatchers (cf. Workspaces.qml)
// — this Hyprland is Luaified and plain `hyprctl dispatch` verbs are
// evaluated as Lua and fail to parse.
//
// Sticky island: nothing here deactivates "overview" — it closes only via
// the toggle or Esc (IslandEscClose in the island wrapper).
Item {
    id: body

    property string monitorName: ""
    readonly property string effectiveMonitor: body.monitorName || Registry.monitorName

    // ---- monitor geometry (card scale derives from it) ----
    readonly property var mon: {
        Hyprland.monitors.values;
        const found = Hyprland.monitors.values.find(m => m.name === body.effectiveMonitor);
        return found ?? Hyprland.focusedMonitor ?? null;
    }
    readonly property int monId: body.mon?.id ?? 0
    readonly property real monX: body.mon?.x ?? 0
    readonly property real monY: body.mon?.y ?? 0
    readonly property real monW: (body.mon?.width ?? 0) > 0 ? body.mon.width : 1920
    readonly property real monH: (body.mon?.height ?? 0) > 0 ? body.mon.height : 1080

    // ---- grid: all 10 workspaces, 5 columns × dynamic rows ----
    readonly property int cols: 5
    readonly property int rows: Math.ceil(10 / body.cols)
    readonly property int focusedId: Hyprland.focusedWorkspace?.id ?? 1

    // ---- card metrics (island is 920 wide; see OverviewIsland) ----
    readonly property real gap: 10
    // Grid spans the full body width (no body padding — the island owns
    // all margins); cards split it evenly.
    readonly property real cardW: (body.width - body.gap * (body.cols - 1)) / body.cols
    readonly property real cardH: body.cardW * body.monH / body.monW
    readonly property real scale: body.cardW / body.monW
    // Dynamic height: derived from the computed grid (leaves report
    // implicitHeight 0, so no implicit chain is possible here — but every
    // term below is itself reactive, no hardcoded px). Text DOES report a
    // real implicitHeight, so the empty-state line measures itself.
    readonly property real gridH: body.rows * body.cardH + (body.rows - 1) * body.gap

    width: 920
    implicitHeight: body.gridH + (emptyNote.visible ? contentCol.spacing + emptyNote.implicitHeight : 0)
    height: implicitHeight

    // ---- live geometry poll (`hyprctl clients -j`, keyed by address) ----
    // Keys are normalized (no `0x` prefix, lowercase): HyprlandToplevel
    // addresses come bare (`556a…`) while hyprctl reports `0x556a…`.
    function normAddr(a) {
        const s = (a ?? "") + "";
        const t = (s.startsWith("0x") || s.startsWith("0X")) ? s.slice(2) : s;
        return t.toLowerCase();
    }
    property var winGeo: ({})
    function refreshGeo() {
        geoProc.running = true;
    }
    property Process geoProc: Process {
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const arr = JSON.parse(text);
                    const m = {};
                    for (const c of arr)
                        m[body.normAddr(c.address)] = c;
                    body.winGeo = m;
                } catch (e) {}
            }
        }
    }
    Component.onCompleted: body.refreshGeo()
    // Slow poll while open (this body is transient — destroyed with the
    // island — so no leak after close).
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: body.refreshGeo()
    }

    // ---- window model: reactive toplevels joined with polled geometry ----
    readonly property var allWins: {
        Hyprland.toplevels.values;
        body.winGeo;
        const out = [];
        for (const t of Hyprland.toplevels.values) {
            const addr = t.address ?? "";
            if (addr === "")
                continue;
            const g = body.winGeo[body.normAddr(addr)] ?? null;
            if (!g)
                continue;
            const wsId = g.workspace?.id ?? -1;
            if (wsId < 1 || wsId > 10)
                continue;
            if ((g.monitor ?? -1) !== body.monId)
                continue;
            out.push({
                htop: t,
                wayland: t.wayland ?? null,
                addr: addr,
                title: g.title ?? t.title ?? "",
                cls: g.class ?? "",
                ws: wsId,
                x: g.at?.[0] ?? 0,
                y: g.at?.[1] ?? 0,
                w: g.size?.[0] ?? 0,
                h: g.size?.[1] ?? 0,
                floating: g.floating ?? false,
                fullscreen: (g.fullscreen ?? 0) !== 0
            });
        }
        return out;
    }

    // ---- drag state: the drop card is resolved GEOMETRICALLY from the
    // dragged tile's center at release (DropArea entered/exited fires, but
    // onDropped never arrives for internal drags and exit-before-release
    // races clear tracked state). DropAreas remain as hover highlight.
    // Which card (1-10) contains body-local point (px, py)? -1 = none.
    // Grid is uniform: content margins 16, then cards + gaps.
    function cardAt(px, py) {
        const gx = px - 16, gy = py - 16;
        const col = Math.floor(gx / (body.cardW + body.gap));
        const row = Math.floor(gy / (body.cardH + body.gap));
        if (col < 0 || col >= body.cols || row < 0 || row > 1)
            return -1;
        return row * body.cols + col + 1;
    }
    // Returns true when the window moved away (tile vanishes with it).
    function finishDrag(fromWs, addr, wrap) {
        let target = -1;
        try {
            const p = wrap.mapToItem(body, wrap.width / 2, wrap.height / 2);
            target = body.cardAt(p.x, p.y);
        } catch (e) {}
        if (target !== -1 && target !== fromWs) {
            body.moveWindow(fromWs, addr, target);
            return true;
        }
        wrap.snapBack();
        return false;
    }

    // ---- actions through the Lua dispatchers (hyprctl CLI wraps args as
    // `hl.dispatch(<args>)` evaluated as Lua, so `workspace 3` /
    // `focuswindow address:…` are syntax errors there — this Hyprland is
    // Luaified. The working reference is Workspaces.qml:
    // `hl.dsp.focus({workspace = N})`. Addresses are `0x`-prefixed like
    // hyprctl reports them (end-4 passes them through verbatim too).
    function dsp(expr) {
        Hyprland.dispatch(expr);
    }
    function focusWorkspace(id) {
        body.dsp(`hl.dsp.focus({workspace = ${id}})`);
        BarState.deactivate("overview");
    }
    function focusWindow(addr) {
        body.dsp(`hl.dsp.focus({window = "address:0x${body.normAddr(addr)}"})`);
    }
    function closeWindow(addr) {
        body.dsp(`hl.dsp.window.close({window = "address:0x${body.normAddr(addr)}"})`);
    }
    function moveWindow(fromWs, addr, targetWs) {
        if (targetWs === fromWs || targetWs < 1 || targetWs > 10)
            return;
        body.dsp(`hl.dsp.window.move({workspace = ${targetWs}, follow = false, window = "address:0x${body.normAddr(addr)}"})`);
    }

    Column {
        id: contentCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        // ===== workspace grid: 5 columns × 2 rows, all 10 =====
        GridLayout {
            width: parent.width
            columns: body.cols
            columnSpacing: body.gap
            rowSpacing: body.gap

            Repeater {
                model: 10
                delegate: Rectangle {
                    id: wsCard
                    required property int modelData
                    readonly property int wid: modelData + 1
                    readonly property bool isFocused: wsCard.wid === body.focusedId
                    property bool dropHot: false

                    Layout.preferredWidth: body.cardW
                    Layout.preferredHeight: body.cardH
                    // Explicit size (see AGENTS.md §2.3).
                    width: body.cardW
                    height: body.cardH
                    radius: Theme.cardRadius
                    color: wsCard.dropHot ? Theme.surfaceActive : Theme.surface
                    border.color: wsCard.dropHot ? Theme.accent : (wsCard.isFocused ? Theme.accent : Theme.border)
                    border.width: (wsCard.dropHot || wsCard.isFocused) ? 2 : 1

                    // Giant dim workspace number.
                    Text {
                        anchors.centerIn: parent
                        text: wsCard.wid
                        color: Theme.muted
                        opacity: 0.35
                        font.family: Theme.fontFamily
                        font.pixelSize: 40
                        font.bold: true
                    }

                    // Click empty space = focus workspace. Declared BEFORE
                    // the window tiles so they paint above and win their
                    // clicks; wheel-transparent for outer scrollers.
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        preventStealing: false
                        propagateComposedEvents: true
                        hoverEnabled: false
                        cursorShape: Qt.PointingHandCursor
                        onClicked: body.focusWorkspace(wsCard.wid)
                    }

                    // Live window tiles, absolutely positioned at scaled
                    // real geometry.
                    Repeater {
                        model: body.allWins.filter(w => w.ws === wsCard.wid)
                        delegate: Item {
                            id: winWrap
                            required property var modelData
                            readonly property var win: modelData

                            function gx() {
                                return Math.max(0, (winWrap.win.x - body.monX) * body.scale);
                            }
                            function gy() {
                                return Math.max(0, (winWrap.win.y - body.monY) * body.scale);
                            }
                            x: winWrap.gx()
                            y: winWrap.gy()
                            // Explicit size; floor keeps tiny windows grabbable.
                            width: Math.max(16, winWrap.win.w * body.scale)
                            height: Math.max(12, winWrap.win.h * body.scale)
                            z: 1 + (winWrap.win.floating ? 1 : 0) + (winWrap.win.fullscreen ? 2 : 0) + (tile.dragging ? 100 : 0)
                            function snapBack() {
                                winWrap.x = Qt.binding(function () {
                                    return winWrap.gx();
                                });
                                winWrap.y = Qt.binding(function () {
                                    return winWrap.gy();
                                });
                            }

                            OverviewPreview {
                                id: tile
                                property bool dragging: Drag.active
                                captureSrc: winWrap.win.wayland
                                iconText: WorkspaceIcons.forClientClass(winWrap.win.cls)
                                winTitle: winWrap.win.title
                                winAddr: winWrap.win.addr
                                wsId: wsCard.wid
                                host: body
                            }
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        onEntered: wsCard.dropHot = true
                        onExited: wsCard.dropHot = false
                        // Backup path (never observed to fire for internal
                        // drags, but harmless if it does).
                        onDropped: drop => {
                            wsCard.dropHot = false;
                            const src = drop.source;
                            if (src && src.winAddr)
                                body.moveWindow(src.wsId, src.winAddr, wsCard.wid);
                        }
                    }
                }
            }
        }

        Text {
            id: emptyNote
            visible: body.allWins.length === 0
            text: "No open windows on this monitor"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
    }
}
