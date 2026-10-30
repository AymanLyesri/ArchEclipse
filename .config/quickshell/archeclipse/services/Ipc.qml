import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.services
import qs.theme

// Hyprland keybinds reach the bar via `qs ipc`; this object must be instantiated
// (child of ShellRoot) — Quickshell requires non-singleton IpcHandler roots.
Item {
    id: root
    property int _timerFired: 0

    function toggleControlFor(monitorName): string {
        const mon = monitorName || Registry.monitorName;
        if (BarState.stateFor(mon) === "control") {
            BarState.deactivate("control", mon);
            return "control closed";
        }
        BarState.deactivate("wallpaper", mon);
        BarState.activate("control", 0, mon);
        return "control open";
    }

    function toggleWallpaperFor(monitorName): string {
        const mon = monitorName || Registry.monitorName;
        if (BarState.isOpenFor("wallpaper", mon)) {
            BarState.deactivate("wallpaper", mon);
            return "wallpaper closed";
        }
        BarState.activate("wallpaper", 0, mon);
        return "wallpaper open";
    }

    IpcHandler {
        target: "bar"

        function toggleSearch(monitor: string): string {
            if (BarState.isOpenFor("search", monitor)) {
                BarState.deactivate("search", monitor);
                return "search closed";
            }
            // Generic open shows default recents: drop any stale preset so
            // LauncherPanel's reset path isn't hijacked by an old pending.
            Launcher.pendingQuery = "";
            BarState.activate("search", 0, monitor);
            return "search open";
        }

        function toggleControl(): string {
            return root.toggleControlFor(Registry.monitorName);
        }

        function toggleOverview(monitor: string): string {
            if (BarState.isOpenFor("overview", monitor)) {
                BarState.deactivate("overview", monitor);
                return "overview closed";
            }
            BarState.activate("overview", 0, monitor);
            return "overview open";
        }

        function toggleWallpaper(): string {
            return root.toggleWallpaperFor(Registry.monitorName);
        }

        // Diagnostic: force the network pulse state (mirrors a network change).
        function pulseNetwork(monitor: string): string {
            BarState.activate("network", 3000, monitor);
            return "network state pulsed";
        }

        function noteVolumeTarget(monitor: string): string {
            BarState.noteVolumeTarget(monitor);
            return "volume OSD target set";
        }

        // Notification probe for history/popup QA: "history" -> count + first
        // summary, "popups" -> live toast count, "clear" -> dismiss all.
        function notifDiag(query: string): string {
            try {
                if (query === "history")
                    return "history=" + Notifications.history.length
                        + (Notifications.history.length > 0 ? " first=" + (Notifications.history[0].notif.summary || "?") : "");
                if (query === "popups") return "popups=" + Notifications.popupToasts.length;
                if (query === "clear") { Notifications.clearHistory(); return "cleared"; }
                if (query === "dnd") return "dnd=" + Settings.notifDnd;
                if (query === "dndon") { Settings.updateSetting("notifications.dnd", true); return "dnd=" + Settings.notifDnd; }
                if (query === "dndoff") { Settings.updateSetting("notifications.dnd", false); return "dnd=" + Settings.notifDnd; }
                return "unknown query";
            } catch (e) {
                return "EX: " + e;
            }
        }

        // Bar-state QA probe: "state", "pulse:<name>:<holdMs>" (e.g. pulse:volume:2000),
        // or "on:<name>"/"off:<name>" for persistent states.
        function barDiag(query: string): string {
            try {
                if (query === "state") return BarState.state;
                // Live membership: proves a pulse stays active while a higher-priority
                // island wins the resolved state (OSD independence QA).
                if (query === "active") return Object.keys(BarState.activeStatesFor(Registry.monitorName)).join(",");
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

        // Dumps raw MPRIS fields plus every MediaWidget.appIconSource resolution step,
        // so a stuck fallback glyph traces back to its failing layer.
        function playerIconDiag(): string {
            try {
                let target = null;
                for (const p of Mpris.players.values) {
                    if (p.isPlaying) {
                        target = p;
                        break;
                    }
                    if (!target)
                        target = p;
                }
                if (!target)
                    return "no players";
                const de = String(target.desktopEntry ?? "");
                const id = String(target.identity ?? "");
                const bus = String(target.dbusName ?? "");
                let out = "identity=[" + id + "] desktopEntry=[" + de + "] dbus=[" + bus + "]";
                try {
                    out += " DesktopEntries=" + (typeof DesktopEntries !== "undefined" ? "defined" : "UNDEFINED");
                } catch (e) {
                    out += " DesktopEntries=ERR:" + String(e).slice(0, 80);
                }
                let entryIcon = "";
                try {
                    let entry = null;
                    if (de.trim() !== "")
                        entry = DesktopEntries.byId(de.trim()) ?? DesktopEntries.heuristicLookup(de.trim());
                    if (!entry && id.trim() !== "")
                        entry = DesktopEntries.heuristicLookup(id.trim());
                    entryIcon = (entry && entry.icon) || "";
                    out += " entryIcon=[" + entryIcon + "]";
                } catch (e) {
                    out += " entryERR=" + String(e).slice(0, 120);
                }
                const cand = entryIcon !== "" ? entryIcon : (id.trim() !== "" ? id.trim().toLowerCase() : (bus.trim() !== "" ? bus.trim().split(".").pop().toLowerCase() : ""));
                out += " candidate=[" + cand + "]";
                try {
                    out += " iconPath=[" + Quickshell.iconPath(cand, true) + "]";
                } catch (e) {
                    out += " iconPathERR=" + String(e).slice(0, 120);
                }
                return out;
            } catch (e) {
                return "EX: " + e;
            }
        }

        // Replicates BarState's watcher-timer wiring: "timerfire" arms a 300ms timer,
        // "timerread" reports it (Qt.createQmlObject Timer + onTriggered.connect QA).
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
                    + " playerEvents=" + BarState.playerEvents
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
            if (BarState.isOpenFor("left", monitor)) {
                BarState.deactivate("left", monitor);
                return "left island closed";
            }
            BarState.activate("left", 0, monitor);
            return "left island open";
        }

        function toggleRightPanel(monitor: string): string {
            if (BarState.isOpenFor("right", monitor)) {
                BarState.deactivate("right", monitor);
                return "right island closed";
            }
            BarState.activate("right", 0, monitor);
            return "right island open";
        }

        function showWidget(name: string, monitor: string): string {
            const valid = ["UserProfile", "BooruViewer", "ChatBot", "MangaViewer", "SettingsWidget", "CustomScripts", "KeyBinds", "Donations"];
            if (valid.indexOf(name) === -1) return "unknown widget: " + name;
            Settings.setLeftPanelWidgetFor(monitor, name);
            BarState.activate("left", 0, monitor);
            return "left island showing " + name;
        }

        // Toggle stop/start.
        function screenrecord(mode: string, monitor: string): string {
            return ScreenRecorder.toggleRecording(mode, monitor);
        }

        // Presets reset on panel creation/state change, so the query is stashed in
        // Launcher.pendingQuery and consumed after the reset — direct when already open.
        function presetSearch(query: string, monitor: string): string {
            if (BarState.isOpenFor("search", monitor)) {
                Launcher.fillInputRequested(query);
                Launcher.runQuery(query);
            } else {
                Launcher.pendingQuery = query;
                BarState.activate("search", 0, monitor);
            }
            return query;
        }

        function clipboard(monitor: string): string {
            presetSearch("cb ", monitor);
            return "clipboard widget opened";
        }

        function emojis(monitor: string): string {
            presetSearch("emoji ", monitor);
            return "emoji picker opened";
        }

        function notes(monitor: string): string {
            presetSearch("note ", monitor);
            return "notes opened";
        }

        function apps(monitor: string): string {
            presetSearch("apps ", monitor);
            return "apps list opened";
        }

        // Scripted capture helper: fires the same path the search island's Enter key
        // runs (Launcher.activateSelected); the launcher owns the selection highlight.
        function launcherActivate(monitor: string): string {
            try {
                return "activated=" + Launcher.activateSelected();
            } catch (e) {
                return "EX: " + e;
            }
        }

        function launcherRow(monitor: string): string {
            try {
                const r = Launcher.results[Launcher.selectedIndex];
                return "selected=" + Launcher.selectedIndex + " of " + Launcher.results.length + " [" + (r ? r.name : "?") + "]";
            } catch (e) {
                return "EX: " + e;
            }
        }

        // Scripted capture helper: pushes a settings leaf the way QML writers do, since
        // writing settings.json from outside loses the race with the shell's persist.
        function settingsSet(key: string, valueB64: string): string {
            try {
                const value = JSON.parse(Qt.atob(valueB64));
                Settings.updateSetting(key, value);
                return "set " + key;
            } catch (e) {
                return "EX: " + e;
            }
        }

        // Scripted capture helper: primes the ChatBot tab and switches to a session id;
        // the tab Loader may have no item yet, so callers retry after a short delay.
        function chatSession(id: string, monitor: string): string {
            try {
                const mon = (monitor && monitor !== "") ? monitor : Registry.monitorName;
                const isl = Registry.get(`left-island-${mon}`) ?? Registry.get("left-island");
                if (!isl) return "no island: left-island-" + mon;
                Registry.selectLeftTab("ChatBot", undefined, mon);
                const w = isl.activeWidget;
                if (!w || !w.switchToSession) return "chat widget not ready";
                w.loadSessions();
                w.switchToSession(id);
                return "chat session=" + w.activeSessionId;
            } catch (e) {
                return "EX: " + e;
            }
        }

        function togglePanel(name: string, monitor: string): string {
            // MediaWindow keeps one player handle per monitor (media-panel-<mon>); the
            // hypr `togglePanel wallpaper-switcher <mon>` alias must keep working.
            if (name === "wallpaper-switcher")
                return root.toggleWallpaperFor(monitor);
            // Side panels are bar islands now — keep the SUPER+L/R
            // (`togglePanel left-panel <mon>`) bindings working.
            if (name === "left-panel" || name === "leftPanel")
                return toggleLeftPanel(monitor);
            if (name === "right-panel" || name === "rightPanel")
                return toggleRightPanel(monitor);
            // The UserProfile moved into the left island — keep SUPER+ESC
            // opening that profile tab instead of duplicating the lock bind.
            if (name === "user-panel" || name === "userPanel") {
                if (BarState.isOpenFor("left", monitor) && Settings.leftPanelWidgetFor(monitor) === "UserProfile") {
                    BarState.deactivate("left", monitor);
                    return "user profile closed";
                }
                Settings.setLeftPanelWidgetFor(monitor, "UserProfile");
                BarState.activate("left", 0, monitor);
                return "user profile open";
            }
            const key = `${name}-${monitor}`;
            const w = Registry.get(key);
            if (w) { w.visible = !w.visible; return key + " toggled"; }
            return "window not found: " + key;
        }

        // Widget-state QA probe: selected/page/limit/imagesCount/fetchStatus/bookmarkCount,
        // plus setPage/setLimit/gotoPage/seed*/load*/fetchApi mutations.
        function widgetState(query: string, monitor: string): string {
            try {
                const w = Registry.get(`left-island-${monitor}`)
                    ?? Registry.get("left-island");
                if (!w) return "no island (left=" + BarState.isOpenFor("left", monitor) + ")";
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
                case "tags": return (item.currentTags || []).join(",");
                case "dialogSrc": {
                    if (!item.dialogImage) return "no-dialog";
                    const srcFn = (typeof item.dialogSource === "function") ? item.dialogSource(item.dialogImage) : "?";
                    return `id=${item.dialogImage.id} src=${srcFn}`;
                }
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
                    if (query.startsWith("dialog:")) {
                        // "dialog:<id>" -> open the dialog for that image
                        // (exercises fetchOriginal + dialogSource live).
                        const id = String(query.substring(7));
                        const found = (item.images || []).find(x => x && String(x.id) === id);
                        if (!found) return "no-image:" + id;
                        item.dialogImage = found;
                        const src = (typeof item.dialogSource === "function") ? item.dialogSource(found) : "?";
                        return `dialog=${id} src=${src}`;
                    }
                    if (query.startsWith("setPage:")) {
                        // "setPage:5" -> substring(8) = "5"
                        item.page = Math.max(1, Number(query.substring(8)) || 1);
                        return "page=" + item.page;
                    }
                    if (query.startsWith("setTags:")) {
                        // "setTags:a,b" replicates the chip add/remove path:
                        // widget tags + Settings + persist + refetch.
                        const newTags = query.substring(8).split(",").map(s => s.trim()).filter(s => s !== "");
                        item.currentTags = newTags;
                        Settings.booru.tags = newTags;
                        Settings.updateSetting("booru.tags", newTags);
                        if (typeof item.fetchImages === "function") {
                            item.fetchImages();
                            return "tags=" + newTags.join(",") + " refetching";
                        }
                        return "tags=" + newTags.join(",") + " (no fetchImages)";
                    }
                    if (query.startsWith("setLimit:")) {
                        // "setLimit:2" -> substring(9) = "2". The widget-local `limit`
                        // is authoritative (the slider assigns it), so write, then persist.
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

        // Wallpaper QA probe: visible/categories/selected/count/current/progress/view,
        // strip/stripdeep/scrollTo:<x>/setCategory:<name> — the scroll regression hooks.
        function wallpaperDiag(query: string, monitor: string): string {
            try {
                const mon = (monitor && monitor !== "") ? monitor : Registry.monitorName;
                const w = Registry.get(`wallpaper-island-${mon}`)
                    ?? Registry.get("wallpaper-island");
                if (!w) return "no island: wallpaper-island-" + mon + " (island=" + (BarState.stateFor(mon) === "wallpaper") + ")";
                if (query === "visible")
                    return "island=" + (BarState.stateFor(mon) === "wallpaper");
                if (query === "categories") return "categories=" + (w.categories || []).join(",");
                if (query === "selected") return "selected=" + w.selectedCategory;
                if (query === "count") return "count=" + (w.provider === "wallhaven" ? (w.whResults || []).length : (w.selectedWallpapers || []).length);
                if (query === "current") return "current=" + (w.currentWallpapers || []).length;
                if (query === "target") return "target=" + w.targetType + " ws=" + w.selectedWorkspaceId;
                if (query === "progress") return "progress=" + w.progressStatus + " label=" + w.progressText;
                if (query === "provider") return "provider=" + w.provider;
                if (query === "view") return "rows=" + Settings.wallpaperMasonryRows + " size=" + Settings.wallpaperTileSize;
                if (query === "width") {
        // Size chain (island -> clip -> body -> strip): the pill follows the island's
        // implicitWidth, so dump every link to see which width the body actually got.
                    const isl = w.parent ? w.parent.parent : null;
                    return "islW=" + (isl ? Math.round(isl.width) : -1) + " islImplicit=" + (isl ? Math.round(isl.implicitWidth) : -1)
                        + " clipW=" + (w.parent ? Math.round(w.parent.width) : -1)
                        + " bodyW=" + Math.round(w.width) + " bodyImplicit=" + Math.round(w.implicitWidth)
                        + " stripW=" + (w.wallStrip ? Math.round(w.wallStrip.width) : -1);
                }
                if (query === "strip") {
                    const s = w.wallStrip;
                    if (!s) return "strip=NOALIAS";
                    return "stripW=" + Math.round(s.width) + " contentW=" + Math.round(s.contentWidth)
                        + " contentX=" + Math.round(s.contentX) + " dir=" + s.flickableDirection
                        + " maxV=" + s.maximumFlickVelocity + " decel=" + s.flickDeceleration;
                }
                if (query.startsWith("scrollTo:")) {
                    const s2 = w.wallStrip;
                    if (!s2) return "strip=NOALIAS";
                    s2.contentX = Math.max(0, Number(query.substring(9)) || 0);
                    return "x=" + Math.round(s2.contentX) + " cw=" + Math.round(s2.contentWidth);
                }
                if (query === "stripdeep") {
                    const s3 = w.wallStrip;
                    if (!s3) return "strip=NOALIAS";
                    const m = w.localMasonry;
                    if (!m) return "stripdeep=NOMASONRY";
                    let rows = 0, wraps = 0, inWin = 0, zeroX = 0, badX = 0;
                    const samples = [];
                    try {
                        const col = (m.children && m.children.length > 0) ? m.children[0] : null;
                        const rws = col ? (col.children || []) : [];
                        for (let r = 0; r < rws.length; r++) {
                            const row = rws[r];
                            if (!row || row.rowItems === undefined) continue;
                            rows++;
                            const kids = row.children || [];
                            let rc = 0;
                            for (let k = 0; k < kids.length; k++) {
                                const c = kids[k];
                                if (!c || c.cellX === undefined) continue;
                                wraps++;
                                rc++;
                                const x = c.cellX, wd = c.cellW;
                                if (!(x >= 0) && !(x < 0)) badX++;
                                else if (x === 0) zeroX++;
                                if (c.inWindow) inWin++;
                                if (samples.length < 6) samples.push(Math.round(x) + "/" + Math.round(wd) + (c.inWindow ? "*" : ""));
                            }
                            if (r < 4) samples.push("row" + r + "=" + rc);
                        }
                    } catch (e2) { return "stripdeep EXwalk: " + e2; }
                    const asp = (w.localAspect && typeof w.localAspect === "object") ? Object.keys(w.localAspect).length : -1;
                    const mdl = (w.selectedWallpapers || []).length;
                    return "x=" + Math.round(s3.contentX) + " vw=" + Math.round(s3.width)
                        + " cw=" + Math.round(s3.contentWidth) + " rows=" + rows
                        + " wraps=" + wraps + " inWin=" + inWin + " zeroX=" + zeroX + " badX=" + badX
                        + " aspects=" + asp + " model=" + mdl + " [" + samples.join(" ") + "]";
                }
                if (query === "theme") return "dynamicColors=" + Settings.dynamicThemeColors
                    + " variant=" + (GlobalTheme.currentTheme ? "light" : "dark");
                if (query.startsWith("setCategory:")) {
                    Settings.updateSetting("wallpaperSwitcher.category", query.substring(12));
                    return "selected=" + Settings.wallpaperCategory;
                }
                if (query === "show") {
                    BarState.activate("wallpaper", 0, mon); return "shown (island)";
                }
                if (query === "hide") {
                    BarState.deactivate("wallpaper", mon); return "hidden (island)";
                }
                return "unknown query";
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
                if (kind.startsWith("debounced:")) {
                    const q = kind.substring(10);
                    Launcher.runQueryDebounced(q);
                    return "debounced-armed:" + q;
                }
                if (kind === "debouncedRead") {
                    const r = Launcher.results || [];
                    return `debounced(last=${Launcher.lastQuery})=${r.length}: ` + r.slice(0, 4).map(x => x.name).join(" || ");
                }
                return "unknown kind";
            } catch (e) {
                return "ERROR: " + e;
            }
        }

    }

    // Brightness IPC (focused monitor unless "<verb>For <monitor>"): safe at key-repeat
    // rate — Brightness coalesces the slow ddcutil writes, see Brightness.qml.
    IpcHandler {
        target: "brightness"

        function increment(): string {
            return Brightness.increment();
        }

        function incrementFor(monitor: string): string {
            return Brightness.increment(monitor);
        }

        function decrement(): string {
            return Brightness.decrement();
        }

        function decrementFor(monitor: string): string {
            return Brightness.decrement(monitor);
        }

        function adjust(delta: int): string {
            return Brightness.adjust(delta);
        }

        function adjustFor(delta: int, monitor: string): string {
            return Brightness.adjust(delta, monitor);
        }

        function set(percent: int): string {
            return Brightness.setScreen(percent / 100);
        }

        function setFor(percent: int, monitor: string): string {
            return Brightness.setScreen(percent / 100, monitor);
        }

        function get(): string {
            return Brightness.describe();
        }
    }

    IpcHandler {
        target: "clipboard"

        // Fired by `wl-paste --watch` (spawned by ClipboardService at
        // boot) on every copy. Queued, never coalesced.
        function event(): string {
            ClipboardService.onEvent();
            return "clipboard event queued";
        }
    }

    IpcHandler {
        target: "dragOverlay"

        function start(monitor: string, x: real, y: real): string {
            const overlay = Registry.get("drag-overlay-" + monitor);
            if (!overlay)
                return "drag overlay unavailable for " + monitor;
            overlay.startSelection(x, y);
            return "drag overlay started";
        }

        function update(monitor: string, x: real, y: real): string {
            const overlay = Registry.get("drag-overlay-" + monitor);
            if (!overlay)
                return "drag overlay unavailable for " + monitor;
            overlay.updateSelection(x, y);
            return "drag overlay updated";
        }

        function stop(monitor: string): string {
            const overlay = Registry.get("drag-overlay-" + monitor);
            if (!overlay)
                return "drag overlay unavailable for " + monitor;
            overlay.stopSelection();
            return "drag overlay stopped";
        }
    }
}
