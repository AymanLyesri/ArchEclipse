pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// System resources for the bar's resource monitor.
// Reuses the exact loop binaries the AGS bar feeds on (no extra polling):
//   /tmp/ags-$USER/system-resources-loop-ags  -> JSON {cpuLoad, ramUsedGB, ramTotalGB, gpus:[{driver,load}]}
//   /tmp/ags-$USER/bandwidth-loop-ags         -> JSON [upPkts, downPkts, upBytes, downBytes]
QtObject {
    id: root

    property var systemResources: null
    property var bandwidth: [0, 0, 0, 0]

    property string tmpDir: `/tmp/ags-${Quickshell.env("USER")}`

    property Process resProc: Process {
        command: [`${root.tmpDir}/system-resources-loop-ags`]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try { root.systemResources = JSON.parse(data); }
                catch (e) { root.systemResources = null; }
            }
        }
        Component.onCompleted: running = true
        onExited: Qt.callLater(() => running = true)   // restart if the loop dies
    }

    property Process bwProc: Process {
        command: [`${root.tmpDir}/bandwidth-loop-ags`]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const p = JSON.parse(data);
                    const kb = v => Math.round((v / 1024) * 100) / 100;
                    root.bandwidth = [kb(p[0]), kb(p[1]), kb(p[2]), kb(p[3])];
                } catch (e) { root.bandwidth = [0, 0, 0, 0]; }
            }
        }
        Component.onCompleted: running = true
        onExited: Qt.callLater(() => running = true)
    }
}
