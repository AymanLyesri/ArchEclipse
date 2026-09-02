import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Port of app.tsx requestHandler — Hyprland keybinds talk to the bar through
// `qs ipc` instead of `ags request`.
//
//   super+super_l -> qs -p <cfg> ipc call bar toggleSearch
//   super+alt_l   -> qs -p <cfg> ipc call bar toggleBar <monitor>
//   super+l       -> qs -p <cfg> ipc call bar toggleLeftPanel <monitor>
//   super+r       -> qs -p <cfg> ipc call bar toggleRightPanel <monitor>
//
// This object must be instantiated (it's a child of ShellRoot in shell.qml,
// not a singleton — Quickshell requires non-singleton IpcHandler roots).
Item {
    IpcHandler {
        target: "bar"

        function toggleSearch(): string {
            if (BarState.state === "search") {
                BarState.deactivate("search");
                return "search closed";
            }
            BarState.activate("search", 0);
            return "search open";
        }

        function toggleBar(monitor: string): string {
            BarState.toggleBarShown(monitor);
            return "bar toggled";
        }

        function toggleLeftPanel(monitor: string): string {
            const key = `left-panel-${monitor}`;
            const w = Registry.get(key);
            if (w) { w.visible = !w.visible; return key + " toggled"; }
            return "window not found: " + key;
        }

        function toggleRightPanel(monitor: string): string {
            const key = `right-panel-${monitor}`;
            const w = Registry.get(key);
            if (w) { w.visible = !w.visible; return key + " toggled"; }
            return "window not found: " + key;
        }

        function screenrecord(mode: string): string {
            const script = Quickshell.env("HOME") + "/.config/hypr/scripts/screenrecord.sh";
            const arg = mode === "area" ? "start --area" : "start";
            Quickshell.execDetached([script, arg]);
            return "recording " + mode;
        }

        function clipboard(): string {
            Launcher.runQuery("cb ");
            BarState.activate("search", 0);
            return "clipboard widget opened";
        }

        function emojis(): string {
            Launcher.runQuery("emoji ");
            BarState.activate("search", 0);
            return "emoji picker opened";
        }

        function notes(): string {
            Launcher.runQuery("note ");
            BarState.activate("search", 0);
            return "notes opened";
        }

        function apps(): string {
            Launcher.runQuery("apps ");
            BarState.activate("search", 0);
            return "apps list opened";
        }

        function togglePanel(name: string, monitor: string): string {
            const key = `${name}-${monitor}`;
            const w = Registry.get(key);
            if (w) { w.visible = !w.visible; return key + " toggled"; }
            return "window not found: " + key;
        }
    }
}
