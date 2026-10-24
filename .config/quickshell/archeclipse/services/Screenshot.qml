pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Owner of every screenshot.sh spawn. It lives here — not in
// ScreenshotIsland — because that island is created and destroyed by the
// hover reveal (`shotLoader.active: screenshotPiece.shown`), and
// destroying a Quickshell Process kills its child (measured: a loader
// deactivated 0.5s into `sleep 4; touch marker` never produced the
// marker). Fullscreen grim finishes inside the 1s leave grace, but an
// area shot needs a slurp drag with the pointer off the bar, so the
// island always folded first and the script died mid-selection
// (measured 2026-10-24: screenshot.sh opened /tmp/screenshot-area.lock
// at 23:00:07, no PNG was written, and the orphaned slurp then made
// screenrecord.sh report "duplicate trigger ignored (slurp already
// running)"). Same reason ScreenRecorder owns its start/stop Processes.
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

    // mode: "area" -> free-form region, anything else -> focused monitor.
    // One shot at a time: reassigning `command` while running would swap
    // the in-flight invocation; the scripts' own locks already serialise
    // duplicate area triggers.
    function capture(mode, monitorName) {
        if (root._shotProc.running)
            return false;
        const arg = mode === "area" ? "--area" : "--now";
        root._shotProc.command = [root.scriptPath, arg, "--monitor", monitorName];
        root._shotProc.running = true;
        return true;
    }
}
