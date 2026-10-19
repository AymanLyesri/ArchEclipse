pragma Singleton
import QtQuick

// Workspace icon mapping — port of constants/workspace.constants.ts.
// Maps the main client class on a workspace to a nerd-font icon.
// Glyphs are written as \u{} escapes because some NFP codepoints are
// unassigned in Unicode and get mangled as raw literals.
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

    // Fresh client class for a HyprlandToplevel. `lastIpcObject.class` is
    // stale unless `Hyprland.refreshToplevels()` runs (see HyprlandToplevel
    // docs) so it resolves to ""/extraIcon here — prefer the reactive
    // `wayland.appId` (== class for native Wayland clients), falling back
    // to the IPC snapshot for XWayland (wayland == null).
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

    // small number badge markup — mirrors workspaceNumberBadge()
    function numberBadge(id: int): string {
        return `<span size="x-small" alpha="65%"> ${id}</span>`;
    }
}
