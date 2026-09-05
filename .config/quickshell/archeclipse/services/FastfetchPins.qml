pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Port of services/fastfetch.ts — syncs booru pins to fastfetch cache directory
// as rounded WebP images for fastfetch display.
// Uses ImageMagick magick CLI for the roundrectangle composite + WebP conversion.
QtObject {
    id: root

    property string cacheDir: Quickshell.env("HOME") + "/.config/fastfetch/cache"
    readonly property string generatedPrefix: "booru-pin-"
    readonly property int cornerRadiusPercent: 5
    readonly property int debounceMs: 250

    property bool _started: false
    property bool _syncInProgress: false
    property bool _resyncQueued: false
    property string _lastPinsSignature: ""

    property Timer _debounceTimer: Timer {
        interval: root.debounceMs
        repeat: false
        onTriggered: root.runSync()
    }

    // Process for running magick conversions (one at a time, sequential)
    property Process _magickProc: Process {
        property string currentSource: ""
        property string currentCache: ""
        property int pendingCount: 0
        property var expectedPaths: []
        onExited: (code, status) => {
            if (code !== 0)
                console.warn("[FastfetchPins] magick failed for " + currentSource + " exit=" + code)
            _magickProc.processNext()
        }
        function processNext() {
            if (pendingCount <= 0) {
                // Done processing all pins — clean stale files and poke zsh
                root._cleanupStale(root._currentExpectedPaths)
                root._pokeZsh()
                root._syncInProgress = false
                if (root._resyncQueued) {
                    root._resyncQueued = false
                    Qt.callLater(root.runSync)
                }
                return
            }
            pendingCount--
            const item = expectedPaths[pendingCount]
            currentSource = item.src
            currentCache = item.dst
            if (!currentSource || !currentCache) { processNext(); return }
            // Check if source exists and cache already exists
            root._checkFileExists(currentSource, (srcExists) => {
                if (!srcExists) { processNext(); return }
                root._checkFileExists(currentCache, (cacheExists) => {
                    if (cacheExists) { processNext(); return }
                    // Build rounded-corner WebP via ImageMagick
                    const radius = "%[fx:min(w,h)*" + (root.cornerRadiusPercent / 100) + "]"
                    command = [
                        "magick", currentSource,
                        "-alpha", "set",
                        "(", "+clone",
                            "-alpha", "transparent",
                            "-background", "none",
                            "-fill", "white",
                            "-draw", "roundrectangle 0,0,%[fx:w-1],%[fx:h-1]," + radius + "," + radius,
                        ")",
                        "-compose", "Dst_In", "-composite",
                        "-strip",
                        "-quality", "82",
                        "-define", "webp:method=6",
                        "-define", "webp:alpha-quality=90",
                        "-background", "none",
                        currentCache
                    ]
                    running = true
                })
            })
        }
    }

    // Helper: check file existence via test -f
    property Process _existsProc: Process {
        property string checkPath: ""
        property var callback: null
        stdout: StdioCollector {
            onStreamFinished: {
                // test -f returns 0 if exists, 1 if not; onExited handles both
            }
        }
        onExited: (code) => {
            if (root._existsProc.callback) root._existsProc.callback(code === 0)
        }
    }

    function _checkFileExists(path, cb) {
        _existsProc.checkPath = path
        _existsProc.callback = cb
        _existsProc.command = ["test", "-f", path]
        _existsProc.running = true
    }

    property var _currentExpectedPaths: []

    function _cleanupStale(expectedPaths) {
        // List cache dir, remove any booru-pin-* files not in expected set
        _cleanupProc.expectedSet = expectedPaths
        _cleanupProc.cacheDirectory = cacheDir
        _cleanupProc.command = ["ls", cacheDir]
        _cleanupProc.running = true
    }

    property Process _cleanupProc: Process {
        property var expectedSet: []
        property string cacheDirectory: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l.length > 0)
                for (const name of lines) {
                    if (!name.startsWith(root.generatedPrefix) || !name.endsWith(".webp")) continue
                    // Extract pin key from filename: booru-pin-<api>-<id>.webp
                    const nameNoExt = name.replace(/\.webp$/, "")
                    const dashIdx = nameNoExt.indexOf("-")
                    const prefix = nameNoExt.substring(0, dashIdx)
                    const rest = nameNoExt.substring(dashIdx + 1)
                    // Check if this key is in expected set
                    const fullKey = rest  // This is <api>-<id>
                    let found = false
                    for (const ep of parent.parent.expectedSet) {
                        const epKey = ep.key
                        if (epKey) {
                            const epName = root.generatedPrefix + ep.api + "-" + ep.id + ".webp"
                            if (name === epName) { found = true; break }
                        }
                    }
                    if (!found) {
                        root._removeFile(root.cacheDir + "/" + name)
                    }
                }
            }
        }
        onExited: {}
    }

    property Process _removeProc: Process {
        property string targetPath: ""
        onExited: (code) => {
            if (code !== 0)
                console.warn("[FastfetchPins] Failed to remove stale: " + targetPath)
        }
    }

    function _removeFile(path) {
        _removeProc.targetPath = path
        _removeProc.command = ["rm", "-f", path]
        _removeProc.running = true
    }

    // Poke zsh to reload fastfetch cache
    property Process _pokeProc: Process {
        command: ["bash", "-c", "pkill -SIGUSR1 zsh || true"]
        onExited: {}
    }

    function _pokeZsh() {
        _pokeProc.running = true
    }

    function sanitizeSegment(value) {
        return value.replace(/[^a-zA-Z0-9_-]/g, "_")
    }

    function getPinKey(pin) {
        if (typeof pin.id !== "number") return null
        const apiValue = (pin.api || {}).value
        if (typeof apiValue !== "string" || !apiValue) return null
        return pin.id + ":" + apiValue
    }

    function getPinsSignature(pins) {
        const parts = []
        for (const pin of pins) {
            const key = getPinKey(pin)
            if (!key) continue
            parts.push(key + ":" + (pin.extension || ""))
        }
        parts.sort()
        return parts.join("|")
    }

    function getSourcePath(pin) {
        const key = getPinKey(pin)
        if (!key) return null
        const [id, apiValue] = key.split(":")
        if (!id || !apiValue || !pin.extension) return null
        return Quickshell.env("HOME") + "/.config/booru/" + apiValue + "/images/" + id + "." + pin.extension
    }

    function getCachePath(pin) {
        const key = getPinKey(pin)
        if (!key) return null
        const [id, apiValue] = key.split(":")
        if (!id || !apiValue) return null
        return cacheDir + "/" + generatedPrefix + sanitizeSegment(apiValue) + "-" + id + ".webp"
    }

    function syncPinsToFastfetchCache() {
        const pins = (Settings.booru || {}).pins || []
        console.log("[FastfetchPins] Sync requested for " + pins.length + " pins")

        // Build expected paths list
        const expected = []
        for (const pin of pins) {
            const src = getSourcePath(pin)
            const dst = getCachePath(pin)
            const key = getPinKey(pin)
            if (src && dst && key) {
                expected.push({ src: src, dst: dst, key: key, api: (pin.api || {}).value, id: pin.id })
            }
        }

        root._currentExpectedPaths = expected

        // Ensure cache dir exists
        _mkdirProc.command = ["mkdir", "-p", cacheDir]
        _mkdirProc.onExited = (code) => {
            if (code === 0) {
                // Start sequential magick processing
                _magickProc.expectedPaths = expected
                _magickProc.pendingCount = expected.length
                _magickProc.processNext()
            } else {
                console.warn("[FastfetchPins] Failed to create cache dir: " + cacheDir)
                root._syncInProgress = false
            }
        }
        _mkdirProc.running = true
    }

    property Process _mkdirProc: Process {
        onExited: {}
    }

    function runSync() {
        if (root._syncInProgress) {
            root._resyncQueued = true
            return
        }
        root._syncInProgress = true
        syncPinsToFastfetchCache()
    }

    function scheduleSync() {
        _debounceTimer.restart()
    }

    function start() {
        if (root._started) return
        root._started = true
        const pins = (Settings.booru || {}).pins || []
        root._lastPinsSignature = getPinsSignature(pins)
        scheduleSync()

        // Watch for settings changes and re-sync when pins change
        // AGS: globalSettings.subscribe(() => { ... scheduleSync() })
        Settings.booruChanged.connect(function() {
            const pins = (Settings.booru || {}).pins || []
            const sig = root.getPinsSignature(pins)
            if (sig === root._lastPinsSignature) return
            root._lastPinsSignature = sig
            root.scheduleSync()
        })
    }

    Component.onCompleted: start()
}
