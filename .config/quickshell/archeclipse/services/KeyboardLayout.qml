pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

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

    // Live layout tracking: listen for Hyprland activelayout>> events
    // so the bar reflects keyboard layout changes instantly.
    property Connections _hyprConn: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event?.name !== "activelayout") return;
            // event.data format: "device_name,layout_name"
            const d = event.data ?? "";
            const sep = d.indexOf(",");
            if (sep === -1) return;
            const device = d.slice(0, sep);
            const layoutName = d.slice(sep + 1);
            root.setActiveLayout(layoutName, device);
        }
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

    // Switch process — cycles to the next keymap on the current keyboard.
    // (hyprctl needs -i $HYPRLAND_INSTANCE_SIGNATURE injected — plain
    // hyprctl breaks with multiple Hyprland instances.)
    property Process _switchLayoutProc: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("[KeyboardLayout] Failed to switch layout: " + text);
            }
        }
    }

    function nextLayout() {
        const cmd = ["hyprctl", "switchxkblayout", "current", "next"];
        const signature = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        if (signature)
            cmd.splice(1, 0, "-i", signature);
        root._switchLayoutProc.command = cmd;
        root._switchLayoutProc.running = true;
    }

}