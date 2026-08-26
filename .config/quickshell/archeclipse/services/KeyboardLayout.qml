pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Port of services/keyboard-layout.ts — watches Hyprland keyboard layout changes
// and exposes the current layout code (e.g. "US", "DV") and full name.
// Simplified version - uses property Process declarations like SysInfo
QtObject {
    id: root

    property string layout: ""
    property string layoutName: ""
    property var deviceLayouts: ({})

    // Load XKB base.lst for layout code -> description mapping
    property var _layoutCodeMap: ({})
    property bool _codesLoaded: false
    property string _pendingLayoutName: ""

    // Process for loading layout codes
    property Process _loadCodesProc: Process {
        command: ["cat", "/usr/share/X11/xkb/rules/base.lst"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const output = text.trim();
                    const map = {};
                    parseXkbSection(output, "layout", map);
                    parseXkbSection(output, "variant", map);
                    root._layoutCodeMap = map;
                    root._codesLoaded = true;
                    if (root._pendingLayoutName) {
                        setActiveLayout(root._pendingLayoutName);
                        root._pendingLayoutName = "";
                    }
                } catch (e) {
                    console.warn("[KeyboardLayout] Failed to parse base.lst:", e);
                }
            }
        }
    }

    // Process for initial layout
    property Process _initialLayoutProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const devices = JSON.parse(text);
                    const keyboards = devices.keyboards ?? [];
                    const mainKeyboard = keyboards.find(k => k.main) ?? keyboards[0];
                    if (mainKeyboard?.active_keymap) {
                        setActiveLayout(mainKeyboard.active_keymap, mainKeyboard.name);
                    }
                    for (const kb of keyboards) {
                        if (kb.name && kb.name !== mainKeyboard?.name && kb.active_keymap) {
                            setActiveLayout(kb.active_keymap, kb.name);
                        }
                    }
                } catch (e) {
                    console.warn("[KeyboardLayout] Failed to read initial layout:", e);
                }
            }
        }
    }

    Component.onCompleted: {
        root._loadCodesProc.running = true;
        loadInitialLayout();
    }

    function parseXkbSection(text, section, map) {
        const lines = text.split("\n");
        let inSection = false;
        for (const line of lines) {
            if (line === "! " + section) {
                inSection = true;
                continue;
            }
            if (!inSection) continue;
            if (line.startsWith("!")) break;
            const trimmed = line.trim();
            if (trimmed === "") break;
            const spaceIndex = trimmed.indexOf(" ");
            if (spaceIndex === -1) continue;
            const code = trimmed.slice(0, spaceIndex);
            const description = trimmed.slice(spaceIndex + 1).trim();
            if (!map[description]) map[description] = code.toUpperCase();
        }
    }

    function resolveCode(name) {
        return root._layoutCodeMap[name] ?? name.slice(0, 2).toUpperCase();
    }

    function setActiveLayout(rawName, device) {
        const normalized = rawName.trim();
        if (!normalized) return;

        const code = resolveCode(normalized);

        if (device) {
            const next = Object.assign({}, deviceLayouts);
            next[device] = { layout: code, layoutName: normalized };
            root.deviceLayouts = next;
        }

        if (!root._codesLoaded) {
            root._pendingLayoutName = normalized;
            return;
        }

        root.layoutName = normalized;
        root.layout = code;
    }

    function loadInitialLayout() {
        const hyprctl = ["hyprctl", "devices", "-j"];
        const signature = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        if (signature) hyprctl.splice(1, 0, "-i", signature);

        root._initialLayoutProc.command = hyprctl;
        root._initialLayoutProc.running = true;
    }

    function flagEmoji(code) {
        const upper = code.toUpperCase();
        if (upper.length !== 2) return "";
        const REGIONAL_INDICATOR_A = 0x1f1e6;
        const points = [...upper].map(c => REGIONAL_INDICATOR_A + (c.charCodeAt(0) - 65));
        if (!points.every(p => p >= REGIONAL_INDICATOR_A && p <= REGIONAL_INDICATOR_A + 25)) return "";
        return String.fromCodePoint(...points);
    }
}