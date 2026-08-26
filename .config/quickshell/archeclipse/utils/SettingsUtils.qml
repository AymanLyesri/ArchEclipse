pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Port of utils/settings.ts — settings file management and auto-creation
QtObject {
    id: root

    readonly property string settingsPath: `${Quickshell.env("HOME")}/.config/ags/cache/settings/settings.json`
    readonly property string settingsDir: `${Quickshell.env("HOME")}/.config/ags/cache/settings`

    function ensureSettingsDir() {
        Dir.makePath(settingsDir);
    }

    function readSettings() {
        ensureSettingsDir();
        const file = File.new(settingsPath);
        if (!file.exists) return null;
        try {
            const content = file.readAll();
            return JSON.parse(content);
        } catch (e) {
            console.warn("[Settings] Failed to read settings:", e);
            return null;
        }
    }

    function writeSettings(obj) {
        ensureSettingsDir();
        const file = File.new(settingsPath);
        try {
            file.write(JSON.stringify(obj, null, 2));
            return true;
        } catch (e) {
            console.warn("[Settings] Failed to write settings:", e);
            return false;
        }
    }

    // Deep set a value by dot-notation path
    function setValue(obj, path, value) {
        const keys = path.split(".");
        let current = obj;
        for (let i = 0; i < keys.length - 1; i++) {
            if (!current[keys[i]]) current[keys[i]] = {};
            current = current[keys[i]];
        }
        current[keys[keys.length - 1]] = value;
    }
}