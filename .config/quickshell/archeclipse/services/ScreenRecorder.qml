pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Port of services/record.service.ts — manages screen recording via wf-recorder
// and a user script. Polls for recording state.
QtObject {
    id: root

    property bool isRecording: false
    // The recorder is global, but its UI belongs to the monitor it captures.
    property string targetMonitor: ""
    property var targetMonitors: []
    property bool _startRequested: false
    property bool _startProcessFinished: true

    // Epoch ms when the current recording started (0 when not recording).
    // Elapsed is computed as Date.now() - start.
    property double startTimestamp: 0

    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/screenrecord.sh"
    readonly property string monitorFilePath: "/tmp/screenrecord_monitor"

    function setTargetMonitors(monitors) {
        const unique = [];
        for (const value of monitors || []) {
            const name = String(value || "").trim();
            if (name !== "" && !unique.includes(name))
                unique.push(name);
        }
        root.targetMonitors = unique;
        // Retain a singular compatibility target for notification routing.
        root.targetMonitor = unique.length > 0 ? unique[0] : "";
    }

    property Process _readMonitorProc: Process {
        command: ["cat", root.monitorFilePath]
        stdout: StdioCollector {
            onStreamFinished: {
                const monitors = text.split(/\r?\n/).map(name => name.trim()).filter(name => name !== "");
                if (monitors.length > 0 || !root._startRequested)
                    root.setTargetMonitors(monitors);
            }
        }
    }

    // Process for checking recording state
    property Process _checkRecProc: Process {
        command: ["pgrep", "-x", "wf-recorder"]
        stdout: StdioCollector {
            onStreamFinished: {
                const running = text.trim().length > 0;
                if (running !== root.isRecording) {
                    // Capture the start moment on the 0->1 edge.
                    if (running)
                        root.startTimestamp = Date.now();
                    else
                        root.startTimestamp = 0;
                    root.isRecording = running;
                }
                if (running) {
                    root._startRequested = false;
                    root._startProcessFinished = true;
                } else if (root._startRequested && root._startProcessFinished) {
                    root._startRequested = false;
                    root.setTargetMonitors([]);
                } else if (!root._startRequested) {
                    // A stale sidecar can survive an unclean process exit.
                    root.setTargetMonitors([]);
                }
            }
        }
    }

    // Stop recording process: the script now verifies the target PID,
    // falls back to pgrep, and exits non-zero with a message when there
    // is nothing to stop — surface that instead of failing silently.
    property Process _stopRecProc: Process {
        command: [root.scriptPath, "stop"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: code => {
            // Reconcile immediately so the island doesn't linger on the
            // poll interval; the periodic check corrects us if wrong.
            root._checkRecProc.running = true;
            if (!root._readMonitorProc.running)
                root._readMonitorProc.running = true;
            if (code !== 0) {
                const detail = ((_stopRecProc.stderr.text || "") + " " + (_stopRecProc.stdout.text || "")).trim();
                console.warn("[ScreenRecorder] Stop failed (" + code + "): " + detail);
                Notifications.send("ScreenRecord Error", detail || "Failed to stop screen recording.");
            }
        }
    }

    // Start recording process: the script exits non-zero when the user
    // cancels area selection or wf-recorder dies on startup — report it
    // (slurp-cancel stays silent, that is a deliberate no-op).
    property Process _startRecProc: Process {
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: code => {
            root._startProcessFinished = true;
            if (!root._readMonitorProc.running)
                root._readMonitorProc.running = true;
            root._settleTimer.restart();
            if (code !== 0) {
                const detail = ((_startRecProc.stderr.text || "") + " " + (_startRecProc.stdout.text || "")).trim();
                // Slurp cancel / dialog dismiss: no toast, just stay idle.
                if (detail !== "") {
                    console.warn("[ScreenRecorder] Start failed (" + code + "): " + detail);
                    Notifications.send("ScreenRecord Error", detail);
                }
            }
        }
    }

    // One-shot settle check after a start/stop so the bar island flips
    // without waiting for the next poll tick.
    property Timer _settleTimer: Timer {
        interval: 1200
        repeat: false
        onTriggered: {
            root._checkRecProc.running = true;
            if (!root._readMonitorProc.running)
                root._readMonitorProc.running = true;
        }
    }

    // Poll status and the sidecar even while idle: screenrecord.sh can be
    // started outside Quickshell (including its all-monitor mode).
    property Timer _pollTimer: Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (!root._readMonitorProc.running)
                root._readMonitorProc.running = true;
            if (!root._checkRecProc.running && !root._startRequested)
                root._checkRecProc.running = true;
        }
    }

    function toggleRecording(mode, monitorName) {
        if (root.isRecording) {
            root._stopRecProc.running = true;
            return "stopped";
        }

        // Start recording
        const monitor = monitorName || Registry.monitorName;
        root.setTargetMonitors(mode === "all" ? [] : [monitor]);
        root._startRequested = true;
        root._startProcessFinished = false;
        if (mode === "all") {
            root._startRecProc.command = [root.scriptPath, "start", "--all"];
        } else if (mode === "area") {
            root._startRecProc.command = [root.scriptPath, "start", "--area", "--monitor", monitor];
        } else {
            root._startRecProc.command = [root.scriptPath, "start", "--monitor", monitor];
        }
        root._startRecProc.running = true;
        return "started";
    }

    Component.onCompleted: {
        root._readMonitorProc.running = true;
        root._checkRecProc.running = true;
    }
}
