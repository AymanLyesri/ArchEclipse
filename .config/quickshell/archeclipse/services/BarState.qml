pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
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

        // Cancel existing timer for this state
        if (root.holdTimers[name]) {
            root.holdTimers[name].stop()
            root.holdTimers[name] = null
        }

        root.activeStates[name] = { priority: priority }

        if (holdMs !== undefined) {
            root.holdTimers[name] = Timer.singleShot(holdMs, () => {
                root.deactivate(name)
            })
        }

        root.debounceResolve()
    }

    // Deactivate a state
    function deactivate(name) {
        if (name === "compact") return // base is permanent

        // Don't deactivate expanded if lock is on
        if (name === "expanded" && root.expanded) return

        if (root.holdTimers[name]) {
            root.holdTimers[name].stop()
            root.holdTimers[name] = null
        }

        delete root.activeStates[name]
        root.debounceResolve()
    }

    // Debounced resolve (100ms)
    function debounceResolve() {
        if (root.debounceTimer) {
            root.debounceTimer.stop()
        }
        root.debounceTimer = Timer.singleShot(100, () => {
            root.state = root.resolveState()
        })
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