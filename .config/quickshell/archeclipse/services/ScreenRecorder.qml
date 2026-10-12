pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Port of services/record.service.ts — manages screen recording via wf-recorder
// and a user script. Polls for recording state.
QtObject {
    id: root

    property bool isRecording: false

    // Epoch ms when the current recording started (0 when not recording).
    // Elapsed is computed as Date.now() - start.
    property double startTimestamp: 0

    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/screenrecord.sh"

    // Process for checking recording state
    property Process _checkRecProc: Process {
        command: ["pgrep", "-x", "wf-recorder"]
        stdout: StdioCollector {
            onStreamFinished: {
                const running = text.trim().length > 0;
                if (running !== root.isRecording) {
                    // Capture the start moment on the 0->1 edge.
                    if (running) root.startTimestamp = Date.now();
                    root.isRecording = running;
                }
                if (running)
                    root._pollTimer.start();
                else
                    root._pollTimer.stop();
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
        onTriggered: root._checkRecProc.running = true
    }

    // Poll at 1s only while recording: pgrep truthfully reflects
    // wf-recorder liveness (covers kills from outside the shell too).
    property Timer _pollTimer: Timer {
        interval: 1000
        running: false
        repeat: true
        onTriggered: {
            if (!root._checkRecProc.running)
                root._checkRecProc.running = true;
        }
    }

    function toggleRecording(mode) {
        if (root.isRecording) {
            root._stopRecProc.running = true;
            return "stopped";
        }

        // Start recording
        if (mode === "area") {
            root._startRecProc.command = [root.scriptPath, "start", "--area"];
        } else {
            root._startRecProc.command = [root.scriptPath, "start"];
        }
        root._startRecProc.running = true;
        return "started";
    }

    Component.onCompleted: {
        root._checkRecProc.running = true;
    }
}