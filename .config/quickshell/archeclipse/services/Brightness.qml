pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Brightness of the FOCUSED monitor.
//   * internal panel (eDP/LVDS/DSI) -> brightnessctl over /sys/class/backlight/*
//   * external monitor              -> DDC/CI via ddcutil (needs i2c-dev + `i2c` group)
QtObject {
    id: root

    // ---- public API (unchanged names, used by bar / OSD / control panel) ----
    // 0..1 brightness of the monitor currently under control (the focused one).
    property real screen: 0
    // True when anything is controllable (internal backlight OR a DDC/CI monitor).
    readonly property bool hasBacklight: root._devices.length > 0 || root._ddc.length > 0
    // Name of the monitor under control ("" = none, e.g. focused monitor has no DDC).
    property string targetName: ""
    // Default step (percent) for increment()/decrement().
    property int step: 10
    // Emitted when the controlled monitor's brightness really changed (key, slider,
    // external write) — NOT when focus merely moves to a monitor with another value.
    // BarState / bar widget use it to pulse the OSD.
    signal adjusted()

    // ---- internal backlight state ----
    property var _devices: []
    property int _primaryMax: 1
    property bool _maxKnown: false
    property string _primaryDevice: ""
    property real _internal: 0
    property bool _internalReady: false

    // ---- DDC/CI state ----
    // [{ name: "DP-1", bus: "5", max: 100, value: 0..1, ready: bool }]
    property var _ddc: []
    // bus -> raw value still to be written (latest wins)
    property var _ddcPending: ({})
    property var _ddcReadQueue: []
    // Low sleep multiplier + no verify read-back: ~5x faster, fine for relative UI use.
    readonly property var _ddcFlags: ["--noverify", "--sleep-multiplier", ".1"]

    // =====================================================================
    // Target resolution
    // =====================================================================
    function _focusedName() {
        const m = Hyprland.focusedMonitor;
        return m ? m.name : "";
    }

    function _isInternalName(name) {
        return /^(eDP|LVDS|DSI)/i.test(name);
    }

    function _ddcFor(name) {
        return root._ddc.find(d => d.name === name) ?? null;
    }

    // Internal backlight is used for the laptop panel; on setups without any DDC
    // monitor it is used regardless of the output name (old behaviour).
    function _useInternal(name) {
        if (root._devices.length === 0)
            return false;
        return root._ddc.length === 0 || name === "" || root._isInternalName(name);
    }

    function _refreshScreen() {
        const name = root._focusedName();
        const d = root._ddcFor(name);
        let t = "";
        let v = 0;
        if (d) {
            if (d.ready) {
                t = d.name;
                v = d.value;
            }
        } else if (root._useInternal(name) && root._maxKnown) {
            t = name !== "" ? name : root._primaryDevice;
            v = root._internal;
        }
        if (root.targetName !== t)
            root.targetName = t;
        if (t !== "" && Math.abs(root.screen - v) > 0.0005)
            root.screen = v;
    }

    property Connections _focusConn: Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            root._refreshScreen();
        }
    }

    // =====================================================================
    // Public control functions (IPC + sliders)
    // =====================================================================

    // Absolute set, 0..1. Used by sliders. Returns a human-readable result.
    function setScreen(percent) {
        return root._apply(percent);
    }

    // Relative change in percentage points (e.g. +10 / -10).
    function adjust(delta) {
        return root._apply((Math.round(root.screen * 100) + delta) / 100);
    }

    function increment() {
        return root.adjust(root.step);
    }

    function decrement() {
        return root.adjust(-root.step);
    }

    function describe() {
        if (root.targetName === "")
            return "no controllable display for '" + root._focusedName() + "'";
        return root.targetName + ": " + Math.round(root.screen * 100) + "%";
    }

    function _apply(percent) {
        const p = Math.max(0, Math.min(1, percent));
        const name = root._focusedName();
        const d = root._ddcFor(name);

        // --- external monitor over DDC/CI ---
        if (d) {
            if (!d.ready)
                return name + ": DDC/CI not ready yet";
            if (Math.abs(d.value - p) < 0.0005)
                return root.describe();
            d.value = p;
            // never write 0: many monitors go fully black / off
            root._ddcPending[d.bus] = Math.max(1, Math.round(p * d.max));
            root._pumpDdc();
            root._refreshScreen();
            root.adjusted();
            return root.describe();
        }

        // --- internal panel over brightnessctl ---
        if (root._useInternal(name) && root._maxKnown) {
            if (Math.abs(root._internal - p) < 0.0005)
                return root.describe();
            root._internal = p;
            const targetPercent = Math.round(p * 100);
            // Fan out to ALL backlight devices via the serial queue
            root._setQueue = root._devices.map(dev => ["brightnessctl", "--device=" + dev, "set", targetPercent + "%", "-q"]);
            if (!root._setBrightnessProc.running)
                root._pumpSetQueue();
            root._refreshScreen();
            root.adjusted();
            return root.describe();
        }

        return "no controllable display for '" + name + "'";
    }

    // =====================================================================
    // Internal backlight (brightnessctl)
    // =====================================================================

    // The kernel emits inotify MODIFY events on /sys/class/backlight/*/brightness
    // for every change, so FileView gives instant zero-poll updates for our own
    // writes and external ones alike.
    property FileView _brightnessView: FileView {
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            if (!root._maxKnown || root._primaryMax <= 0)
                return;
            // While our own writes are in flight the optimistic value is newer
            // than the file — don't let a stale event bounce it back.
            if (root._setBrightnessProc.running || root._setQueue.length > 0)
                return;
            const v = Number(text().trim());
            if (isNaN(v))
                return;
            const nv = v / root._primaryMax;
            const changed = Math.abs(nv - root._internal) > 0.0005;
            root._internal = nv;
            root._refreshScreen();
            if (changed && root._internalReady && root.targetName !== "" && !root._ddcFor(root.targetName))
                root.adjusted();
            root._internalReady = true;
        }
    }

    property Process _detectProc: Process {
        command: ["/bin/ls", "-1", "/sys/class/backlight"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._devices = text.trim().split("\n").filter(d => d.length > 0);
                if (root._devices.length > 0) {
                    root._primaryDevice = root._devices[0];
                    root._brightnessView.path = "/sys/class/backlight/" + root._primaryDevice + "/brightness";
                    root._maxProc.command = ["brightnessctl", "--device=" + root._primaryDevice, "max"];
                    root._maxProc.running = true;
                }
            }
        }
    }

    property Process _maxProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root._primaryMax = Number(text.trim()) || 1;
                root._maxKnown = true;
                // Max may arrive after the first file load — re-parse now.
                root._brightnessView.reload();
            }
        }
    }

    // Serial queue: a single reused Process cannot run N commands from a loop
    // (running=true while running is a no-op), so chain one device per exit.
    property var _setQueue: []
    property Process _setBrightnessProc: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("[Brightness] Failed to set brightness: " + text);
            }
        }
        onExited: root._pumpSetQueue()
    }

    function _pumpSetQueue() {
        if (root._setQueue.length === 0)
            return;
        const next = root._setQueue.shift();
        root._setBrightnessProc.command = next;
        root._setBrightnessProc.running = true;
    }

    // =====================================================================
    // External monitors (ddcutil / DDC-CI)
    // =====================================================================

    // `ddcutil detect` is slow (seconds) — run once at startup and on hotplug.
    // Missing ddcutil is not an error: the shell wrapper just prints nothing.
    property Process _ddcDetectProc: Process {
        command: ["sh", "-c", "command -v ddcutil >/dev/null 2>&1 && ddcutil detect --brief 2>/dev/null; exit 0"]
        stdout: StdioCollector {
            onStreamFinished: root._parseDdcDetect(text)
        }
    }

    function _parseDdcDetect(out) {
        const found = [];
        for (const block of out.split(/\n\s*\n/)) {
            if (!block.trim().startsWith("Display "))
                continue;
            const bus = block.match(/I2C bus:\s*\/dev\/i2c-(\d+)/);
            // "DRM_connector: card1-DP-1" (ddcutil 2.x) / "DRM connector: ..." (older)
            const con = block.match(/DRM[_ ]connector:\s*(?:card\d+-)?(\S+)/);
            if (!bus)
                continue;
            found.push({ name: con ? con[1] : "", bus: bus[1], max: 100, value: 0, ready: false });
        }

        // No connector info (some NVIDIA setups): if exactly one DDC display and
        // exactly one non-internal output exist, they must be the same monitor.
        if (found.length === 1 && found[0].name === "") {
            const ext = [];
            for (let i = 0; i < Quickshell.screens.length; i++) {
                if (!root._isInternalName(Quickshell.screens[i].name))
                    ext.push(Quickshell.screens[i]);
            }
            if (ext.length === 1)
                found[0].name = ext[0].name;
        }

        const list = found.filter(d => d.name !== "");
        const seen = {};
        root._ddc = list.filter(d => (seen[d.name] ? false : (seen[d.name] = true)));
        root._ddcReadQueue = root._ddc.slice();
        root._readNextDdc();
        root._refreshScreen();
    }

    // Initial read of the current value, one monitor at a time (I2C is slow and
    // doesn't like parallel access). The bus number is echoed in front of the
    // ddcutil output so the result can't be attributed to the wrong monitor
    // regardless of stream-finished / exited ordering.
    function _readNextDdc() {
        if (root._ddcReadProc.running || root._ddcReadQueue.length === 0)
            return;
        const d = root._ddcReadQueue.shift();
        root._ddcReadProc.command = ["sh", "-c",
            "printf 'BUS %s ' \"$1\"; ddcutil --bus \"$1\" getvcp 10 --brief 2>/dev/null; exit 0",
            "sh", d.bus];
        root._ddcReadProc.running = true;
    }

    property Process _ddcReadProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                // "BUS <n> VCP 10 C <current> <max>"
                const m = text.match(/BUS\s+(\d+)\s+VCP\s+10\s+C\s+(\d+)\s+(\d+)/);
                if (m) {
                    const d = root._ddc.find(x => x.bus === m[1]);
                    if (d) {
                        d.max = Math.max(1, parseInt(m[3]));
                        d.value = Math.min(1, parseInt(m[2]) / d.max);
                        d.ready = true;
                    }
                }
                root._refreshScreen();
            }
        }
        onExited: {
            root._refreshScreen();
            root._readNextDdc();
        }
    }

    // Coalescing writer: ONE ddcutil at a time; while it runs, newer values just
    // overwrite the pending slot for that bus, and the latest one is sent on exit.
    function _pumpDdc() {
        if (root._ddcSetProc.running)
            return;
        const buses = Object.keys(root._ddcPending);
        if (buses.length === 0)
            return;
        const bus = buses[0];
        const raw = root._ddcPending[bus];
        delete root._ddcPending[bus];
        root._ddcSetProc.command = ["ddcutil", "--bus", bus].concat(root._ddcFlags).concat(["setvcp", "10", String(raw)]);
        root._ddcSetProc.running = true;
    }

    property Process _ddcSetProc: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("[Brightness] ddcutil: " + text.trim());
            }
        }
        onExited: root._pumpDdc()
    }

    // Re-detect when outputs are plugged / unplugged (debounced).
    property Timer _redetectTimer: Timer {
        interval: 1000
        onTriggered: {
            if (!root._ddcDetectProc.running)
                root._ddcDetectProc.running = true;
        }
    }
    property Connections _screensConn: Connections {
        target: Quickshell
        function onScreensChanged() {
            root._redetectTimer.restart();
        }
    }

    Component.onCompleted: {
        root._detectProc.running = true;
        root._ddcDetectProc.running = true;
    }
}
