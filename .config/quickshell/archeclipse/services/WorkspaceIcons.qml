pragma Singleton
import QtQuick
import qs.theme

// Workspace icon mapping (port of constants/workspace.constants.ts) from the main client class;
// glyphs come from the shared Icons registry so every app icon has one home.
QtObject {
    id: root

    readonly property var map: [
        { pattern: /cord$|vesktop/i, icon: Icons.discordApp },
        { pattern: /foot|kitty|alacritty|xterm|gnome-terminal|konsole/i, icon: Icons.terminal },
        { pattern: /thunar|nautilus|dolphin|ranger/i, icon: Icons.folder },
        { pattern: /loupe|eog|gwenview/i, icon: Icons.image },
        { pattern: /chrome|chromium|brave/i, icon: Icons.chrome },
        { pattern: /firefox|zen/i, icon: Icons.firefox },
        { pattern: /vlc/i, icon: Icons.vlc },
        { pattern: /spotify|spotube/i, icon: Icons.spotify },
        { pattern: /vscode|vscodium|visual.?studio.?code/i, icon: Icons.code },
        { pattern: /(^|[._-])code(?:-oss)?($|[._-])/i, icon: Icons.code },
        { pattern: /sublime/i, icon: Icons.sublime },
        { pattern: /pycharm/i, icon: Icons.pycharm },
        { pattern: /webstorm/i, icon: Icons.webstorm },
        { pattern: /intellij|idea/i, icon: Icons.idea },
        { pattern: /jetbrains/i, icon: Icons.jetbrains },
        { pattern: /zed/i, icon: Icons.zed },
        { pattern: /steam/i, icon: Icons.steam },
        { pattern: /lutris|game|\.exe$/i, icon: Icons.game },
        { pattern: /telegram/i, icon: Icons.telegram }
    ]

    readonly property string emptyIcon: Icons.workspaceEmpty     // empty workspaces
    readonly property string extraIcon: Icons.workspaceExtra     // occupied, unmapped class
    readonly property string specialIcon: Icons.specialWorkspace   // special workspace toggle

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
