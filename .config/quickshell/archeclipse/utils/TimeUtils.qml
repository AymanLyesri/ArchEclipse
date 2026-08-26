pragma Singleton
import QtQuick

// Port of utils/time.ts — logging and timing utilities
QtObject {
    id: root

    // Simple timestamp formatter
    function now() {
        return new Date();
    }

    function formatMs(ms) {
        if (ms < 1000) return `${ms.toFixed(2)}ms`;
        if (ms < 60000) return `${(ms / 1000).toFixed(2)}s`;
        return `${(ms / 60000).toFixed(2)}m`;
    }

    // Log execution time of a function
    function logTime(label, fn) {
        const start = Date.now();
        try {
            const result = fn();
            const elapsed = Date.now() - start;
            console.log(`[Time] ${label}: ${formatMs(elapsed)}`);
            return result;
        } catch (e) {
            const elapsed = Date.now() - start;
            console.log(`[Time] ${label}: ${formatMs(elapsed)} (threw)`);
            throw e;
        }
    }

    // For async functions
    function logTimeAsync(label, fn) {
        const start = Date.now();
        return fn().then(result => {
            const elapsed = Date.now() - start;
            console.log(`[Time] ${label}: ${formatMs(elapsed)}`);
            return result;
        }).catch(e => {
            const elapsed = Date.now() - start;
            console.log(`[Time] ${label}: ${formatMs(elapsed)} (threw)`);
            throw e;
        });
    }

    // Format date according to format string (subset of strftime)
    function formatDate(date, format) {
        const p = (n) => n.toString().padStart(2, "0");
        if (format === "%I:%M %p") {
            let h = date.getHours() % 12; if (h === 0) h = 12;
            return `${p(h)}:${p(date.getMinutes())} ${date.getHours() < 12 ? "AM" : "PM"}`;
        }
        // Default %H:%M
        return `${p(date.getHours())}:${p(date.getMinutes())}`;
    }

    // Poll a function at interval (returns a Timer)
    function createPoll(initialValue, intervalMs, callback) {
        const timer = Timer.create({
            interval: intervalMs,
            running: true,
            repeat: true,
            triggeredOnStart: true,
            onTriggered: callback
        });
        return timer;
    }
}