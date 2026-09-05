import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
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
    property int _timerFired: 0
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

        // Notification probe for history/popup QA: "history" -> count + first
        // summary, "popups" -> live toast count, "clear" -> dismiss all.
        function notifDiag(query: string): string {
            try {
                if (query === "history")
                    return "history=" + Notifications.history.length
                        + (Notifications.history.length > 0 ? " first=" + (Notifications.history[0].notif.summary || "?") : "");
                if (query === "popups") return "popups=" + Notifications.popups.length;
                if (query === "clear") { Notifications.clearHistory(); return "cleared"; }
                if (query === "dnd") return "dnd=" + Settings.notifDnd;
                if (query === "dndon") { Settings.updateSetting("notifications.dnd", true); return "dnd=" + Settings.notifDnd; }
                if (query === "dndoff") { Settings.updateSetting("notifications.dnd", false); return "dnd=" + Settings.notifDnd; }
                return "unknown query";
            } catch (e) {
                return "EX: " + e;
            }
        }

        // Bar-state probe for dynamic-island QA: query is "state", or
        // "pulse:<name>:<holdMs>" (e.g. "pulse:volume:2000"), or
        // "on:<name>" / "off:<name>" for persistent states.
        function barDiag(query: string): string {
            try {
                if (query === "state") return BarState.state;
                if (query.startsWith("pulse:")) {
                    const rest = query.substring(6).split(":");
                    BarState.activate(rest[0], Number(rest[1]) || 2000);
                    return "pulsed=" + rest[0] + " state=" + BarState.state;
                }
                if (query.startsWith("on:")) {
                    BarState.activate(query.substring(3));
                    return "on state=" + BarState.state;
                }
                if (query.startsWith("off:")) {
                    BarState.deactivate(query.substring(4));
                    return "off state=" + BarState.state;
                }
                return "unknown query";
            } catch (e) {
                return "EX: " + e;
            }
        }

        // Player probe for MPRIS QA: returns active title|artist|isPlaying
        // using the same playable-player rule as PlayerWidget.
        function playerDiag(): string {
            try {
                let first = null;
                for (const p of Mpris.players.values) {
                    if ((p.trackTitle ?? "").trim() !== ""
                        || p.playbackState === MprisPlaybackState.Playing) {
                        if (p.playbackState === MprisPlaybackState.Playing)
                            return (p.trackTitle || "?") + " | " + (p.trackArtist || "?") + " | playing";
                        if (!first) first = p;
                    }
                }
                if (first) return (first.trackTitle || "?") + " | " + (first.trackArtist || "?") + " | stopped";
                return "no players";
            } catch (e) {
                return "EX: " + e;
            }
        }

        // Timer-pattern probe: replicates BarState's watcher-timer wiring to
        // verify Qt.createQmlObject Timer + onTriggered.connect fires.
        // Call "timerfire" (arms 300ms timer), then "timerread".
        function timerDiag(query: string): string {
            try {
                if (query === "timerfire") {
                    const t = Qt.createQmlObject("import QtQuick; Timer { interval: 300; running: true; repeat: false }", this);
                    t.onTriggered.connect(function() { _timerFired++; });
                    return "armed";
                }
                if (query === "timerread") return "fired=" + _timerFired;
                return "unknown query";
            } catch (e) {
                return "EX: " + e;
            }
        }

        // BarState watcher vitals for dynamic-island QA.
        function vitals(): string {
            try {
                const sink = Pipewire.defaultAudioSink;
                return "volWired=" + BarState._volumeWired
                    + " sinkAudio=" + (!!(sink && sink.audio))
                    + " sink=" + (sink ? (sink.name || sink.description) : "null")
                    + " vol=" + (sink && sink.audio ? sink.audio.volume : -1)
                    + " volEvents=" + BarState.volumeEvents
                    + " brightFirst=" + BarState._brightnessFirstRender
                    + " playerFirst=" + BarState._playerFirstRender
                    + " activePlayer=" + (BarState._activePlayer ? "set" : "null")
                    + " playerPolls=" + BarState.playerPolls
                    + " mprisN=" + (Mpris.players.values ? Mpris.players.values.length : -1)
                    + " netFirst=" + BarState._networkFirstRender
                    + " state=" + BarState.state;
            } catch (e) {
                return "EX: " + e;
            }
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

        // AGS parity (app.tsx requestHandler): toggle stop/start.
        function screenrecord(mode: string): string {
            return ScreenRecorder.toggleRecording(mode);
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
                case "gridSrc": {
                    const imgs = item.images || [];
                    if (!imgs.length) return "no-images";
                    const n = Object.keys(item.previewIds || {}).length;
                    const cols = (item.masonryColumns || []).map(c => c.length).join("/");
                    return `cached=${n} cols=[${cols}] src0=${item.gridSource(imgs[0])}`;
                }
                case "bookmarkCount": return String((Settings.booru.bookmarks || []).length);
                case "pinCount": return String((Settings.booru.pins || []).length);
                case "fetchStatus": return item.progressStatus || "?";
                case "lastFetchCmd": return item.lastFetchCmd || "?";
                case "lastFetchError": return item.lastFetchError || "?";
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
                        // Widget-local `limit` is the source of truth (the
                        // settings slider assigns it directly, so the
                        // Settings binding is one-way). Write the widget
                        // first, then persist — same as the slider handler.
                        const n = Math.max(0, Number(query.substring(9)) || 0);
                        item.limit = n;
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
                if (kind.startsWith("results:")) {
                    const q = kind.substring(8);
                    Launcher.runQuery(q);
                    const r = Launcher.results || [];
                    return `results(${q})=${r.length}: ` + r.slice(0, 4).map(x => x.name).join(" || ");
                }
                return "unknown kind";
            } catch (e) {
                return "ERROR: " + e;
            }
        }
    }
}
