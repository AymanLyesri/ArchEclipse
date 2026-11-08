import QtQuick
import Quickshell.Hyprland
import qs.theme
import qs.services
import qs.widgets.shared
import "../shared/PillPath.js" as PillPath

// Three nested metric strokes at each pill end, tracing the fill's flare -> side -> bottom
// corner; each fills from the top downward, so it reads as the silhouette, not a bar.
Item {
    id: root

    property int bodyWidth: 100
    property int bodyHeight: 28
    property int flare: Theme.radius
    property int corner: Theme.radius
    property bool topBar: true
    property string monitorName: ""

    // Outer -> inner = CPU, RAM, GPU (same order both ends). The stack must stay put: a band
    // may lose its fill, never its track, or the three would re-flow on every sample.
    property real strokeWidth: 6
    property real gap: 1.5
    property real edgeGap: 1.5
    property real tail: 4

    // Three bands need 2.5 widths of inset room before the corner radius; past that the inner
    // bands cross the corner and vanish, so the drawn width is capped, never the band count.
    readonly property real maxStrokeWidth: Math.max(0.5, Math.max(0, root.corner - root.edgeGap - 2 * root.gap) / 3)
    readonly property real drawStrokeWidth: Math.max(0.5, Math.min(root.strokeWidth, root.maxStrokeWidth))

    // Hit strip per end: covers the stroke footprint at each body end.
    readonly property real hitWidth: corner + tail + 4

    implicitWidth: bodyWidth + flare * 2
    implicitHeight: bodyHeight
    width: implicitWidth
    height: implicitHeight

    readonly property var res: SysInfo.systemResources
    // Parity with the cell this replaced; SysInfo's loop is unconditional, this is bookkeeping.
    Component.onCompleted: SysInfo.acquireResources()
    Component.onDestruction: SysInfo.releaseResources()

    // Missing sample / no GPU gives 0, never a dropped stroke: the stack would re-flow.
    property real cpuFrac: {
        const v = root.res ? root.res.cpuLoad : null;
        return (v === null || v === undefined) ? 0 : Math.max(0, Math.min(1, Number(v) / 100));
    }
    property real ramFrac: {
        const total = root.res ? Number(root.res.ramTotalGB) : 0;
        if (!(total > 0))
            return 0;
        return Math.max(0, Math.min(1, Number(root.res.ramUsedGB) / total));
    }
    property real gpuFrac: {
        const gpus = root.res && root.res.gpus ? root.res.gpus : [];
        let best = 0;
        let found = false;
        for (const g of gpus) {
            if (g.load === undefined || g.load === null)
                continue;
            found = true;
            best = Math.max(best, Number(g.load) / 100);
        }
        return found ? Math.max(0, Math.min(1, best)) : 0;
    }
    Behavior on cpuFrac {
        Anim {
            type: Anim.FastEffects
        }
    }
    Behavior on ramFrac {
        Anim {
            type: Anim.FastEffects
        }
    }
    Behavior on gpuFrac {
        Anim {
            type: Anim.FastEffects
        }
    }
    onCpuFracChanged: canvas.requestPaint()
    onRamFracChanged: canvas.requestPaint()
    onGpuFracChanged: canvas.requestPaint()

    readonly property string tipText: {
        const r = root.res;
        const cpu = r && r.cpuLoad !== undefined && r.cpuLoad !== null ? `CPU ${Number(r.cpuLoad).toFixed(1)}%` : "CPU N/A";
        const ram = r && Number(r.ramTotalGB) > 0 ? `RAM ${Math.round(root.ramFrac * 100)}% (${Number(r.ramUsedGB).toFixed(1)}/${Number(r.ramTotalGB).toFixed(1)} GB)` : "RAM N/A";
        const gpus = r && r.gpus ? r.gpus : [];
        const gpu = gpus.length ? gpus.map(g => `${g.driver || g.name || "GPU"}: ${g.load ?? "N/A"}%`).join(" | ") : "GPU N/A";
        return cpu + "<br>" + ram + "<br>" + gpu;
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        property color trackColor: Theme.track
        property color cpuColor: Theme.chart1
        property color ramColor: Theme.chart2
        property color gpuColor: Theme.chart3
        onTrackColorChanged: requestPaint()
        onCpuColorChanged: requestPaint()
        onRamColorChanged: requestPaint()
        onGpuColorChanged: requestPaint()
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
            const W = canvas.width;
            const H = canvas.height;
            const f = root.flare;
            const cr = root.corner;
            if (f <= 0 || cr <= 0 || W <= 0 || H <= 0)
                return;
            ctx.reset();
            ctx.clearRect(0, 0, W, H);
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            const fracs = [root.cpuFrac, root.ramFrac, root.gpuFrac];
            const colors = [canvas.cpuColor, canvas.ramColor, canvas.gpuColor];
            for (let k = 0; k < 3; k++) {
                const d = root.edgeGap + k * (root.drawStrokeWidth + root.gap) + root.drawStrokeWidth / 2;
                if (cr - d <= 0)
                    continue;
                for (let e = 0; e < 2; e++) {
                    const end = e === 0 ? "left" : "right";
                    PillPath.strokeEnd(ctx, end, root.topBar, W, H, f, cr, d, root.tail, c => {
                        c.lineWidth = root.drawStrokeWidth;
                        c.strokeStyle = canvas.trackColor;
                        c.stroke();
                    }, 1);
                    if (fracs[k] <= 0)
                        continue;
                    PillPath.strokeEnd(ctx, end, root.topBar, W, H, f, cr, d, root.tail, c => {
                        c.lineWidth = root.drawStrokeWidth;
                        c.strokeStyle = colors[k];
                        c.stroke();
                    }, fracs[k]);
                }
            }
        }
    }

    // Re-shown after an island state: a deferred hidden paint must not leave a stale buffer.
    onVisibleChanged: {
        if (visible)
            canvas.requestPaint();
    }
    onFlareChanged: canvas.requestPaint()
    onCornerChanged: canvas.requestPaint()
    onTopBarChanged: canvas.requestPaint()
    onStrokeWidthChanged: canvas.requestPaint()
    onGapChanged: canvas.requestPaint()
    onEdgeGapChanged: canvas.requestPaint()
    onTailChanged: canvas.requestPaint()

    // Dwell lives on the hit strips, never the pill: pillHover pins islands open.
    readonly property bool hovered: leftHit.containsMouse || rightHit.containsMouse
    onHoveredChanged: {
        if (root.hovered) {
            if (Settings.revealInPressure <= 0)
                BarState.activate("system", 3000, root.monitorName);
            else
                dwellTimer.restart();
        } else {
            dwellTimer.stop();
        }
    }
    Timer {
        id: dwellTimer
        interval: Math.max(0, Settings.revealInPressure)
        repeat: false
        onTriggered: BarState.activate("system", 3000, root.monitorName)
    }

    MouseArea {
        id: leftHit
        x: root.flare
        y: 0
        width: root.hitWidth
        height: root.bodyHeight
        hoverEnabled: true
        acceptedButtons: Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        // Plain `workspace` verbs are parsed as Lua here and silently fail.
        onClicked: Hyprland.dispatch("hl.dsp.focus({workspace = 5})")
        AppTooltip {
            visible: leftHit.containsMouse
            text: root.tipText
        }
    }

    MouseArea {
        id: rightHit
        x: root.flare + root.bodyWidth - root.hitWidth
        y: 0
        width: root.hitWidth
        height: root.bodyHeight
        hoverEnabled: true
        acceptedButtons: Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: Hyprland.dispatch("hl.dsp.focus({workspace = 5})")
        AppTooltip {
            visible: rightHit.containsMouse
            text: root.tipText
        }
    }
}
