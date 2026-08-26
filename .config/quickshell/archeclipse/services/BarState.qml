pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

// Port of the Bar.tsx priority-based state resolver.
// States: compact (base), expanded, and transient pulses
// (volume/brightness/recording/player/network). Highest priority wins.
QtObject {
    id: root

    readonly property var priorities: ({
        compact: 0,
        recording: 40,
        expanded: 60,
        volume: 80,
        brightness: 80,
        network: 80,
        player: 80,
        search: 100
    })

    property string state: "compact"
    property var activeStates: ({ compact: true })   // name -> active
    property var _timers: ({})

    function resolve() {
        let best = "compact";
        let bestP = -1;
        for (const name in activeStates) {
            if (!activeStates[name]) continue;
            const p = priorities[name] ?? 0;
            if (p > bestP) { best = name; bestP = p; }
        }
        // 100ms delay mirrors Bar.tsx so rapid activate/deactivate coalesces
        resolveTimer.restart();
    }

    property Timer resolveTimer: Timer {
        id: _resolveTimer
        interval: 100
        onTriggered: {
            let best = "compact", bestP = -1;
            const act = root.activeStates;
            for (const name in act) {
                if (!act[name]) continue;
                const p = root.priorities[name] ?? 0;
                if (p > bestP) { best = name; bestP = p; }
            }
            if (root.state !== best) root.state = best;
        }
    }

    function activate(name: string, holdMs: int) {
        if (_timers[name]) { _timers[name].stop(); _timers[name] = null; }
        if (holdMs > 0) {
            const t = Qt.createQmlObject("import QtQuick; Timer { repeat:false }", root);
            t.interval = holdMs;
            t.triggered.connect(() => deactivate(name));
            t.start();
            _timers[name] = t;
        }
        const next = Object.assign({}, activeStates);
        next[name] = true;
        activeStates = next;
        resolve();
    }

    function deactivate(name: string) {
        if (name === "compact") return;
        if (name === "expanded" && Settings.barExpanded) return;
        if (_timers[name]) { _timers[name].stop(); delete _timers[name]; }
        const next = Object.assign({}, activeStates);
        next[name] = false;
        activeStates = next;
        resolve();
    }

    // Always-Expanded setting pins expanded (Bar.tsx settings watcher)
    property bool expandedPin: Settings.barExpanded
    onExpandedPinChanged: expandedPin ? activate("expanded", 0) : deactivate("expanded")

    // --- per-monitor visibility overrides (barShown map) ---
    property var barShown: ({})
    function revealBar(monitorName: string) {
        const n = Object.assign({}, barShown); n[monitorName] = true; barShown = n;
    }
    function concealBar(monitorName: string) {
        const n = Object.assign({}, barShown); delete n[monitorName]; barShown = n;
    }
    function toggleBarShown(monitorName: string) {
        const n = Object.assign({}, barShown);
        n[monitorName] = !(barShown[monitorName] ?? autoVisibleDefault());
        barShown = n;
    }

    function autoVisibleDefault(): bool { return Settings.barLock || Settings.barSmartHide; }

    // --- transient pulse watchers (Bar.tsx watchTransient equivalents) ---
    property real _lastVolume: -1
    property bool _volFirst: true
    property Connections _volWatch: Connections {
        target: VolumeWatcher.sink
        ignoreUnknownSignals: true
        function onVolumesChanged() {
            const v = VolumeWatcher.volume;
            if (root._volFirst) { root._volFirst = false; root._lastVolume = v; return; }
            if (Math.abs(v - root._lastVolume) < 0.001) return;
            root._lastVolume = v;
            root.activate("volume", 2000);
        }
    }

    // brightness changes via brightnessctl — event-driven through ddc/udev is
    // not exposed by Quickshell; poll cheaply at 2s and pulse only on change.
    property real _lastBrightness: -1
    property bool _briFirst: true
    property int _briFastLeft: 0   // remaining fast-poll ticks after a change

    property Timer _briPoll: Timer {
        interval: root._briFastLeft > 0 ? 300 : 2000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            if (root._briFastLeft > 0) root._briFastLeft--;
            briQuery.running = true;
        }
    }
    property Process briQuery: Process {
        command: ["sh", "-c", "brightnessctl -m info"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = text.trim().split(",");
                    const v = parseFloat(parts[3]) / 100;   // field 3 is the percent (brightnessctl -m)
                    if (root._briFirst) { root._briFirst = false; root._lastBrightness = v; return; }
                    if (Math.abs(v - root._lastBrightness) < 0.001) return;
                    root._lastBrightness = v;
                    root._briFastLeft = 10;              // keep tracking for ~3s
                    root.activate("brightness", 2000);   // re-trigger resets the hold timer
                } catch (e) {}
            }
        }
    }

    // recording state — same detector as AGS record.service (pgrep wf-recorder)
    property bool recording: false
    onRecordingChanged: recording ? activate("recording", 0) : deactivate("recording")
    property Timer _recTimer: Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: recQuery.running = true
    }
    property Process recQuery: Process {
        command: ["pgrep", "-x", "wf-recorder"]
        stdout: StdioCollector {
            onStreamFinished: root.recording = text.trim().length > 0
        }
    }

    // Debounced Hyprland event tick — drives smart-hide re-evaluation,
    // same as the hyprlandTick in Bar.tsx.
    property int hyprlandTick: 0
    property Timer _tickTimer: Timer {
        interval: 100
        onTriggered: root.hyprlandTick++
    }
    property Connections _hyprConn: Connections {
        target: Hyprland
        function onRawEvent(e) { root._tickTimer.restart(); }
    }
}
