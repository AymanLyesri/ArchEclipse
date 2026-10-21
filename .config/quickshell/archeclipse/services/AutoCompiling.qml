pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Gated rustc builder for single-file Rust helpers (scripts/*.rs, zero deps —
// no cargo manifest/target weight). Compiles into ~/.cache/quickshell/binaries/
// ONLY when the binary is missing or older than its source; a fresh build
// skips on every reload. Callers register with build(srcPath, binName, done);
// done(binPath) fires once the binary is ready (immediately if already built,
// after a 10s delay per failed attempt — handles rustc/source missing etc).
// One compile runs at a time; queued jobs are drained in order.
//
// A progress toast pops only for real compiles — the arm timer is canceled
// by a skip verdict, so a no-op rebuild never flashes a card.
// shortcut: progress converges toward 95% over an estimated duration — rustc
// emits no phase data for a single-file compile, so the bar is time-based,
// snapped to 100% on exit. Upgrade to real rustc -Z/--json progress if ever
// available stable.
QtObject {
    id: root

    property string binDir: `${Quickshell.env("HOME")}/.cache/quickshell/binaries`

    property var ready: ({})          // binName -> binPath, set once build succeeded
    property var durations: ({})      // binName -> ms of last successful compile

    property var _queue: []
    property var _current: null
    // shortcut: toasts are mutated via try/catch — a wrapper swiped away
    // mid-compile is destroyed and would throw on the next tick.
    function _setProgress(job, p) {
        try {
            job.w.progress = p;
            job.w.body = Math.round(p * 100) + "%";
        } catch (e) {
            job.w = null;
            ticker.stop();
        }
    }

    function build(srcPath, binName, done) {
        if (root.ready[binName] !== undefined) {
            done(root.ready[binName]);
            return;
        }
        root._queue.push({ src: srcPath, bin: binName, done: done });
        root._pump();
    }

    function _pump() {
        if (root._current || root._queue.length === 0)
            return;
        const job = root._current = root._queue.shift();
        job.skipped = false;
        job.w = null;
        compileProc.command = [
            "bash", "-c",
            "mkdir -p " + root.binDir
            + ' && if [ "' + root.binDir + '/' + job.bin + '" -nt "' + job.src + '" ]; then echo "' + job.bin + ' up to date, skipping compile";'
            + ' else rustc --edition=2021 -O -o "' + root.binDir + '/' + job.bin + '" "' + job.src + '"; fi'
        ];
        // Progress estimate: converge on 95% over the LAST measured compile
        // duration for this binary (3s fallback on first build). rustc emits
        // no phase data for a single file, so the bar is calibrated elapsed
        // time — after the first run it lands ~95% exactly when done.
        job.startC = Date.now();
        job.est = root.durations[job.bin] || 3000;
        toastArm.start();
        compileProc.running = true;
    }

    function _closeToast(job) {
        if (job.w) {
            Notifications.closeProgress(job.w);
            job.w = null;
        }
        ticker.stop();
    }

    function _armToast() {
        const job = root._current;
        if (!job || job.w || job.skipped)
            return;
        job.w = Notifications.progressToast("Compiling " + job.bin + ".rs");
        ticker.start();
    }

    property Timer toastArm: Timer {
        interval: 250
        repeat: false
        onTriggered: root._armToast()
    }

    // Bar driver: time-based convergence (see _pump note on calibration).
    property Timer ticker: Timer {
        interval: 150
        repeat: true
        onTriggered: {
            const job = root._current;
            if (!job || !job.w)
                return;
            const t = Date.now() - job.startC;
            root._setProgress(job, Math.min(0.95, 0.95 * (1 - Math.exp(-4 * t / job.est))));
        }
    }

    property Process compileProc: Process {
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                console.log("[AutoCompiling] " + data);
                const job = root._current;
                if (job && data.includes("up to date")) {
                    job.skipped = true;
                    toastArm.stop();
                    root._closeToast(job);
                }
            }
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => console.warn("[AutoCompiling] compile stderr: " + data)
        }
        onExited: (exitCode, exitStatus) => {
            const job = root._current;
            root._current = null;
            root._closeToast(job);
            if (exitCode === 0) {
                console.log("[AutoCompiling] " + job.bin + " binary ready");
                const binPath = root.binDir + "/" + job.bin;
                const nextReady = Object.assign({}, root.ready);
                nextReady[job.bin] = binPath;
                root.ready = nextReady;
                const nextDur = Object.assign({}, root.durations);
                nextDur[job.bin] = Math.max(100, Date.now() - job.startC);
                root.durations = nextDur;
                job.done(binPath);
                root._pump();
            } else {
                console.warn("[AutoCompiling] " + job.bin + " compilation failed, exitCode=" + exitCode + " — retrying");
                root._queue.push(job);
                retryTimer.start();
            }
        }
    }

    property Timer retryTimer: Timer {
        interval: 10000
        repeat: false
        onTriggered: root._pump()
    }
}
