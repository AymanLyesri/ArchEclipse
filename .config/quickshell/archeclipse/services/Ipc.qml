import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme

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

        // Diagnostic: force the network pulse state (mirrors a network change).
        function pulseNetwork(): string {
            BarState.activate("network", 3000);
            return "network state pulsed";
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

        function showWidget(name: string, monitor: string): string {
            const key = `left-panel-${monitor}`;
            const w = Registry.get(key);
            if (w) { w.selectedWidget = name; w.visible = true; return key + " showing " + name; }
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

        // Targeted widget-state probe for parity/QA. `query` is one of:
        //   "selected", "page", "limit", "imagesCount", "imagesIds",
        //   "bookmarkCount", "pinCount", "fetchStatus", "fetchedTags".
        // "setPage" / "setLimit" / "gotoPage" mutate the live widget.
        // "seedBookmarks" / "seedPins" inject test data.
        // "loadBookmarks" / "loadPins" / "fetchApi" trigger the
        // corresponding pagination or API fetch.
        // Returns a stringified value or a result code.
        function widgetState(query: string, monitor: string): string {
            try {
                const w = Registry.get(`left-panel-${monitor}`);
                if (!w) return "no panel";
                const item = w.activeWidget;
                if (!item) return "no widget (selected=" + w.selectedWidget + ")";
                // Debug echo so we can see exactly what the IPC layer delivered.
                // Comment out the early return to keep parity probes.
                if (query === "_debug") {
                    return `query=${JSON.stringify(query)} activeW=${item ? "yes" : "no"}`;
                }
                switch (query) {
                case "selected": return w.selectedWidget;
                case "page": return String(item.page);
                case "limit": return String(item.limit);
                case "imagesCount": return String((item.images || []).length);
                case "imagesIds": return (item.images || []).map(x => x && x.id).filter(Boolean).join(",");
                case "bookmarkCount": return String((Settings.booru.bookmarks || []).length);
                case "pinCount": return String((Settings.booru.pins || []).length);
                case "fetchStatus": return item.progressStatus || "?";
                case "fetchedTags": return (item.fetchedTags || []).slice(0, 5).join(",");
                case "seedBookmarks": {
                    Settings.booru.bookmarks = [1,2,3,4,5].map(i => ({
                        id: String(i),
                        file_url: `http://x/${i}.jpg`,
                        preview_url: `http://x/${i}.jpg`,
                        tags: [`tag${i}`]
                    }));
                    Settings.updateSetting("booru.bookmarks", Settings.booru.bookmarks);
                    return "seeded=" + (Settings.booru.bookmarks || []).length;
                }
                case "seedPins": {
                    Settings.booru.pins = ["a","b","c","d","e","f","g"].map(i => ({
                        id: "p" + i,
                        file_url: `http://y/${i}.jpg`,
                        preview_url: `http://y/${i}.jpg`,
                        tags: [`pt${i}`]
                    }));
                    Settings.updateSetting("booru.pins", Settings.booru.pins);
                    return "seeded=" + (Settings.booru.pins || []).length;
                }
                case "loadBookmarks": {
                    if (typeof item.loadBookmarks === "function") {
                        item.loadBookmarks();
                        const ids = (item.images || []).map(x => x && x.id).filter(Boolean);
                        return `bm(page=${item.page},limit=${item.limit}) -> ${ids.length} ids: ` + ids.join(",");
                    }
                    return "no loadBookmarks";
                }
                case "loadPins": {
                    if (typeof item.loadPins === "function") {
                        item.loadPins();
                        const ids = (item.images || []).map(x => x && x.id).filter(Boolean);
                        return `pins(page=${item.page},limit=${item.limit}) -> ${ids.length} ids: ` + ids.join(",");
                    }
                    return "no loadPins";
                }
                case "fetchApi": {
                    if (typeof item.fetchImages === "function") {
                        item.fetchImages();
                        return "fetchImages called, status=" + (item.progressStatus || "?");
                    }
                    return "no fetchImages";
                }
                default:
                    if (query.startsWith("setPage:")) {
                        // "setPage:5" -> substring(8) = "5"
                        item.page = Math.max(1, Number(query.substring(8)) || 1);
                        return "page=" + item.page;
                    }
                    if (query.startsWith("setLimit:")) {
                        // "setLimit:2" -> substring(9) = "2"
                        // BooruViewer has `limit: Settings.booru.limit` binding,
                        // so write through Settings to stick.
                        const n = Math.max(0, Number(query.substring(9)) || 0);
                        Settings.booru.limit = n;
                        Settings.updateSetting("booru.limit", n);
                        return "limit=" + item.limit;
                    }
                    return "unknown query";
                }
            } catch (e) {
                return "EX: " + e;
            }
        }

        // TEMP diagnostic — exercises launcher query pipeline. Remove after verification.
        function launcherDiag(kind: string): string {
            try {
                if (kind === "emoji") {
                    const r = Launcher.emojiResults("smile");
                    return `emoji(smile)=${r.length}: ` + r.map(x => x.name).join(",");
                }
                if (kind === "clipboard") {
                    const r = Launcher.clipboardResults("verification");
                    return `clipboard(verification)=${r.length}: ` + r.map(x => x.name.slice(0, 40)).join(" || ");
                }
                if (kind === "notes") {
                    const r = Launcher.noteResults("list");
                    return "notes(list)=" + JSON.stringify(r.map(x => x.name));
                }
                if (kind === "recent") {
                    const r = Launcher.recentApps();
                    return "recentApps=" + JSON.stringify(r.map(x => x.name));
                }
                if (kind === "quick") {
                    return "quickAppOrder=" + JSON.stringify(Launcher.quickAppOrder.map(x => x.name));
                }
                if (kind === "conv") {
                    const r = Launcher.tryConversion("10kg in lb");
                    return "10kg in lb -> " + (r ? r.map(x => x.name) : "null");
                }
                if (kind === "arith") {
                    const r = Launcher.tryArithmetic("2+2*3");
                    return "2+2*3 -> " + (r ? r.map(x => x.name) : "null");
                }
                return "unknown kind";
            } catch (e) {
                return "ERROR: " + e;
            }
        }
    }
}
