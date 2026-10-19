pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Networking
import qs.theme
import qs.services

Singleton {
    id: root

    // Priority map (default base 0 < recording 40 < pulses 80 < search 100)
    // "compact"/"expanded" kept only for backward-compat with old persist files.
    // wallpaper (95) beats control (90) so SUPER+W opens over the control island.
    // Side pills keep priority entries but resolveState() skips them. All
    // interactive islands and transient pulses are stored per monitor.
    property var priority: {
        "default": 0,
        "recording": 40,
        "volume": 80,
        "brightness": 80,
        "network": 80,
        "player": 80,
        "weather": 80,
        "system": 80,
        "overview": 85,
        "control": 90,
        "left": 93,
        "right": 93,
        "wallpaper": 95,
        "search": 100
    }

    // Active states with hold timers
    property var activeStates: {}

    // Search is a single session because Launcher is a singleton; opening it
    // on another monitor moves that session. Other islands and pulses may be
    // active independently on multiple monitors.
    property var panelStatesByMonitor: ({})
    property string searchMonitor: ""
    readonly property var monitorScopedStates: ({
        search: true, left: true, right: true, control: true, wallpaper: true,
        player: true, volume: true, brightness: true, network: true,
        weather: true, system: true, overview: true, recording: true
    })
    function isMonitorScopedState(name): bool {
        return root.monitorScopedStates[name] === true;
    }

    // Bar shown overrides (per monitor)
    property var barShown: {}

    // Hyprland tick for reactive deps
    property int hyprlandTick: 0
    property var _tickTimer: null

    // Geometric room-check results per monitor name.
    // Populated by _roomProc from `hyprctl j/clients` + `hyprctl j/monitors`.
    property var blockedMonitors: {}
    // Current bar height used for the band check
    property int barHeight: 34

    // Current resolved state (default is the permanent base, no compact)
    property string state: "default"

    // Compatibility flags for callers that mean the focused monitor. Bar
    // instances use isOpenFor() with their own monitor name.
    readonly property bool leftOpen: isOpenFor("left", Registry.monitorName)
    readonly property bool rightOpen: isOpenFor("right", Registry.monitorName)

    // Open in-bar popovers (tray overflow/menu popups), tracked by their
    // owning monitor so a menu on one output cannot pin every bar open.
    property var popupCountByMonitor: ({})
    readonly property int popupCount: Object.values(root.popupCountByMonitor || {}).reduce((sum, count) => sum + Number(count || 0), 0)
    function popupCountFor(monitorName): int {
        const monitor = monitorName || Registry.monitorName || "";
        return Number((root.popupCountByMonitor || {})[monitor] || 0);
    }
    function holdPopup(monitorName) {
        const monitor = monitorName || Registry.monitorName || "";
        if (!monitor)
            return;
        const next = Object.assign({}, root.popupCountByMonitor || {});
        next[monitor] = Number(next[monitor] || 0) + 1;
        root.popupCountByMonitor = next;
    }
    function releasePopup(monitorName) {
        const monitor = monitorName || Registry.monitorName || "";
        if (!monitor)
            return;
        const next = Object.assign({}, root.popupCountByMonitor || {});
        const count = Number(next[monitor] || 0);
        if (count <= 1)
            delete next[monitor];
        else
            next[monitor] = count - 1;
        root.popupCountByMonitor = next;
    }

    // Hold timers
    property var holdTimers: {}

    // Debounce timer
    property var debounceTimer: null
    property Connections _focusedMonitorConnection: Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            root.debounceResolve();
        }
    }

    // Settings reference
    property var settings: qs.theme.Settings

    // Lock setting (from settings)
    // `expanded` kept for compat (always true — default is the base state).
    property bool lock: true
    property bool expanded: true
    property bool isDefault: true
    property bool orientation: true
    property bool smartHide: false
    property bool fullWidth: false

    // Volume pulse tracking
    property real _lastVolume: 0
    property bool _volumeFirstRender: true
    property int volumeEvents: 0
    property string lastVolumeMonitor: ""
    property string volumeTargetMonitor: ""
    property Timer _volumeTargetTimer: Timer {
        interval: 600
        repeat: false
        onTriggered: root.volumeTargetMonitor = ""
    }

    // Brightness pulse tracking
    property real _lastBrightness: 0
    // false: Brightness.adjusted never fires for the initial load, so a true
    // guard here would swallow the first real keypress.
    property bool _brightnessFirstRender: false
    property int brightnessEvents: 0
    property string lastBrightnessMonitor: ""
    property var _lastBrightnessByMonitor: ({})

    // Player pulse tracking
    property var _activePlayer: null
    property string _playerKey: ""
    property bool _playerFirstRender: true
    property int playerEvents: 0
    // Startup grace: MPRIS players/metadata populate asynchronously over
    // the first seconds after bar init (list bind, then title/artist/url
    // trickling in). The first-render guard only covers the single
    // synchronous setup call, so those staged arrivals look like new
    // items and pop the island on every (re)start. While true, updates
    // only refresh the baseline key, never pulse.
    property bool _playerStarting: true

    // Network pulse tracking
    property var _networkDevice: null
    property bool _networkFirstRender: true
    property var _lastNetSig: {}
    property Connections _networkDevicesConnection: Connections {
        target: Networking.devices
        function onValuesChanged() {
            root.trackNetworkDevice(root.primaryNetworkDevice());
        }
    }
    property Connections _networkDeviceConnection: Connections {
        target: root._networkDevice
        function onConnectedChanged() {
            root.trackNetworkDevice(root.primaryNetworkDevice());
        }
        function onStateChanged() {
            root.trackNetworkDevice(root.primaryNetworkDevice());
        }
    }

    // Volume watcher
    property PwObjectTracker _volumeTracker: PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Component.onCompleted: {
        root.settings = Settings;
        root.lock = Settings.barLock ?? true;
        root.expanded = Settings.barDefault ?? true;
        root.isDefault = Settings.barDefault ?? true;
        root.orientation = Settings.barOrientation ?? true;
        root.smartHide = Settings.barSmartHide ?? false;
        root.fullWidth = Settings.barFullWidth ?? false;

        root.activeStates = {
            "default": {
                priority: root.priority.default
            }
        };

        // Setup volume watcher (pipewire sink)
        setupVolumeWatcher();
        // Setup MPRIS player watcher
        setupPlayerWatcher();
        // Setup network watcher
        setupNetworkWatcher();

        // End the MPRIS startup grace a few seconds after init (see
        // _playerStarting): late-arriving initial metadata must not pulse.
        const grace = Qt.createQmlObject('import QtQuick; Timer { repeat: false; interval: 5000 }', root);
        grace.triggered.connect(() => {
            root._playerStarting = false;
            grace.destroy();
        });
        grace.start();

        // Hyprland event tick — re-evaluates the geometric smart-hide room
        // check when clients move/resize (client moves don't re-emit a
        // change to the static toplevel list, so we tick on the raw event
        // stream, debounced).
        Hyprland.rawEvent.connect(event => {
            if (!root._tickTimer) {
                root._tickTimer = Qt.createQmlObject('import QtQuick; Timer { repeat: false; interval: 100 }', root);
                root._tickTimer.triggered.connect(() => {
                    root._tickTimer = null;
                    root.hyprlandTick++;
                    root.updateRoomCheck();
                });
                root._tickTimer.start();
            }
        });

        // Initial room check
        root.updateRoomCheck();

        // Sync persistent recording state at startup (subscribe
        // isRecording from mount; a recording already in progress must show)
        if (ScreenRecorder.isRecording)
            root.activate("recording", 0, ScreenRecorder.targetMonitor || Registry.monitorName);
    }

    // -----------------------------------------------------------------
    // Geometric smart-hide room check.
    // A client "blocks" the bar band if it overlaps the top/bottom barHeight
    // pixels of a monitor on the monitor's active workspace. Queried from
    // hyprctl so geometry is always current (client .at/.size in the cached
    // toplevel list lags behind moves/resizes).
    // -----------------------------------------------------------------
    property var _roomClientText: ""
    property var _roomMonitorText: ""

    function updateRoomCheck() {
        const pc = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        pc.command = ["hyprctl", "clients", "-j"];
        pc.running = true;
        pc.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root);
        pc.stdout.onStreamFinished.connect(() => {
            root._roomClientText = pc.stdout.text;
            root.finishRoomCheck();
        });
    }

    function finishRoomCheck() {
        // Query monitors only after clients arrive; then compute blockage.
        const pm = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        pm.command = ["hyprctl", "monitors", "-j"];
        pm.running = true;
        pm.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root);
        pm.stdout.onStreamFinished.connect(() => {
            root.computeRoomCheck(root._roomClientText, pm.stdout.text);
        });
    }

    function computeRoomCheck(clientsText, monitorsText) {
        let clients = [];
        let monitors = [];
        try {
            clients = JSON.parse(clientsText);
        } catch (e) {
            return;
        }
        try {
            monitors = JSON.parse(monitorsText);
        } catch (e) {
            return;
        }

        const blocked = {};
        const onTop = root.orientation;
        const h = root.barHeight;

        for (const m of monitors) {
            if (!m || m.name === undefined)
                continue;
            const wsId = m.activeWorkspace?.id;
            if (wsId === undefined) {
                blocked[m.name] = false;
                continue;
            }
            const bandStart = onTop ? m.y : m.y + m.height - h;
            const bandEnd = bandStart + h;
            const hit = clients.some(c => {
                if (!c || !c.mapped)
                    return false;
                if (c.workspace?.id !== wsId)
                    return false;
                const top = c.at?.[1] ?? 0;
                const bottom = top + (c.size?.[1] ?? 0);
                return bottom > bandStart && top < bandEnd;
            });
            blocked[m.name] = hit;
        }
        root.blockedMonitors = blocked;
    }

    // Bar auto-visibility core:
    // lock => always visible; unlocked => hidden until the screen-edge
    // hover strip (BarHoverWindow) sets an explicit override. The override
    // wins over this in Bar.barVisible.
    function barVisibleFor(monitorName) {
        if (root.lock)
            return true;
        return false;
    }

    // ===== Volume watcher =====
    // NOTE: the signal must be CONNECTED first; the first-render guard lives
    // inside the callback. Returning early before connect (as before) meant
    // the pulse never fired at all.
    property bool _volumeWired: false
    function setupVolumeWatcher() {
        const sink = Pipewire.defaultAudioSink;
        // volumesChanged lives on sink.audio (PwNodeAudioIface), which only
        // exists once the node is bound — retry until then.
        if (!sink || !sink.audio || root._volumeWired) {
            if ((!sink || !sink.audio) && !root._volumeWired) {
                const t = Qt.createQmlObject('import QtQuick; Timer { repeat: false; interval: 1000 }', root);
                t.triggered.connect(() => {
                    t.destroy();
                    root.setupVolumeWatcher();
                });
                t.start();
            }
            return;
        }
        root._volumeWired = true;
        root._lastVolume = sink.audio.volume ?? 0;
        sink.audio.volumesChanged.connect(() => {
            if (!sink.audio)
                return;
            const vol = sink.audio.volume;
            if (vol === undefined || isNaN(vol) || vol < 0 || vol > 1)
                return;

            // Skip the initial notification on mount (first-render guard)
            if (root._volumeFirstRender) {
                root._volumeFirstRender = false;
                root._lastVolume = vol;
                return;
            }
            // Ignore spurious notifications where the value didn't change
            if (vol === root._lastVolume)
                return;
            root._lastVolume = vol;
            const monitor = root.volumeTargetMonitor || Registry.monitorName;
            root.lastVolumeMonitor = monitor;
            root._volumeTargetTimer.stop();
            root.volumeTargetMonitor = "";
            root.volumeEvents++;

            // Respect an existing hover-pin: re-pulsing with a hold timer
            // while pinned would arm an auto-deactivate that closes the
            // island under an attending cursor. 2500ms linger (like the
            // player pill) so the OSD stays readable after key repeats.
            if (!root.isPersistent("volume", monitor))
                root.activate("volume", 2500, monitor);
        });
    }

    function noteVolumeTarget(monitorName) {
        root.volumeTargetMonitor = monitorName || Registry.monitorName;
        root._volumeTargetTimer.restart();
    }

    // ===== Brightness watcher (event-driven, like volume) =====
    // The Brightness service watches the kernel backlight file with inotify,
    // so any change — our own sliders or external brightness keys — updates
    // Brightness.screen instantly with zero polling. Pulse on change, exactly
    // like the Pipewire volumesChanged hookup below.
    property Connections _brightnessConn: Connections {
        target: Brightness
        // `adjusted` (not `screenChanged`): fires only on real changes — keys,
        // sliders, external writes — never on the initial load or when focus
        // merely moves to a monitor that has a different brightness.
        function onAdjusted(monitorName) {
            const monitor = monitorName || Brightness.targetName || Registry.monitorName;
            const val = Brightness.screenFor(monitor);
            // Skip the initial notification on mount (first-render guard)
            if (root._brightnessFirstRender) {
                root._brightnessFirstRender = false;
                root._lastBrightness = val;
                const baseline = Object.assign({}, root._lastBrightnessByMonitor || {});
                baseline[monitor] = val;
                root._lastBrightnessByMonitor = baseline;
                return;
            }
            // Ignore spurious notifications where the value didn't change
            const previous = (root._lastBrightnessByMonitor || {})[monitor];
            if (previous !== undefined && val === previous)
                return;
            root._lastBrightness = val;
            const baseline = Object.assign({}, root._lastBrightnessByMonitor || {});
            baseline[monitor] = val;
            root._lastBrightnessByMonitor = baseline;
            root.lastBrightnessMonitor = monitor;
            root.brightnessEvents++;

            // Respect an existing hover-pin (see volume watcher above).
            // 2500ms linger (like the player pill).
            if (!root.isPersistent("brightness", monitor))
                root.activate("brightness", 2500, monitor);
        }
    }

    // ===== MPRIS player watcher (event-driven) =====
    // The island opens only when the actual media item meaningfully
    // changes (composite identity below). YouTube thumbnail hover
    // previews publish the hovered video's title as transient metadata
    // while the page URL stays on a browse page (no /watch, /shorts,
    // ... video path) — that is preview noise, not a new item, so it
    // never pulses. Redundant pushes (late cover art, position/length,
    // play/pause) keep the same key and are ignored the same way.
    function pickPlayer() {
        // Playing-else-first (matches DefaultBar.firstPlayable's intent,
        // MediaWidget.player and playerDiag): a paused player with a stale
        // title must never shadow the actually-playing one just because it
        // sorts earlier in Mpris.players.values. Order-dependence here
        // stuck the watcher on paused Firefox while Spotify played, so
        // track changes never pulsed.
        let first = null;
        for (const p of Mpris.players.values) {
            const titled = ((p.trackTitle ?? "").trim() !== "");
            const playing = p.playbackState === MprisPlaybackState.Playing;
            if (!titled && !playing)
                continue;
            if (playing)
                return p;
            if (!first)
                first = p;
        }
        return first;
    }

    function previewUrl(p) {
        try {
            const md = p ? p.metadata : null;
            if (!md)
                return "";
            const u = md["xesam:url"];
            return u === undefined || u === null ? "" : String(u);
        } catch (e) {
            return "";
        }
    }

    function playerItemKey(p) {
        if (!p)
            return "";
        return (p.uniqueId ?? "?") + "|" + (p.trackTitle ?? "") + "|" + (p.trackArtist ?? "") + "|" + previewUrl(p);
    }

    // True when the player exposes preview noise rather than an actual
    // media item: a YouTube browse page (no video path). Not a site
    // blacklist — real video pages (/watch, /shorts, ...) return false.
    function isPreviewUpdate(p) {
        const m = previewUrl(p).match(/^https?:\/\/(?:www\.|m\.)?youtube\.com(\/[^?#]*)?/i);
        if (!m)
            return false;
        const path = (m[1] || "/").toLowerCase();
        return !(/^(\/watch|\/shorts\/|\/embed\/|\/live\/|\/v\/)/.test(path));
    }

    function notePlayerUpdate() {
        root.playerEvents++;
        const player = pickPlayer();
        root._activePlayer = player;
        const key = playerItemKey(player);

        // Skip first evaluation (snapshot the baseline, don't pulse)
        if (root._playerFirstRender) {
            root._playerFirstRender = false;
            root._playerKey = key;
            return;
        }

        // Redundant metadata/state push — identity unchanged
        if (key === root._playerKey)
            return;
        root._playerKey = key;

        // Player gone or thumbnail-preview noise — record, don't pulse
        if (!player || isPreviewUpdate(player))
            return;

        // Startup grace — record the baseline above, never pulse
        if (root._playerStarting)
            return;

        // Track metadata is global, so place its brief reveal on the currently
        // focused monitor. Hover and click reveals are targeted by MediaPill.
        root.activate("player", 2500, Registry.monitorName);
    }

    function setupPlayerWatcher() {
        root.notePlayerUpdate();
        Mpris.players.valuesChanged.connect(root.notePlayerUpdate);
    }

    // ===== Network watcher =====
    // Pulses the bar-wide "network" state for
    // ~3s whenever the active network connection changes (wifi connect,
    // disconnect, ssid change, signal re-association).
    function setupNetworkWatcher() {
        root.trackNetworkDevice(root.primaryNetworkDevice());
    }

    function primaryNetworkDevice() {
        if (!Networking.devices?.values)
            return null;
        for (const d of Networking.devices.values) {
            if (d && d.connected)
                return d;
        }
        return Networking.devices.values.length > 0 ? Networking.devices.values[0] : null;
    }

    function trackNetworkDevice(device) {
        if (device !== root._networkDevice) {
            root._networkDevice = device;
            root._networkFirstRender = true;
        }
        if (!device)
            return;

        if (root._networkFirstRender) {
            root._networkFirstRender = false;
            root._lastNetSig = {
                state: device.state,
                connected: device.connected
            };
            return;
        }

        const changed = device.connected !== root._lastNetSig.connected || device.state !== root._lastNetSig.state;
        root._lastNetSig = {
            state: device.state,
            connected: device.connected
        };
        if (changed)
            root.activate("network", 3000, Registry.monitorName);
    }

    function monitorStates(monitorName) {
        const monitor = monitorName || Registry.monitorName || "";
        return (root.panelStatesByMonitor || {})[monitor] || {};
    }

    function isOpenFor(name, monitorName): bool {
        const monitor = monitorName || Registry.monitorName || "";
        return root.monitorStates(monitor)[name] === true;
    }

    function activeStatesFor(monitorName) {
        const states = Object.assign({}, root.activeStates || {});
        const local = root.monitorStates(monitorName);
        for (const name of Object.keys(local)) {
            if (local[name] === true)
                states[name] = {priority: root.priority[name] ?? 0};
        }
        return states;
    }

    function stateFor(monitorName): string {
        return root.resolveState(monitorName);
    }

    // Resolve highest priority state for a monitor (default is the base fallback).
    function resolveState(monitorName): string {
        var best = "default";
        var bestPriority = -Infinity;
        const states = root.activeStatesFor(monitorName);
        for (var name in states) {
            // Side pills (left/right/recording) are independent pills, not
            // main-pill states — the main pill never resolves them.
            if (name === "left" || name === "right" || name === "recording")
                continue;
            // Legacy base names resolve to the default state
            var canonical = (name === "expanded" || name === "compact") ? "default" : name;
            var entry = states[name];
            if (entry.priority > bestPriority) {
                best = canonical;
                bestPriority = entry.priority;
            }
        }
        return best;
    }

    // Activate a state (with optional holdMs for auto-deactivate).
    // Omit holdMs (or pass 0) for persistent states that stay active until
    // explicitly deactivated (search toggle, recording). Only holdMs > 0
    // arms an auto-deactivate timer. "default" is the permanent base.
    // "expanded"/"compact" are accepted as legacy aliases for "default".
    // True when a state is active with no auto-deactivate timer — i.e.
    // persistently pinned (pulses always arm a timer otherwise, so a
    // timer-less pulse means something pinned it, e.g. IslandHoverPin).
    function isPersistent(name, monitorName) {
        if (root.isMonitorScopedState(name)) {
            const monitor = monitorName || Registry.monitorName || "";
            const timers = root.holdTimers || {};
            return root.isOpenFor(name, monitor) && !timers[name + "@" + monitor];
        }
        const active = root.activeStates || {};
        const timers = root.holdTimers || {};
        return (name in active) && !timers[name];
    }

    function activate(name, holdMs, monitorName) {
        const capture = Registry.get("capture-session");
        if (capture && capture.active && capture.desiredState !== "" && name !== capture.desiredState
            && !(capture.overviewMode && (name === "left" || name === "right")))
            return;
        if (name === "expanded" || name === "compact")
            name = "default";
        var priority = root.priority[name];
        if (priority === undefined)
            return;

        if (root.isMonitorScopedState(name)) {
            const monitor = monitorName || Registry.monitorName || "";
            // Volume and brightness share one OSD slot on this monitor.
            // Clear the rival in the same scoped map before returning below.
            if (name === "volume" || name === "brightness")
                root.deactivate(name === "volume" ? "brightness" : "volume", monitor);
            if (name === "search") {
                // Launcher owns shared query/results state, so only one
                // monitor may display its input at a time. Move it cleanly.
                var moved = Object.assign({}, root.panelStatesByMonitor || {});
                for (const key of Object.keys(moved)) {
                    if (key !== monitor && moved[key] && moved[key].search) {
                        const old = Object.assign({}, moved[key]);
                        delete old.search;
                        if (Object.keys(old).length)
                            moved[key] = old;
                        else
                            delete moved[key];
                    }
                }
                root.searchMonitor = monitor;
                root.panelStatesByMonitor = moved;
            }

            const scopedTimers = root.holdTimers || {};
            const timerKey = name + "@" + monitor;
            if (scopedTimers[timerKey]) {
                scopedTimers[timerKey].stop();
                scopedTimers[timerKey] = null;
            }
            var byMonitor = Object.assign({}, root.panelStatesByMonitor || {});
            const local = Object.assign({}, byMonitor[monitor] || {});
            local[name] = true;
            byMonitor[monitor] = local;
            root.panelStatesByMonitor = byMonitor;

            if (holdMs !== undefined && holdMs > 0) {
                const t = Qt.createQmlObject('import QtQuick; Timer { repeat: false; interval: ' + holdMs + ' }', root);
                t.triggered.connect(() => {
                    root.deactivate(name, monitor);
                    t.destroy();
                });
                t.start();
                scopedTimers[timerKey] = t;
            }
            root.holdTimers = scopedTimers;
            root.debounceResolve();
            return;
        }

        const timers = root.holdTimers || {};
        // Cancel existing timer for this state
        if (timers[name]) {
            timers[name].stop();
            timers[name] = null;
        }
        root.holdTimers = timers;

        var next = Object.assign({}, root.activeStates || {});
        next[name] = {
            priority: priority
        };
        root.activeStates = next;

        if (holdMs !== undefined && holdMs > 0) {
            const t = Qt.createQmlObject('import QtQuick; Timer { repeat: false; interval: ' + holdMs + ' }', root);
            t.triggered.connect(() => {
                root.deactivate(name);
                t.destroy();
            });
            t.start();
            timers[name] = t;
        }

        root.debounceResolve();
    }

    // Deactivate a state (default is the permanent base and can't be removed)
    function deactivate(name, monitorName) {
        const capture = Registry.get("capture-session");
        if (capture && capture.active && (capture.desiredState === name
            || (capture.overviewMode && (name === "left" || name === "right"))))
            return;
        if (name === "default")
            return;
        if (root.isMonitorScopedState(name)) {
            const monitor = monitorName || (name === "search" ? root.searchMonitor : "") || Registry.monitorName || "";
            const scopedTimers = root.holdTimers || {};
            const timerKey = name + "@" + monitor;
            if (scopedTimers[timerKey]) {
                scopedTimers[timerKey].stop();
                scopedTimers[timerKey] = null;
            }
            root.holdTimers = scopedTimers;
            var byMonitor = Object.assign({}, root.panelStatesByMonitor || {});
            const local = Object.assign({}, byMonitor[monitor] || {});
            delete local[name];
            if (Object.keys(local).length)
                byMonitor[monitor] = local;
            else
                delete byMonitor[monitor];
            root.panelStatesByMonitor = byMonitor;
            // Keep the last owner while closed: a launcher quick-app closes
            // search before its callback opens a side panel on that monitor.
            root.debounceResolve();
            return;
        }
        if (name === "expanded" || name === "compact") {
            // Migrate legacy base names to default
            var mig = Object.assign({}, root.activeStates || {});
            delete mig[name];
            delete mig["expanded"];
            delete mig["compact"];
            if (Object.keys(mig).length === 0)
                mig["default"] = {
                    priority: root.priority.default
                };
            root.activeStates = mig;
            root.debounceResolve();
            return;
        }

        const timers = root.holdTimers || {};
        if (timers[name]) {
            timers[name].stop();
            timers[name] = null;
        }
        root.holdTimers = timers;

        var next = Object.assign({}, root.activeStates || {});
        delete next[name];
        root.activeStates = next;
        root.debounceResolve();
    }

    // Debounced resolve (100ms)
    function debounceResolve() {
        if (root.debounceTimer) {
            root.debounceTimer.stop();
            root.debounceTimer.destroy();
        }
        const t = Qt.createQmlObject('import QtQuick; Timer { repeat: false; interval: 100 }', root);
        t.triggered.connect(() => {
            root.state = root.resolveState(Registry.monitorName);
            t.destroy();
        });
        t.start();
        root.debounceTimer = t;
    }

    // Reveal bar for a monitor (explicit override wins over
    // the settings-driven auto visibility; conceal deletes the key).
    function revealBar(monitorName) {
        var next = Object.assign({}, root.barShown || {});
        next[monitorName] = true;
        root.barShown = next;
    }

    // Conceal bar for a monitor
    function concealBar(monitorName) {
        var next = Object.assign({}, root.barShown || {});
        delete next[monitorName];
        root.barShown = next;
    }

    // Public API for IPC
    function activateState(name, holdMs, monitorName) {
        root.activate(name, holdMs, monitorName);
    }
    function deactivateState(name, monitorName) {
        root.deactivate(name, monitorName);
    }
    function setBarState(name) {
        root.activate(name);
    }
    // current = override ?? barAutoVisible, then set !current
    function toggleBarShown(monitorName) {
        var shown = root.barShown || {};
        var current = shown[monitorName];
        if (current === undefined)
            current = root.barVisibleFor(monitorName);
        var next = Object.assign({}, shown);
        next[monitorName] = !current;
        root.barShown = next;
    }
    function toggleBar(monitorName) {
        root.toggleBarShown(monitorName);
    }

    // Recording is a single system process, but its indicator belongs only
    // to the monitor where recording started.
    Connections {
        target: ScreenRecorder
        function onIsRecordingChanged() {
            if (ScreenRecorder.isRecording)
                root.activate("recording", 0, ScreenRecorder.targetMonitor || Registry.monitorName);
            else
                root.deactivate("recording", ScreenRecorder.targetMonitor || Registry.monitorName);
        }
        function onTargetMonitorChanged() {
            if (ScreenRecorder.isRecording) {
                for (const monitor of Object.keys(root.panelStatesByMonitor || {}))
                    root.deactivate("recording", monitor);
                root.activate("recording", 0, ScreenRecorder.targetMonitor || Registry.monitorName);
            }
        }
    }

    // Live mirror of the lock/orientation/expanded settings. Without this
    // took effect after a shell restart. Re-locking clears stale
    // per-monitor overrides — otherwise a bar hidden while unlocked stays
    // hidden with no hover strip left to reveal it.
    Connections {
        target: Settings
        function onBarLockChanged() {
            root.lock = Settings.barLock ?? true;
            if (root.lock)
                root.barShown = {};
        }
        function onBarDefaultChanged() {
            root.expanded = Settings.barDefault ?? true;
            root.isDefault = Settings.barDefault ?? true;
        }
        function onBarOrientationChanged() {
            root.orientation = Settings.barOrientation ?? true;
        }
    }

    // Media-item trigger: re-evaluates the island the moment the active
    // player's item identity may have changed (track switch,
    // title/artist/url update, player-list switch). notePlayerUpdate
    // dedupes redundant pushes and drops thumbnail-preview noise.
    // trackChanged fires before the new properties land (postTrackChanged
    // fires after), so both are watched — the stale first pass is a
    // same-key no-op and the follow-up carries the new identity.
    Connections {
        target: root._activePlayer
        function onTrackChanged() {
            root.notePlayerUpdate();
        }
        function onPostTrackChanged() {
            root.notePlayerUpdate();
        }
        function onTrackTitleChanged() {
            root.notePlayerUpdate();
        }
        function onTrackArtistChanged() {
            root.notePlayerUpdate();
        }
        function onMetadataChanged() {
            root.notePlayerUpdate();
        }
    }
}
