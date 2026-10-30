pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// System resources for the bar: one compiled Rust helper streams tagged JSON
// (SYS every 5s, BW every 3s), built by AutoCompiling from scripts/sysmonitor.rs.
QtObject {
    id: root

    property var systemResources: null
    property var bandwidth: [0, 0, 0, 0]

    property string binPath: ""

    property var loopProcObj: null
    property int resourceConsumers: 0

    // 2s backoff before restarting the loop: an immediate `running = true` on exit
    // spin-loops at 100% CPU when the binary is missing (exits 1 with no default route).
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

    // The loop also serves bandwidth, so it runs whenever the binary is ready; the
    // consumer count is bookkeeping for callers, not a lifecycle gate (idles at ~0%).
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
