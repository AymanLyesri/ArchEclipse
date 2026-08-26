pragma Singleton
import QtQuick

// Workspace icon mapping — port of constants/workspace.constants.ts.
// Maps the main client class on a workspace to a nerd-font icon.
// Glyphs are written as \u{} escapes because some NFP codepoints are
// unassigned in Unicode and get mangled as raw literals.
QtObject {
    id: root

    readonly property var map: [
        { pattern: /cord$/, icon: "\u{F066F}" },                                  // discord-like
        { pattern: /foot|kitty|alacritty|xterm|gnome-terminal|konsole/i, icon: "\u{F120}" },
        { pattern: /thunar|nautilus|dolphin|ranger/i, icon: "\u{F024B}" },
        { pattern: /chrome|chromium|brave/i, icon: "\u{F268}" },
        { pattern: /firefox|zen/i, icon: "\u{F0239}" },
        { pattern: /vlc/i, icon: "\u{F057C}" },
        { pattern: /spotify|spotube/i, icon: "\u{F1BC}" },
        { pattern: /code|vscode|sublime|jetbrains/i, icon: "\u{E70C}" },
        { pattern: /steam/i, icon: "\u{F11B}" },
        { pattern: /lutris|game|\.exe$/i, icon: "\u{F1B6}" },
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

    // small number badge markup — mirrors workspaceNumberBadge()
    function numberBadge(id: int): string {
        return `<span size="x-small" alpha="65%"> ${id}</span>`;
    }
}
