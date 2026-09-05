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

    // Priority map (compact base 0 < recording 40 < expanded 60 < pulses 80 < search 100)
    property var priority: {
        "compact": 0,
        "recording": 40,
        "expanded": 60,
        "volume": 80,
        "brightness": 80,
        "network": 80,
        "player": 80,
        "search": 100
    }

    // Active states with hold timers
    property var activeStates: {}

    // Bar shown overrides (per monitor)
    property var barShown: {}

    // Hyprland tick for reactive deps
    property int hyprlandTick: 0
    property var _tickTimer: null

    // Geometric room-check results per monitor name (matches AGS barBlocked).
    // Populated by _roomProc from `hyprctl j/clients` + `hyprctl j/monitors`.
    property var blockedMonitors: {}
    // Current bar height used for the band check (matches AGS currentBarHeight)
    property int barHeight: 34

    // Current resolved state
    property string state: "compact"

    // Hold timers
    property var holdTimers: {}

    // Debounce timer
    property var debounceTimer: null

    // Settings reference
    property var settings: qs.theme.Settings

    // Lock setting (from settings)
    property bool lock: true
    property bool expanded: false
    property bool orientation: true
    property bool smartHide: false
    property bool fullWidth: false

    // Volume pulse tracking
    property real _lastVolume: 0
    property bool _volumeFirstRender: true

    // Brightness pulse tracking
    property real _lastBrightness: 0
    property bool _brightnessFirstRender: true

    // Player pulse tracking
    property var _activePlayer: null
    property bool _playerFirstRender: true

    // Network pulse tracking
    property var _networkDevice: null
    property bool _networkFirstRender: true
    property var _lastNetSig: {}

    // Volume watcher
    property PwObjectTracker _volumeTracker: PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Component.onCompleted: {
        root.settings = Settings
        root.lock = Settings.barLock ?? true
        root.expanded = Settings.barExpanded ?? false
        root.orientation = Settings.barOrientation ?? true
        root.smartHide = Settings.barSmartHide ?? false
        root.fullWidth = Settings.barFullWidth ?? false

        root.activeStates = {
            compact: { priority: root.priority.compact }
        }
        if (root.expanded) {
            root.activate("expanded", 0)
        }

        // Setup volume watcher (pipewire sink)
        setupVolumeWatcher()
        // Setup brightness watcher
        setupBrightnessWatcher()
        // Setup MPRIS player watcher
        setupPlayerWatcher()
        // Setup network watcher
        setupNetworkWatcher()

        // Hyprland event tick — re-evaluates the geometric smart-hide room
        // check when clients move/resize (client moves don't re-emit a
        // change to the static toplevel list, so we tick on the raw event
        // stream, debounced, exactly like AGS Bar.tsx).
        Hyprland.rawEvent.connect((event) => {
            if (!root._tickTimer) {
                root._tickTimer = Qt.createQmlObject('import QtQuick; Timer { repeat: false; interval: 100 }', root)
                root._tickTimer.triggered.connect(() => {
                    root._tickTimer = null
                    root.hyprlandTick++
                    root.updateRoomCheck()
                })
                root._tickTimer.start()
            }
        })

        // Initial room check
        root.updateRoomCheck()
    }

    // -----------------------------------------------------------------
    // Geometric smart-hide room check (AGS barBlocked).
    // A client "blocks" the bar band if it overlaps the top/bottom barHeight
    // pixels of a monitor on the monitor's active workspace. Queried from
    // hyprctl so geometry is always current (client .at/.size in the cached
    // toplevel list lags behind moves/resizes, exactly as AGS notes).
    // -----------------------------------------------------------------
    property var _roomClientText: ""
    property var _roomMonitorText: ""

    function updateRoomCheck() {
        const pc = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        pc.command = ["hyprctl", "clients", "-j"]
        pc.running = true
        pc.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root)
        pc.stdout.onStreamFinished.connect(() => {
            root._roomClientText = pc.stdout.text
            root.finishRoomCheck()
        })
    }

    function finishRoomCheck() {
        // Query monitors only after clients arrive; then compute blockage.
        const pm = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        pm.command = ["hyprctl", "monitors", "-j"]
        pm.running = true
        pm.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root)
        pm.stdout.onStreamFinished.connect(() => {
            root.computeRoomCheck(root._roomClientText, pm.stdout.text)
        })
    }

    function computeRoomCheck(clientsText, monitorsText) {
        let clients = []
        let monitors = []
        try { clients = JSON.parse(clientsText) } catch(e) { return }
        try { monitors = JSON.parse(monitorsText) } catch(e) { return }

        const blocked = {}
        const onTop = root.orientation
        const h = root.barHeight

        for (const m of monitors) {
            if (!m || m.name === undefined) continue
            const wsId = m.activeWorkspace?.id
            if (wsId === undefined) { blocked[m.name] = false; continue }
            const bandStart = onTop ? m.y : m.y + m.height - h
            const bandEnd = bandStart + h
            const hit = clients.some((c) => {
                if (!c || !c.mapped) return false
                if (c.workspace?.id !== wsId) return false
                const top = c.at?.[1] ?? 0
                const bottom = top + (c.size?.[1] ?? 0)
                return bottom > bandStart && top < bandEnd
            })
            blocked[m.name] = hit
        }
        root.blockedMonitors = blocked
        // [RoomCheck] diagnostic — verify geometric smart-hide computes
        console.log("[RoomCheck] monitors:", JSON.stringify(blocked))
    }

    // AGS barAutoVisible core: lock => always visible; else smart-hide =>
    // visible iff nothing geometrically overlaps the bar band.
    function barVisibleFor(monitorName) {
        if (root.lock) return true
        if (!root.smartHide) return false
        return !(root.blockedMonitors[monitorName] ?? false)
    }

    // ===== Volume watcher =====
    function setupVolumeWatcher() {
        const sink = Pipewire.defaultAudioSink
        if (!sink) return

        // Skip first render
        if (root._volumeFirstRender) {
            root._volumeFirstRender = false
            root._lastVolume = sink.audio?.volume ?? 0
            return
        }

        sink.volumesChanged.connect(() => {
            if (!sink.audio) return
            const vol = sink.audio.volume
            if (isNaN(vol) || vol < 0 || vol > 1) return

            // Ignore spurious notifications
            if (vol === root._lastVolume) return
            root._lastVolume = vol

            root.activate("volume", 2000)
        })
    }

    // ===== Brightness watcher =====
    function setupBrightnessWatcher() {
        // Use a timer to poll brightness directly via brightnessctl (same as Brightness service)
        const timer = Qt.createQmlObject('import QtQuick; Timer { interval: 2000; running: true; repeat: true }', root)
        timer.onTriggered.connect(function() {
            const proc = Qt.createQmlObject('import Quickshell.Io; Process { command: ["brightnessctl", "-m", "info"] }', root)
            proc.running = true
            proc.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', root)
            proc.stdout.onStreamFinished.connect(function() {
                const text = proc.stdout.text
                const lines = text.trim().split("\n")
                if (lines.length > 0) {
                    const fields = lines[0].split(",")
                    if (fields.length >= 4) {
                        const current = parseInt(fields[2]) || 0
                        const max = parseInt(fields[3]) || 1
                        const val = current / max
                        if (root._brightnessFirstRender) {
                            root._brightnessFirstRender = false
                            root._lastBrightness = val
                            return
                        }
                        if (val !== root._lastBrightness) {
                            root._lastBrightness = val
                            root.activate("brightness", 2000)
                        }
                    }
                }
            })
        })
    }

    // ===== MPRIS player watcher =====
    function setupPlayerWatcher() {
        // Find first playable player
        function findPlayablePlayer() {
            for (const p of Mpris.players.values) {
                if ((p.trackTitle ?? "").trim() !== "" || p.playbackState === MprisPlaybackState.Playing) {
                    return p
                }
            }
            return null
        }

        // Watch for player changes using a timer since QtObject properties don't auto-emit signals
        const playerTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 2000; running: true; repeat: true }', root)
        playerTimer.onTriggered.connect(function() {
            const player = findPlayablePlayer()
            if (!player) return

            // Skip first render
            if (root._playerFirstRender) {
                root._playerFirstRender = false
                root._activePlayer = player
                return
            }

            // Ignore if same player and no title change
            if (root._activePlayer === player && player.trackTitle === root._activePlayer?.trackTitle) {
                return
            }
            root._activePlayer = player

            root.activate("player", 2500)
        })
    }

    // ===== Network watcher =====
    // Mirrors AGS NetworkWidget.tsx: pulses the bar-wide "network" state for
    // ~3s whenever the active network connection changes (wifi connect,
    // disconnect, ssid change, signal re-association).
    function setupNetworkWatcher() {
        function primaryDevice() {
            if (!Networking.devices?.values) return null
            for (const d of Networking.devices.values) {
                if (d && d.connected) return d
            }
            return Networking.devices.values.length > 0 ? Networking.devices.values[0] : null
        }

        function track(device) {
            if (!device) return
            root._networkDevice = device

            // Skip first render
            if (root._networkFirstRender) {
                root._networkFirstRender = false
                root._lastNetSig = {
                    state: device.state,
                    connected: device.connected
                }
                return
            }

            const changed = device.connected !== root._lastNetSig.connected ||
                            device.state !== root._lastNetSig.state

            root._lastNetSig = {
                state: device.state,
                connected: device.connected
            }
            if (changed) root.activate("network", 3000)
        }

        // Poll primary device each 2s for state changes (reactive, no spurious
        // signal churn — NetworkManager events are coalesced here).
        const netTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 2000; running: true; repeat: true }', root)
        netTimer.onTriggered.connect(function() {
            const dev = primaryDevice()
            if (dev !== root._networkDevice) {
                root._networkDevice = dev
                if (!dev) return
                // First contact with a new device: don't pulse yet
                root._networkFirstRender = true
            }
            track(dev)
        })
    }

    // Resolve highest priority active state
    function resolveState(): string {
        var best = "compact"
        var bestPriority = -Infinity
        for (var name in root.activeStates) {
            var entry = root.activeStates[name]
            if (entry.priority > bestPriority) {
                best = name
                bestPriority = entry.priority
            }
        }
        return best
    }

    // Activate a state (with optional holdMs for auto-deactivate)
    function activate(name, holdMs) {
        var priority = root.priority[name]
        if (priority === undefined) return

        const timers = root.holdTimers || {}
        // Cancel existing timer for this state
        if (timers[name]) {
            timers[name].stop()
            timers[name] = null
        }
        root.holdTimers = timers

        root.activeStates = root.activeStates || {}
        root.activeStates[name] = { priority: priority }

        if (holdMs !== undefined) {
            const t = Qt.createQmlObject('import QtQuick; Timer { repeat: false; interval: ' + holdMs + ' }', root)
            t.triggered.connect(() => {
                root.deactivate(name)
                t.destroy()
            })
            t.start()
            timers[name] = t
        }

        root.debounceResolve()
    }

    // Deactivate a state
    function deactivate(name) {
        if (name === "compact") return // base is permanent

        // Don't deactivate expanded if lock is on
        if (name === "expanded" && root.expanded) return

        const timers = root.holdTimers || {}
        if (timers[name]) {
            timers[name].stop()
            timers[name] = null
        }
        root.holdTimers = timers

        root.activeStates = root.activeStates || {}
        delete root.activeStates[name]
        root.debounceResolve()
    }

    // Debounced resolve (100ms)
    function debounceResolve() {
        if (root.debounceTimer) {
            root.debounceTimer.stop()
            root.debounceTimer.destroy()
        }
        const t = Qt.createQmlObject('import QtQuick; Timer { repeat: false; interval: 100 }', root)
        t.triggered.connect(() => {
            root.state = root.resolveState()
            t.destroy()
        })
        t.start()
        root.debounceTimer = t
    }

    // Reveal bar for a monitor
    function revealBar(monitorName) {
        root.barShown[monitorName] = true
    }

    // Conceal bar for a monitor
    function concealBar(monitorName) {
        delete root.barShown[monitorName]
    }

    // Public API for IPC
    function activateState(name, holdMs) { root.activate(name, holdMs) }
    function deactivateState(name) { root.deactivate(name) }
    function setBarState(name) { root.activate(name, 0) }
    function toggleBarShown(monitorName) {
        root.barShown[monitorName] = !(root.barShown[monitorName] ?? false)
    }
    function toggleBar(monitorName) { root.toggleBarShown(monitorName) }
}