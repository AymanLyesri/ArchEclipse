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
    // Side islands (93) sit above pulses/control so an open island isn't
    // yanked away by transient states (no width-spring thrash), but yield to
    // wallpaper/search — deactivating those returns to the still-open island.
    property var priority: {
        "default": 0,
        "recording": 40,
        "volume": 80,
        "brightness": 80,
        "network": 80,
        "player": 80,
        "weather": 80,
        "system": 80,
        "control": 90,
        "left": 93,
        "right": 93,
        "wallpaper": 95,
        "search": 100
    }

    // Active states with hold timers
    property var activeStates: {}

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

    // Open in-bar popovers (tray overflow/menu popups). Guards the
    // hover-leave collapse (while a popup is open).
    property int popupCount: 0
    function holdPopup() {
        root.popupCount++;
    }
    function releasePopup() {
        root.popupCount = Math.max(0, root.popupCount - 1);
    }

    // Hold timers
    property var holdTimers: {}

    // Debounce timer
    property var debounceTimer: null

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

    // Brightness pulse tracking
    property real _lastBrightness: 0
    property bool _brightnessFirstRender: true

    // Player pulse tracking
    property var _activePlayer: null
    property string _playerKey: ""
    property bool _playerFirstRender: true
    property int playerEvents: 0

    // Network pulse tracking
    property var _networkDevice: null
    property bool _networkFirstRender: true
    property var _lastNetSig: {}

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
            root.activate("recording");
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
            root.volumeEvents++;
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

            root.activate("volume", 2000);
        });
    }

    // ===== Brightness watcher (event-driven, like volume) =====
    // The Brightness service watches the kernel backlight file with inotify,
    // so any change — our own sliders or external brightness keys — updates
    // Brightness.screen instantly with zero polling. Pulse on change, exactly
    // like the Pipewire volumesChanged hookup below.
    property Connections _brightnessConn: Connections {
        target: Brightness
        function onScreenChanged() {
            const val = Brightness.screen;
            // Skip the initial notification on mount (first-render guard)
            if (root._brightnessFirstRender) {
                root._brightnessFirstRender = false;
                root._lastBrightness = val;
                return;
            }
            // Ignore spurious notifications where the value didn't change
            if (val === root._lastBrightness)
                return;
            root._lastBrightness = val;

            root.activate("brightness", 2000);
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
        for (const p of Mpris.players.values) {
            if ((p.trackTitle ?? "").trim() !== "" || p.playbackState === MprisPlaybackState.Playing) {
                return p;
            }
        }
        return null;
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

        root.activate("player", 2500);
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
        function primaryDevice() {
            if (!Networking.devices?.values)
                return null;
            for (const d of Networking.devices.values) {
                if (d && d.connected)
                    return d;
            }
            return Networking.devices.values.length > 0 ? Networking.devices.values[0] : null;
        }

        function track(device) {
            if (!device)
                return;
            root._networkDevice = device;

            // Skip first render
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
                root.activate("network", 3000);
        }

        // Poll primary device each 2s for state changes (reactive, no spurious
        // signal churn — NetworkManager events are coalesced here).
        const netTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 2000; running: true; repeat: true }', root);
        netTimer.onTriggered.connect(function () {
            const dev = primaryDevice();
            if (dev !== root._networkDevice) {
                root._networkDevice = dev;
                if (!dev)
                    return;
                // First contact with a new device: don't pulse yet
                root._networkFirstRender = true;
            }
            track(dev);
        });
    }

    // Resolve highest priority active state (default is the base fallback)
    function resolveState(): string {
        var best = "default";
        var bestPriority = -Infinity;
        for (var name in root.activeStates) {
            // Legacy base names resolve to the default state
            var canonical = (name === "expanded" || name === "compact") ? "default" : name;
            var entry = root.activeStates[name];
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
    function activate(name, holdMs) {
        if (name === "expanded" || name === "compact")
            name = "default";
        var priority = root.priority[name];
        if (priority === undefined)
            return;
        // Side islands are mutually exclusive: opening one closes the
        // other so left <-> right switches resolve cleanly (same
        // priority would otherwise leave both active and the winner
        // dependent on object iteration order).
        var rival = name === "left" ? "right" : (name === "right" ? "left" : "");
        if (rival !== "")
            root.deactivate(rival);
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
    function deactivate(name) {
        if (name === "default")
            return;
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
            root.state = root.resolveState();
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
    function activateState(name, holdMs) {
        root.activate(name, holdMs);
    }
    function deactivateState(name) {
        root.deactivate(name);
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

    // Recording watcher (isRecording changes -> activate/deactivate
    // "recording" persistently). ScreenRecorder is a sibling singleton.
    Connections {
        target: ScreenRecorder
        function onIsRecordingChanged() {
            if (ScreenRecorder.isRecording)
                root.activate("recording");
            else
                root.deactivate("recording");
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
