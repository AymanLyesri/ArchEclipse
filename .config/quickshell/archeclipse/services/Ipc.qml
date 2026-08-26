import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Port of app.tsx requestHandler — Hyprland keybinds talk to the bar through
// `qs ipc` instead of `ags request`.
//
//   super+super_l -> qs -p <cfg> ipc call bar toggleSearch
//   super+alt_l   -> qs -p <cfg> ipc call bar togglebar <monitor>
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
    }
}
