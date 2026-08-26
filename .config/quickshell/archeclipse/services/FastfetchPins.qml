pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Port of services/fastfetch.ts — syncs booru pins to fastfetch cache directory
// as rounded WebP images for fastfetch display.
// Simplified version - full implementation needs File/Dir APIs
QtObject {
    id: root

    property string cacheDir: Quickshell.env("HOME") + "/.config/fastfetch/cache"
    readonly property string generatedPrefix: "booru-pin-"
    readonly property int cornerRadiusPercent: 5
    readonly property int debounceMs: 250

    property bool _started: false
    property int _debounceTimer: 0
    property bool _syncInProgress: false
    property bool _resyncQueued: false
    property string _lastPinsSignature: ""

    function sanitizeSegment(value) {
        return value.replace(/[^a-zA-Z0-9_-]/g, "_");
    }

    function getPinKey(pin) {
        if (typeof pin.id !== "number") return null;
        const apiValue = pin.api?.value;
        if (typeof apiValue !== "string" || !apiValue) return null;
        return pin.id + ":" + apiValue;
    }

    function getPinsSignature(pins) {
        const parts = [];
        for (const pin of pins) {
            const key = getPinKey(pin);
            if (!key) continue;
            parts.push(key + ":" + (pin.extension ?? ""));
        }
        parts.sort();
        return parts.join("|");
    }

    function syncPinsToFastfetchCache() {
        const pins = Settings.booru?.pins ?? [];
        // TODO: Implement when File/Dir APIs are available
        console.log("[FastfetchPins] Sync requested for " + pins.length + " pins");
    }

    function runSync() {
        if (root._syncInProgress) {
            root._resyncQueued = true;
            return;
        }
        root._syncInProgress = true;
        syncPinsToFastfetchCache();
        root._syncInProgress = false;
        if (root._resyncQueued) {
            root._resyncQueued = false;
            runSync();
        }
    }

    function scheduleSync() {
        if (root._debounceTimer) {
            Timer.stop(root._debounceTimer);
        }
        root._debounceTimer = Timer.create({
            interval: root.debounceMs,
            repeat: false,
            onTriggered: runSync
        });
    }

    function start() {
        if (root._started) return;
        root._started = true;
        const pins = Settings.booru?.pins ?? [];
        root._lastPinsSignature = getPinsSignature(pins);
        scheduleSync();
    }

    Component.onCompleted: start();
}