pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// System resources for the bar's resource monitor.
// One compiled Rust helper (no extra polling) streams tagged JSON on stdout:
//   SYS {...} -> {cpuLabel, cpuLoad, clockGHz, threads, cpuTempC,
//                 ramTotalGB, ramUsedGB, ramFreeGB, ramUsage,
//                 gpus:[{label, driver, load, memoryUsedGB, memoryTotalGB, tempC}],
//                 updatedAt}          (every 5s, first sample after 300ms)
//   BW  [...] -> [upBytes/s, downBytes/s, upBytesToday, downBytesToday]
//                                        (every 3s, first sample after one interval)
// The binary is built by the AutoCompiling singleton from scripts/sysmonitor.rs.
QtObject {
    id: root

    property var systemResources: null
    property var bandwidth: [0, 0, 0, 0]

    property string binPath: ""

    property var loopProcObj: null
    property int resourceConsumers: 0

    // Backoff restart for the loop: an immediate `running = true` on exit
    // spin-loops at 100% CPU when the binary is missing/crashing (e.g.
    // sysmonitor exits(1) with no default route). 2s delay + running
    // guard keeps one instance alive without hammering.
    property Timer loopRestartTimer: Timer {
        interval: 2000
        repeat: false
        onTriggered: {
            if (root.loopProcObj && !root.loopProcObj.running)
                root.loopProcObj.running = true;
        }
    }

    function startLoop() {
        // Tear down the previous instance + pending restart so recompile
        // (or a manual retry) never leaves duplicate loop processes.
        loopRestartTimer.stop();

        // bandwidth loop
        if (root.loopProcObj) root.loopProcObj.destroy();
        root.loopProcObj = null;
        root.loopProcObj = Qt.createQmlObject(`
            import Quickshell.Io; import QtQuick;
            Process {
                command: ["${root.binPath}"]
                stdout: SplitParser {
                    splitMarker: "\\n"
                    onRead: data => {
                        if (data.startsWith("SYS ")) {
                            // keep the last good sample on a bad line (no flicker)
                            try { root.systemResources = JSON.parse(data.slice(4)); }
                            catch (e) {}
                        } else if (data.startsWith("BW ")) {
                            try {
                                const p = JSON.parse(data.slice(3));
                                const kb = v => Math.round(v / 1024);
                                root.bandwidth = [kb(p[0]), kb(p[1]), kb(p[2]), kb(p[3])];
                            } catch (e) { root.bandwidth = [0, 0, 0, 0]; }
                        }
                    }
                }
                stderr: SplitParser {
                    splitMarker: "\\n"
                    onRead: data => console.warn("[SysInfo] sysmonitor stderr: " + data)
                }
                onExited: (code, status) => {
                    console.warn("[SysInfo] sysmonitor exited code=" + code + " — restarting in 2s");
                    root.loopRestartTimer.start();
                }
                Component.onCompleted: running = true
            }`, root);
    }

    // The loop serves bandwidth (always visible in the bar) as well as
    // on-demand resource views, so it runs whenever the binary is ready —
    // the consumer count below is bookkeeping for callers, not a
    // lifecycle gate (the loop idles at ~0% CPU between samples anyway).
    function acquireResources() {
        root.resourceConsumers++;
        if (root.binPath && !root.loopProcObj)
            root.startLoop();
    }

    function releaseResources() {
        root.resourceConsumers = Math.max(0, root.resourceConsumers - 1);
    }

    Component.onCompleted: {
        AutoCompiling.build(
            `${Quickshell.env("HOME")}/.config/quickshell/archeclipse/scripts/sysmonitor.rs`,
            "sysmonitor",
            p => {
                root.binPath = p;
                startLoop();
            });
    }
}
