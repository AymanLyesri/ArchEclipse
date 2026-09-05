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
    // AGS Recording.tsx computes elapsed as Date.now() - start.
    property double startTimestamp: 0

    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/screenrecord.sh"

    // Process for checking recording state
    property Process _checkRecProc: Process {
        command: ["pgrep", "-x", "wf-recorder"]
        stdout: StdioCollector {
            onStreamFinished: {
                const running = text.trim().length > 0;
                if (running !== root.isRecording) {
                    // Capture the start moment on the 0->1 edge (AGS: Date.now() - start).
                    if (running) root.startTimestamp = Date.now();
                    root.isRecording = running;
                }
            }
        }
    }

    // Stop recording process
    property Process _stopRecProc: Process {
        command: [root.scriptPath, "stop"]
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    console.warn("[ScreenRecorder] Stop failed: " + text);
                    Notifications.send("ScreenRecord Error", "Failed to stop screen recording.");
                }
            }
        }
    }

    // Start recording process
    property Process _startRecProc: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    console.warn("[ScreenRecorder] Start failed: " + text);
                    Notifications.send("ScreenRecord Error", "Failed to start screen recording.");
                }
            }
        }
    }

    // Poll every 200ms like the AGS version
    property Timer _pollTimer: Timer {
        interval: 200
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._checkRecProc.running = true
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