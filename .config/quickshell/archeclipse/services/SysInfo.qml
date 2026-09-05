pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// System resources for the bar's resource monitor.
// Reuses the exact loop binaries the AGS bar feeds on (no extra polling):
//   /tmp/ags-$USER/system-resources-loop-ags  -> JSON {cpuLoad, ramUsedGB, ramTotalGB, gpus:[{driver,load}]}
//   /tmp/ags-$USER/bandwidth-loop-ags         -> JSON [upPkts, downPkts, upBytes, downBytes]
// The binaries are compiled from the AGS C sources at startup so Quickshell
// works standalone (does not depend on AGS having been started first).
QtObject {
    id: root

    property var systemResources: null
    property var bandwidth: [0, 0, 0, 0]

    property string tmpDir: `/tmp/ags-${Quickshell.env("USER")}`
    property string scriptsDir: `${Quickshell.env("HOME")}/.config/ags/scripts`

    property var resProcObj: null
    property var bwProcObj: null

    // Compile both loop binaries. gcc is fast; unconditional compile is fine.
    // On success, start the loop processes.
    property Process compileProc: Process {
        command: [
            "bash", "-c",
            "gcc -o " + root.tmpDir + "/system-resources-loop-ags " + root.scriptsDir + "/system-resources-loop-ags.c -lm"
            + " && gcc -o " + root.tmpDir + "/bandwidth-loop-ags " + root.scriptsDir + "/bandwidth-loop-ags.c -lm"
        ]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                console.log("[SysInfo] loop binaries compiled");
                startLoops();
            } else {
                console.warn("[SysInfo] compilation failed, exitCode=" + exitCode);
                // Retry after a delay (handles source missing, gcc missing, etc.)
                retryTimer.start();
            }
        }
    }

    property Timer retryTimer: Timer {
        interval: 10000
        repeat: true
        onTriggered: compileProc.running = true;
    }

    function startLoops() {
        // system resources loop
        if (root.resProcObj) root.resProcObj.destroy();
        root.resProcObj = Qt.createQmlObject(`
            import Quickshell.Io; import QtQuick;
            Process {
                command: ["${root.tmpDir}/system-resources-loop-ags"]
                stdout: SplitParser {
                    splitMarker: "\\n"
                    onRead: data => {
                        try { root.systemResources = JSON.parse(data); }
                        catch (e) { root.systemResources = null; }
                    }
                }
                onExited: Qt.callLater(() => running = true)
                Component.onCompleted: running = true
            }`, root);

        // bandwidth loop
        if (root.bwProcObj) root.bwProcObj.destroy();
        root.bwProcObj = Qt.createQmlObject(`
            import Quickshell.Io; import QtQuick;
            Process {
                command: ["${root.tmpDir}/bandwidth-loop-ags"]
                stdout: SplitParser {
                    onRead: data => {
                        try {
                            const p = JSON.parse(data);
                            const kb = v => Math.round((v / 1024) * 100) / 100;
                            root.bandwidth = [kb(p[0]), kb(p[1]), kb(p[2]), kb(p[3])];
                        } catch (e) { root.bandwidth = [0, 0, 0, 0]; }
                    }
                }
                onExited: Qt.callLater(() => running = true)
                Component.onCompleted: running = true
            }`, root);
    }

    Component.onCompleted: {
        compileProc.running = true;
    }
}