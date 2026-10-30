pragma Singleton
import QtQuick

// Workspace icon mapping (port of constants/workspace.constants.ts) from the main
// client class; glyphs are \u{} escapes because some NFP codepoints break as literals.
QtObject {
    id: root

    readonly property var map: [
        { pattern: /cord$|vesktop/i, icon: "\u{F066F}" },
        { pattern: /foot|kitty|alacritty|xterm|gnome-terminal|konsole/i, icon: "\u{F120}" },
        { pattern: /thunar|nautilus|dolphin|ranger/i, icon: "\u{F024B}" },
        { pattern: /loupe|eog|gwenview/i, icon: "\u{F03E}" },
        { pattern: /chrome|chromium|brave/i, icon: "\u{F268}" },
        { pattern: /firefox|zen/i, icon: "\u{F0239}" },
        { pattern: /vlc/i, icon: "\u{F057C}" },
        { pattern: /spotify|spotube/i, icon: "\u{F1BC}" },
        { pattern: /vscode|vscodium|visual.?studio.?code/i, icon: "\u{E8DA}" },
        { pattern: /(^|[._-])code(?:-oss)?($|[._-])/i, icon: "\u{E8DA}" },
        { pattern: /sublime/i, icon: "\u{E7AA}" },
        { pattern: /pycharm/i, icon: "\u{E877}" },
        { pattern: /webstorm/i, icon: "\u{E8E4}" },
        { pattern: /intellij|idea/i, icon: "\u{E7B5}" },
        { pattern: /jetbrains/i, icon: "\u{E808}" },
        { pattern: /zed/i, icon: "\u{EAC4}" },
        { pattern: /steam/i, icon: "\u{F1B6}" },
        { pattern: /lutris|game|\.exe$/i, icon: "\u{F11B}" },
        { pattern: /telegram/i, icon: "\u{F2C6}" }
    ]

    readonly property string emptyIcon: "\u{EABC}"     // empty workspaces
    readonly property string extraIcon: "\u{F10C}"     // occupied, unmapped class
    readonly property string specialIcon: "\u{F303}"   // special workspace toggle

    function forClientClass(clientClass: string): string {
        const n = (clientClass || "").toLowerCase();
        for (const entry of map)
            if (entry.pattern.test(n)) return entry.icon;
        return extraIcon;
    }

    // `lastIpcObject.class` is stale without Hyprland.refreshToplevels(), so prefer
    // wayland.appId (== class for Wayland) and fall back to IPC only for XWayland.
    function classForToplevel(t: var): string {
        if (!t)
            return "";
        try {
            const appId = ((t.wayland?.appId ?? "") + "").trim();
            if (appId !== "")
                return appId;
        } catch (e) {}
        try {
            const c = ((t.lastIpcObject?.class ?? "") + "").trim();
            if (c !== "")
                return c;
        } catch (e) {}
        return "";
    }

    function forToplevel(t: var): string {
        return forClientClass(classForToplevel(t));
    }

}
