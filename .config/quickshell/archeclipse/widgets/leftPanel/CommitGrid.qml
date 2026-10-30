import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.widgets.shared

// CommitGrid — 52×7 activity grid from the unauthenticated commit_activity endpoint; committed
// days take the accent at a count-scaled opacity. Disk-cached, refetched past 3h (no wedge).
Item {
    id: root

    // Defensive: hosts in collapsed/hidden layouts can hand out 0/negative
    // width; clamping avoids negative-dimension polish loops.
    property real widgetWidth: parent ? Math.max(0, parent.width) : 350
    width: Math.max(0, root.widgetWidth)

    readonly property int gap: 2
    readonly property int weeksTotal: 52
    readonly property int cellSize: Math.max(3, Math.floor((widgetWidth - root.gap * (root.weeksTotal - 1)) / root.weeksTotal))
    readonly property real step: root.cellSize + root.gap
    readonly property real gridWidth: root.weeksTotal * root.step - root.gap
    readonly property real gridHeight: 7 * root.cellSize + 6 * root.gap
    readonly property real monthH: 12
    readonly property int cacheTtlMs: 3 * 3600 * 1000

    property var counts: []      // flat ints, index = week*7 + day
    property var weekStarts: []  // 52 unix seconds
    readonly property int maxTotal: counts.reduce((a, b) => Math.max(a, b), 0)
    property bool loading: true
    property bool failed: false
    property int retries: 0

    // Explicit implicitHeight: embeds inside the GeneralTab Column positioner
    // read implicitHeight, never height (see GeneralTab header NOTE).
    implicitHeight: root.monthH + 4 + root.gridHeight + (root.weekStarts.length === 0 ? 8 + 18 : 0)

    // --- data ---
    // Parse + validate (self-check drops weeks whose days[] disagrees with total).
    function apply(text, fromNetwork) {
        let arr;
        try {
            arr = JSON.parse(text.trim());
        } catch (e) {
            return false;
        }
        if (!Array.isArray(arr) || arr.length === 0)
            return false;
        const cs = [], ws = [];
        let bad = 0;
        for (let i = 0; i < arr.length; i++) {
            const w = arr[i];
            if (!w || typeof w.week !== "number" || !Array.isArray(w.days) || w.days.length !== 7)
                continue;
            let sum = 0;
            for (let d = 0; d < 7; d++)
                sum += w.days[d];
            if (sum !== w.total) {
                bad++;
                continue;
            }
            ws.push(w.week);
            for (let d = 0; d < 7; d++)
                cs.push(w.days[d]);
        }
        if (bad > 0)
            console.warn("commit-grid: dropped", bad, "weeks where days[] disagreed with total");
        if (ws.length === 0)
            return false;
        if (fromNetwork) {
            try {
                cacheFile.setText(JSON.stringify({
                    ts: Date.now(),
                    raw: text.trim()
                }));
            } catch (e) {
                console.warn("commit-grid: cache write failed:", e);
            }
        }
        root.weekStarts = ws;
        root.counts = cs;
        root.loading = false;
        root.failed = false;
        return true;
    }

    // Blank days: faint neutral tint. Committed days: solid accent + ITEM opacity scaled by
    // count (sqrt-curved, floor 0.3) — alpha color strings misbehaved, so nothing relies on them.
    function cellOpacity(count) {
        if (count <= 0)
            return 0.15;
        return 0.3 + 0.7 * Math.sqrt(count / Math.max(1, root.maxTotal));
    }

    function tipFor(week, day) {
        const c = root.counts[week * 7 + day];
        const d = new Date((root.weekStarts[week] + day * 86400) * 1000);
        return c + (c === 1 ? " commit" : " commits") + " on " + Qt.formatDate(d, "ddd, MMM d");
    }

    // Month labels above the boundary weeks: the week whose Sunday starts in
    // one month and Saturday in the next holds the 1st of the new month.
    readonly property var monthLabels: {
        const out = [];
        const labelW = 26, minGap = root.step * 3;
        let lastX = -1e9, prevSatM = -1;
        for (let i = 0; i < root.weekStarts.length; i++) {
            const satM = new Date((root.weekStarts[i] + 6 * 86400) * 1000).getMonth();
            // (prevSat, sat] is exactly week i, so a Saturday-month jump means the 1st falls in
            // this week; no extra Sunday condition (it skipped 1st-on-a-Sunday months).
            if (i === 0) {
                prevSatM = satM;
                continue;
            }
            if (satM !== prevSatM) {
                const x = i * root.step;
                if (x - lastX >= minGap && x + labelW <= root.gridWidth) {
                    out.push({
                        x: Math.round(x),
                        text: Qt.formatDate(new Date((root.weekStarts[i] + 6 * 86400) * 1000), "MMM")
                    });
                    lastX = x;
                }
            }
            prevSatM = satM;
        }
        return out;
    }

    // --- cache (house pattern: WelcomeScreen FileView) ---
    FileView {
        id: cacheFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/activity/commits.json"
        watchChanges: false
        printErrors: false
        onLoaded: {
            let cached = null;
            try {
                cached = JSON.parse(text());
            } catch (e) {
                cached = null;
            }
            if (cached && typeof cached.raw === "string" && typeof cached.ts === "number") {
                root.apply(cached.raw, false);
                if (Date.now() - cached.ts < root.cacheTtlMs) {
                    root.retries = 0;
                    return;
                }
            }
            activityProc.running = true;
        }
        onLoadFailed: activityProc.running = true
    }

    // --- fetch (house pattern: starsProc; --max-time caps hung DNS/routes) ---
    Process {
        id: activityProc
        command: ["curl", "-sf", "--max-time", "4", "https://api.github.com/repos/AymanLyesri/ArchEclipse/stats/commit_activity"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.apply(text, true))
                    return;
                // HTTP 202 arrives as an empty array while GitHub (re)generates
                // stats — retry twice before declaring failure.
                root.retries++;
                if (root.retries <= 2) {
                    retryTimer.restart();
                } else {
                    console.warn("commit-grid: stats unavailable after retries");
                    root.failed = true;
                    root.loading = false;
                }
            }
        }
        onExited: code => {
            if (code !== 0 && root.weekStarts.length === 0) {
                console.warn("commit-grid: fetch failed (curl exited", code + ")");
                root.failed = true;
                root.loading = false;
            }
        }
    }

    Timer {
        id: retryTimer
        interval: 1500
        onTriggered: activityProc.running = true
    }

    // --- UI ---
    // Month strip
    Item {
        x: (root.width - root.gridWidth) / 2
        width: root.gridWidth
        height: root.monthH

        Repeater {
            model: root.monthLabels
            delegate: Text {
                x: modelData.x
                width: 26
                text: modelData.text
                font.pixelSize: Math.max(8, Theme.fontSize - 5)
                color: Theme.fgDim
            }
        }
    }

    // Cells
    Item {
        x: (root.width - root.gridWidth) / 2
        y: root.monthH + 4
        width: root.gridWidth
        height: root.gridHeight

        Repeater {
            model: root.counts
            delegate: Rectangle {
                required property int index
                readonly property int week: Math.floor(index / 7)
                readonly property int day: index - week * 7
                x: Math.round(week * root.step)
                y: day * root.step
                width: root.cellSize
                height: root.cellSize
                radius: Math.max(1, Math.round(root.cellSize / 5))
                color: root.counts[index] > 0 ? Theme.accent : Theme.mix(Theme.bg, Theme.fg, 0.12)
                opacity: root.cellOpacity(root.counts[index])
            }
        }

        // One hover handler for all 364 cells (no per-cell MouseAreas).
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onPositionChanged: mouse => {
                const w = Math.floor(mouse.x / root.step);
                const d = Math.floor(mouse.y / root.step);
                if (root.weekStarts.length !== 0 && w >= 0 && w < root.weekStarts.length && d >= 0 && d < 7) {
                    tip.text = root.tipFor(w, d);
                    tip.visible = true;
                } else {
                    tip.visible = false;
                }
            }
            onExited: tip.visible = false
        }

        AppTooltip {
            id: tip
            visible: false
        }
    }

    // Loading / failure notice
    Text {
        visible: root.weekStarts.length === 0
        y: root.monthH + 4 + root.gridHeight + 8
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.loading ? "loading activity…" : (root.failed ? "couldn't load activity" : "no activity yet")
        font.pixelSize: Math.max(9, Theme.fontSize - 3)
        color: Theme.fgDim
    }
}
