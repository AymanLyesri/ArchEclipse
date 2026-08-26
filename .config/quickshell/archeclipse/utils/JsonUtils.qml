pragma Singleton
import QtQuick

// Port of utils/json.ts — JSON file read/write helpers
QtObject {
    id: root

    function readFile(path) {
        const file = File.new(path);
        if (!file.exists) return null;
        try {
            const content = file.readAll();
            return JSON.parse(content);
        } catch (e) {
            console.warn(`[JSON] Failed to read ${path}:`, e);
            return null;
        }
    }

    function writeFile(path, obj) {
        try {
            const file = File.new(path);
            file.write(JSON.stringify(obj, null, 2));
            return true;
        } catch (e) {
            console.warn(`[JSON] Failed to write ${path}:`, e);
            return false;
        }
    }

    function safeParse(text, fallback = null) {
        try {
            return JSON.parse(text);
        } catch {
            return fallback;
        }
    }

    function safeStringify(obj, fallback = "{}") {
        try {
            return JSON.stringify(obj);
        } catch {
            return fallback;
        }
    }
}