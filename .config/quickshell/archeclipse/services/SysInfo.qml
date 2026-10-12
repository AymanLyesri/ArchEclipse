pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// System resources for the bar's resource monitor.
// Two tiny compiled C helpers (no extra polling) stream JSON on stdout:
//   /tmp/quickshell-$USER/system-resources-loop  -> JSON {cpuLoad, ramUsedGB, ramTotalGB, gpus:[{driver,load}]}
//   /tmp/quickshell-$USER/bandwidth-loop         -> JSON [upPkts, downPkts, upBytes, downBytes]
// The binaries are compiled from the C sources in scripts/ at startup.
QtObject {
    id: root

    property var systemResources: null
    property var bandwidth: [0, 0, 0, 0]

    property string tmpDir: `/tmp/quickshell-${Quickshell.env("USER")}`
    property string scriptsDir: `${Quickshell.env("HOME")}/.config/quickshell/archeclipse/scripts`

    property var resProcObj: null
    property var bwProcObj: null
    property int resourceConsumers: 0
    property bool binariesReady: false

    // Compile both loop binaries. gcc is fast; unconditional compile is fine.
    // mkdir -p first: /tmp is wiped on every reboot, without it `ld` fails with
    // "cannot open output file" and the loops never start (retry would loop forever).
    property Process compileProc: Process {
        command: [
            "bash", "-c",
            "mkdir -p " + root.tmpDir
            + " && gcc -o " + root.tmpDir + "/system-resources-loop " + root.scriptsDir + "/system-resources-loop.c -lm"
            + " && gcc -o " + root.tmpDir + "/bandwidth-loop " + root.scriptsDir + "/bandwidth-loop.c -lm"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => console.log("[SysInfo] compile: " + data)
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => console.warn("[SysInfo] compile stderr: " + data)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                console.log("[SysInfo] loop binaries compiled");
                root.binariesReady = true;
                retryTimer.stop();
                startLoops();
            } else {
                console.warn("[SysInfo] compilation failed, exitCode=" + exitCode + " — retrying");
                // Retry after a delay (handles source missing, gcc missing, etc.)
                if (!retryTimer.running)
                    retryTimer.start();
            }
        }
    }

    property Timer retryTimer: Timer {
        interval: 10000
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            if (!compileProc.running)
                compileProc.running = true;
        }
    }

    // Backoff restarts for the loops: an immediate `running = true` on exit
    // spin-loops at 100% CPU when the binary is missing/crashing (e.g.
    // bandwidth-loop exits(1) with no default route). 2s delay + running
    // guard keeps one instance alive without hammering.
    property Timer resRestartTimer: Timer {
        interval: 2000
        repeat: false
        onTriggered: {
            if (root.resourceConsumers > 0 && root.resProcObj && !root.resProcObj.running)
                root.resProcObj.running = true;
        }
    }
    property Timer bwRestartTimer: Timer {
        interval: 2000
        repeat: false
        onTriggered: {
            if (root.bwProcObj && !root.bwProcObj.running)
                root.bwProcObj.running = true;
        }
    }

    function startLoops() {
        // Tear down previous instances + pending restarts so recompile
        // (or a manual retry) never leaves duplicate loop processes.
        resRestartTimer.stop();
        bwRestartTimer.stop();
        // system resources loop is only needed while a resource widget exists.
        if (root.resProcObj) root.resProcObj.destroy();
        root.resProcObj = null;
        if (root.resourceConsumers > 0)
            root.resProcObj = Qt.createQmlObject(`
            import Quickshell.Io; import QtQuick;
            Process {
                command: ["${root.tmpDir}/system-resources-loop"]
                stdout: SplitParser {
                    splitMarker: "\\n"
                    onRead: data => {
                        try { root.systemResources = JSON.parse(data); }
                        catch (e) { root.systemResources = null; }
                    }
                }
                stderr: SplitParser {
                    splitMarker: "\\n"
                    onRead: data => console.warn("[SysInfo] res-loop stderr: " + data)
                }
                onExited: (code, status) => {
                    console.warn("[SysInfo] res-loop exited code=" + code + " — restarting in 2s");
                    root.resRestartTimer.start();
                }
                Component.onCompleted: running = true
            }`, root);

        // bandwidth loop
        if (root.bwProcObj) root.bwProcObj.destroy();
        root.bwProcObj = Qt.createQmlObject(`
            import Quickshell.Io; import QtQuick;
            Process {
                command: ["${root.tmpDir}/bandwidth-loop"]
                stdout: SplitParser {
                    splitMarker: "\\n"
                    onRead: data => {
                        try {
                            const p = JSON.parse(data);
                            const kb = v => Math.round(v / 1024);
                            root.bandwidth = [kb(p[0]), kb(p[1]), kb(p[2]), kb(p[3])];
                        } catch (e) { root.bandwidth = [0, 0, 0, 0]; }
                    }
                }
                stderr: SplitParser {
                    splitMarker: "\\n"
                    onRead: data => console.warn("[SysInfo] bw-loop stderr: " + data)
                }
                onExited: (code, status) => {
                    console.warn("[SysInfo] bw-loop exited code=" + code + " — restarting in 2s");
                    root.bwRestartTimer.start();
                }
                Component.onCompleted: running = true
            }`, root);
    }

    function acquireResources() {
        root.resourceConsumers++;
        if (root.resourceConsumers === 1 && root.binariesReady)
            root.startLoops();
    }

    function releaseResources() {
        root.resourceConsumers = Math.max(0, root.resourceConsumers - 1);
        if (root.resourceConsumers === 0 && root.resProcObj) {
            root.resRestartTimer.stop();
            root.resProcObj.destroy();
            root.resProcObj = null;
            root.systemResources = null;
        }
    }

    Component.onCompleted: {
        compileProc.running = true;
    }
}