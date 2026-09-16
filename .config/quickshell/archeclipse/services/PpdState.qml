pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// power-profiles-daemon availability — probed once at quickshell start.
// ControlPanelBody binds to this instead of spawning `powerprofilesctl get`
// each time the control island opens (its body is transient, so
// Component.onCompleted there re-ran the probe on every open).
QtObject {
    id: root

    property bool available: false
    property bool _started: false

    property Process _probe: Process {
        command: ["bash", "-c", "powerprofilesctl get 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: root.available = (text.trim() !== "")
        }
    }

    function start() {
        if (root._started)
            return;
        root._started = true;
        root._probe.running = true;
    }

    // Re-probe on demand (e.g. PPD installed mid-session).
    function refresh() {
        root._started = true;
        root._probe.running = true;
    }

    Component.onCompleted: root.start()
}
