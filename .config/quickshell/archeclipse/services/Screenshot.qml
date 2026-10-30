pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Owns every screenshot.sh spawn because destroying a Process kills its child
// (measured: an area slurp outlived the folding island), as ScreenRecorder does.
QtObject {
    id: root

    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/screenshot.sh"

    property Process _shotProc: Process {
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: code => {
            const detail = ((_shotProc.stderr.text ?? "") + " " + (_shotProc.stdout.text ?? "")).trim();
            // Escape-cancelled slurp exits 1 with no output — a deliberate
            // no-op (same contract as screenrecord.sh).
            if (code === 0 || detail === "")
                return;
            console.warn("[Screenshot] shot exited (" + code + "): " + detail);
            Notifications.send("Screenshot Error", detail);
        }
    }

    // "area" selects a region, anything else the focused monitor. One shot at a time:
    // reassigning `command` mid-run swaps the invocation; the script locks guard dups.
    function capture(mode, monitorName) {
        if (root._shotProc.running)
            return false;
        const arg = mode === "area" ? "--area" : "--now";
        root._shotProc.command = [root.scriptPath, arg, "--monitor", monitorName];
        root._shotProc.running = true;
        return true;
    }
}
