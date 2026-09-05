pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Port of widgets/applauncher + utilities: query parsing pipeline and results.
//
// Query grammar (mirrors AGS handleEntryChanged / parse*Query):
//   cb ...            clipboard history  (search cache/launcher/clipboard-history.json)
//   note ...          notes CRUD          (list/add/edit <n>/del <n> over cache/launcher/notes.json)
//   apps ...          list all apps
//   emoji ...         emoji search        (search assets/emojis/emojis.json)
//   translate <t> > <lang>  translate via AGS scripts/translate.sh
//   N unit in/unit M  unit conversion     (full table incl. speed/digital/temp)
//   arithmetic        ..*/+-..
//   URL               open link
//   "name > args"     custom commands filtered
//   fallback          fuzzy app search (DesktopEntries), then terminal hint
//
// Data files are the SAME ones AGS reads/writes (source of truth) so launcher
// state (history, notes, clipboard, quick-apps) is shared with AGS.

QtObject {
    id: root

    readonly property int maxItems: 10
    readonly property string historyPath: `${Quickshell.env("HOME")}/.config/ags/cache/launcher/app-history.json`
    readonly property string notesPath: `${Quickshell.env("HOME")}/.config/ags/cache/launcher/notes.json`
    readonly property string clipboardPath: `${Quickshell.env("HOME")}/.config/ags/cache/launcher/clipboard-history.json`
    readonly property string emojisPath: `${Quickshell.env("HOME")}/.config/ags/assets/emojis/emojis.json`
    readonly property string quickAppHistoryPath: `${Quickshell.env("HOME")}/.config/ags/cache/launcher/quick-app-history.json`

    property var results: []
    property int selectedIndex: 0
    property string lastQuery: ""

    // launch history persisted to AGS app-history.json
    property FileView _historyFile: FileView { path: root.historyPath; watchChanges: false; printErrors: false }
    property var history: {
        try { return JSON.parse(_historyFile.text() || "[]"); } catch (e) { return []; }
    }
    function touchHistory(name) {
        let h = history.filter(n => n !== name);
        h.unshift(name);
        h = h.slice(0, 10);
        _historyFile.setText(JSON.stringify(h));
        history = h;
    }

    // ---- recent apps (AppHistory) — names from app-history.json that resolve to DesktopEntries ----
    function recentApps() {
        const entries = [];
        const appsByName = {};
        for (const e of DesktopEntries.applications.values) {
            if (!e.noDisplay) appsByName[e.name] = e;
        }
        for (const name of history) {
            const e = appsByName[name];
            if (e) entries.push(mkResult(e.name, e.icon ? `image://icon/${e.icon}` : "", e.comment || "", () => { e.execute(); touchHistory(e.name); }));
        }
        return entries;
    }

    // ---- QuickApps (favorites — mirrors AGS constants/app.constants.ts quickApps) ----
    function openLeftPanelTab(selector) {
        // Mirror AGS QuickApps "Keybinds": open the left panel and switch tab.
        if (typeof Registry !== "undefined" && Registry.selectLeftTab) {
            Registry.selectLeftTab(selector);
        }
    }

    function quickAppsList() {
        return [
            mkResult("Keybinds", "\u{F13AA}", "View or edit your Hyprland keybinds", () => openLeftPanelTab("KeyBinds")),
            mkResult("Browser", "\u{F1578}", "Open your default web browser", () => Quickshell.execDetached(["xdg-open", "http://www.google.com"])),
            mkResult("Terminal", "\u{F1204}", "Open a new terminal window", () => Quickshell.execDetached(["kitty"])),
            mkResult("Files", "\u{F1538}", "Open your file manager", () => Quickshell.execDetached(["bash", "-c", `${Quickshell.env("HOME")}/.config/hypr/scripts/filemanager.sh || xdg-open .`])),
            mkResult("Calculator", "\u{F1784}", "Open the calculator", () => Quickshell.execDetached(["kitty", "bc"])),
            mkResult("Text Editor", "\u{F1214}", "Open your default text editor", () => Quickshell.execDetached(["code"])),
        ]
    }

    // QuickApps ordered by quick-app-history (mirrors QuickApps.tsx sortQuickAppsByHistory)
    property var quickAppOrder: []
    property FileView _qaFile: FileView { path: root.quickAppHistoryPath; watchChanges: false; printErrors: false }
    function refreshQuickApps() {
        let qaHistory;
        try { qaHistory = JSON.parse(_qaFile.text() || "[]"); } catch (e) { qaHistory = []; }
        if (!Array.isArray(qaHistory)) qaHistory = [];
        const qapps = quickAppsList();
        const rank = new Map(qaHistory.map((n, i) => [n, i]));
        const names = new Set(qapps.map(a => a.name));
        const valid = qaHistory.filter(n => names.has(n));
        if (valid.length !== qaHistory.length) _qaFile.setText(JSON.stringify(valid));
        const ordered = [...qapps].sort((a, b) => {
            const ar = rank.get(a.name) ?? Number.POSITIVE_INFINITY;
            const br = rank.get(b.name) ?? Number.POSITIVE_INFINITY;
            if (ar === br) return qapps.indexOf(a) - qapps.indexOf(b);
            return ar - br;
        });
        quickAppOrder = ordered;
    }
    function touchQuickApp(name) {
        const names = new Set(quickAppsList().map(a => a.name));
        if (!names.has(name)) return;
        let h;
        try { h = JSON.parse(_qaFile.text() || "[]"); } catch (e) { h = []; }
        if (!Array.isArray(h)) h = [];
        const next = [name, ...h.filter(n => n !== name)];
        _qaFile.setText(JSON.stringify(next));
        refreshQuickApps();
    }
    Component.onCompleted: refreshQuickApps()

    function selectNext(dir) {
        if (!results.length) return;
        // AGS skips header rows when navigating (while list[next].app_type === "header")
        const start = selectedIndex;
        let next = start;
        do {
            next = (next + dir + results.length) % results.length;
        } while (results[next] && results[next].isHeader && next !== start);
        selectedIndex = next;
    }

    function activateSelected() {
        const r = results[selectedIndex];
        if (r && r.launch) r.launch();
    }

    // ---- result row factory ----
    function mkResult(name, icon, description, launch, argText) {
        return { name, icon, description, launch, argText: argText || "" };
    }
    // header row factory (AGS app_type === "header")
    function mkHeader(name) {
        return { name, isHeader: true };
    }

    // ---- app search over DesktopEntries (tiered like AGS rankApps) ----
    function isSubseq(q, target) {
        let i = 0;
        for (const ch of target) { if (ch === q[i]) i++; if (i === q.length) return true; }
        return i === q.length;
    }
    function scoreEntry(e, q) {
        const name = (e.name || "").toLowerCase();
        if (name === q) return 1000;
        if (name.startsWith(q)) return 900;
        if (name.split(/[\s\-_]+/).some(w => w.startsWith(q))) return 800;
        if (name.includes(q)) return 600;
        if (isSubseq(q, name)) return 400;
        const meta = `${e.entry || ""} ${e.executable || ""} ${e.comment || ""}`.toLowerCase();
        if (meta.includes(q)) return 200;
        return 0;
    }

    function appResults(query, withArgs) {
        const q = query.toLowerCase().trim();
        const entries = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        const scored = [];
        for (const e of entries) {
            // AGS parity: bare "apps" lists everything (history-first);
            // scored search otherwise.
            const s = q ? scoreEntry(e, q) : 1;
            if (s > 0) scored.push({ e, s });
        }
        scored.sort((a, b) => {
            const ha = history.indexOf(a.e.name), hb = history.indexOf(b.e.name);
            const ba = ha >= 0 ? Math.max(48 - ha * 8, 8) : 0;
            const bb = hb >= 0 ? Math.max(48 - hb * 8, 8) : 0;
            return (b.s + bb) - (a.s + ba) || a.e.name.localeCompare(b.e.name);
        });
        return scored.slice(0, maxItems).map(({ e }) => {
            const entry = e;
            return mkResult(entry.name, entry.icon ? `image://icon/${entry.icon}` : "", entry.comment || "", () => {
                if (withArgs && withArgs.length > 0)
                    Quickshell.execDetached(["sh", "-c", `${entry.command} ${withArgs.join(" ")}`]);
                else
                    entry.execute();
                touchHistory(entry.name);
            }, withArgs ? withArgs.join(" ") : "");
        });
    }

    // ---- custom commands (mirrors AGS constants/app.constants.ts customApps) ----
    function customCommandsList() {
        return [
            mkResult("Light Theme", "\u{F1042}", "Switch to light theme", () => Quickshell.execDetached(["bash", "-c", `${Quickshell.env("HOME")}/.config/hypr/theme/scripts/system-theme.sh switch light`])),
            mkResult("Dark Theme", "\u{F1046}", "Switch to dark theme", () => Quickshell.execDetached(["bash", "-c", `${Quickshell.env("HOME")}/.config/hypr/theme/scripts/system-theme.sh switch dark`])),
            mkResult("System Sleep", "\u{F1046}", "Suspend system", () => Quickshell.execDetached(["bash", "-c", `${Quickshell.env("HOME")}/.config/hypr/scripts/hyprlock.sh suspend`])),
            mkResult("System Restart", "\u{F1781}", "Reboot system", () => Quickshell.execDetached(["reboot"])),
            mkResult("System Shutdown", "\u{F1741}", "Power off system", () => Quickshell.execDetached(["shutdown", "now"]))
        ]
    }

    // ---- unit conversion (full table — mirrors AGS utils/convert.ts) ----
    function tryConversion(text) {
        const m = text.match(/^(?:convert\s+)?(\d+(?:\.\d+)?)\s*([a-zA-Z°/%]+(?:\s+[a-zA-Z]+)?)(?:\s+(?:to|in|as|=>)\s+([a-zA-Z°/%]+(?:\s+[a-zA-Z]+)?))?$/i);
        if (!m) return null;
        const v = parseFloat(m[1]);
        const from = m[2].trim().toLowerCase().replace(/\s+/g, "");
        const toRaw = m[3];
        if (!toRaw) return null;
        const to = toRaw.trim().toLowerCase().replace(/\s+/g, "");
        // aliases
        const alias = { "c": "celsius", "f": "fahrenheit", "k": "kelvin", "kph": "kmh", "kmh": "km/h", "mph": "mph" };
        const f = alias[from] || from;
        const t = alias[to] || to;
        const conv = {
            // temperature
            "celsius": { "fahrenheit": x => x * 9 / 5 + 32, "kelvin": x => x + 273.15 },
            "fahrenheit": { "celsius": x => (x - 32) * 5 / 9, "kelvin": x => (x - 32) * 5 / 9 + 273.15 },
            "kelvin": { "celsius": x => x - 273.15, "fahrenheit": x => (x - 273.15) * 9 / 5 + 32 },
            // weight
            "kg": { "g": x => x * 1000, "lb": x => x * 2.20462, "oz": x => x * 35.274, "ton": x => x / 1000 },
            "g": { "kg": x => x / 1000, "lb": x => x * 0.00220462, "oz": x => x * 0.035274 },
            "lb": { "kg": x => x * 0.453592, "g": x => x * 453.592, "oz": x => x * 16 },
            "oz": { "kg": x => x * 0.0283495, "g": x => x * 28.3495, "lb": x => x * 0.0625 },
            // length
            "m": { "km": x => x / 1000, "cm": x => x * 100, "mm": x => x * 1000, "mi": x => x * 0.000621371, "ft": x => x * 3.28084, "in": x => x * 39.3701 },
            "km": { "m": x => x * 1000, "mi": x => x * 0.621371, "ft": x => x * 3280.84 },
            "mi": { "m": x => x * 1609.34, "km": x => x * 1.60934, "ft": x => x * 5280 },
            "ft": { "m": x => x * 0.3048, "cm": x => x * 30.48, "in": x => x * 12 },
            "in": { "m": x => x * 0.0254, "cm": x => x * 2.54, "ft": x => x / 12 },
            // volume
            "l": { "ml": x => x * 1000, "gal": x => x * 0.264172, "cup": x => x * 4.22675, "floz": x => x * 33.814 },
            "ml": { "l": x => x / 1000, "cup": x => x * 0.00422675, "tsp": x => x * 0.202884 },
            "gal": { "l": x => x * 3.78541, "ml": x => x * 3785.41, "qt": x => x * 4 },
            // digital
            "gb": { "mb": x => x * 1024, "kb": x => x * 1024 * 1024, "tb": x => x / 1024, "pb": x => x / (1024 * 1024) },
            "mb": { "gb": x => x / 1024, "kb": x => x * 1024, "tb": x => x / (1024 * 1024) },
            // speed
            "km/h": { "m/s": x => x / 3.6, "mph": x => x * 0.621371, "knot": x => x * 0.539957 },
            "mph": { "km/h": x => x * 1.60934, "m/s": x => x * 0.44704, "knot": x => x * 0.868976 }
        };
        if (conv[f] && conv[f][t]) {
            const deg = f === "celsius" || f === "fahrenheit" || f === "kelvin";
            const out = conv[f][t](v);
            const suffix = deg ? "°" : " ";
            const label = `${parseFloat(out.toFixed(4))}${suffix}${toRaw.trim()}`;
            return [mkResult(label, "\u{F1433}", `Converted from ${v} ${m[2].trim()}`, () => Quickshell.execDetached(["wl-copy", label]))];
        }
        return null;
    }

    // ---- arithmetic ----
    function tryArithmetic(text) {
        if (!/^[\d\s.+\-*/()%]+$/.test(text.trim()) || !/[+\-*/]/.test(text)) return null;
        try {
            const val = Function(`"use strict"; return (${text})`)();
            if (typeof val !== "number" || isNaN(val)) return null;
            return [mkResult(`${val}`, "\u{F118D}", "= " + text.trim(), () => Quickshell.execDetached(["wl-copy", `${val}`]))];
        } catch (e) { return null; }
    }

    // ---- URL ----
    function tryUrl(text) {
        const t = text.trim();
        if (/^(https?:\/\/|www\.)\S+$/.test(t) || /^\S+\.com\b/.test(t)) {
            const url = t.startsWith("http") ? t : `https://${t}`;
            return [mkResult(`Open ${url}`, "\u{F153A}", "Open in browser", () => Quickshell.execDetached(["xdg-open", url]))];
        }
        return null;
    }

    // ---- emoji (same assets/emojis/emojis.json index AGS uses) ----
    property FileView _emojiFile: FileView { path: root.emojisPath; printErrors: false }
    property var _emojiIndex: {
        try { return JSON.parse(_emojiFile.text() || "[]"); } catch (e) { return []; }
    }
    function emojiResults(query) {
        const q = query.toLowerCase();
        let out = [];
        for (const e of _emojiIndex) {
            if ((e.app_tags || "").toLowerCase().includes(q)) {
                const glyph = e.app_name || "";
                out.push(mkResult(glyph, glyph, e.app_tags, () => Quickshell.execDetached(["wl-copy", glyph])));
                if (out.length >= maxItems) break;
            }
        }
        return out;
    }

    // ---- notes (same cache/launcher/notes.json AGS uses; full CRUD) ----
    property FileView _notesFile: FileView { path: root.notesPath; watchChanges: false; printErrors: false }
    property var notes: {
        try { return JSON.parse(_notesFile.text() || "[]"); } catch (e) { return []; }
    }
    function persistNotes(list) {
        _notesFile.setText(JSON.stringify(list));
        notes = list;
    }
    function noteResults(rawCommand) {
        const list = notes;
        const norm = (rawCommand || "").trim();
        if (norm === "" || /^list$/i.test(norm)) {
            const visible = list.slice(0, maxItems);
            if (visible.length === 0)
                return [mkResult("No notes yet", "\u{F19DB}", "Type: note buy milk", null)];
            return visible.map((note) => {
                const content = String(note.content || "");
                const preview = content.length > 80 ? content.slice(0, 79) + "…" : content;
                const when = note.updatedAt ? new Date(note.updatedAt).toLocaleString() : "recent";
                return mkResult(`${note.id}. ${preview}`, "\u{F19DB}",
                    `Updated ${when} · click to copy`, () => Quickshell.execDetached(["wl-copy", content]));
            });
        }
        const updateMatch = norm.match(/^(?:edit|set|update|modify)\s+(\d+)(?:\s+([\s\S]+))?$/i);
        if (updateMatch) {
            const idx = Number(updateMatch[1]) - 1;
            if (idx < 0 || idx >= list.length)
                return [mkResult("Note not found", "\u{F19DB}", "", null)];
            const next = JSON.parse(JSON.stringify(list));
            next[idx].content = (updateMatch[2] || "").trim();
            next[idx].updatedAt = Date.now();
            persistNotes(next);
            return [mkResult("Note updated", "\u{F19DB}", next[idx].content, null)];
        }
        const removeMatch = norm.match(/^(?:del|rm|remove|delete)\s+(\d+)$/i);
        if (removeMatch) {
            const idx = Number(removeMatch[1]) - 1;
            if (idx < 0 || idx >= list.length)
                return [mkResult("Note not found", "\u{F19DB}", "", null)];
            const next = JSON.parse(JSON.stringify(list));
            next.splice(idx, 1);
            persistNotes(next);
            return [mkResult("Note removed", "\u{F19DB}", "", null)];
        }
        const addMatch = norm.match(/^(?:add|new)\s+([\s\S]+)$/i);
        const content = addMatch ? addMatch[1].trim() : norm;
        if (!content)
            return [mkResult("No notes yet", "\u{F19DB}", "Type: note buy milk", null)];
        const next = JSON.parse(JSON.stringify(list));
        next.push({ id: next.length + 1, content, createdAt: Date.now(), updatedAt: Date.now() });
        persistNotes(next);
        return [mkResult("Note saved", "\u{F19DB}", content, null)];
    }

    // ---- clipboard (same cache/launcher/clipboard-history.json AGS reads) ----
    property FileView _cbFile: FileView { path: root.clipboardPath; watchChanges: false; printErrors: false }
    property var _clipboardIndex: {
        try { return JSON.parse(_cbFile.text() || "[]"); } catch (e) { return []; }
    }
    function clipboardResults(query) {
        const q = query.toLowerCase();
        let out = [];
        for (const entry of _clipboardIndex) {
            const content = String(entry.content || "");
            if (content.toLowerCase().includes(q)) {
                const stroke = content.replace(/\s+/g, " ").slice(0, 128)
                    + (content.length > 128 ? "…" : "");
                const type = entry.type || (entry.mimeType || "text");
                out.push(mkResult(stroke, "\u{F156C}", `${type} · click to copy`, () => Quickshell.execDetached(["wl-copy", content])));
                if (out.length >= maxItems) break;
            }
        }
        if (out.length === 0)
            out = [mkResult("No clipboard match", "\u{F156C}", `Nothing matching "${query}" in history`, null)];
        return out;
    }

    // ---- translate (AGS scripts/translate.sh like translate.tsx) ----
    property Process _trProc: Process {
        property string mode: ""
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (parent.mode === "translate")
                    root.results = [root.mkResult(text.trim(), "\u{F10CC}", "Translation · click to copy", () =>
                        Quickshell.execDetached(["sh", "-c", `printf %s '${text.trim().replace(/'/g, "")}' | wl-copy`]))];
            }
        }
    }

    // ---- main entry — mirrors handleEntryChanged() (debounced 100ms like AGS) ----
    property var _debounce: null
    function runQueryDebounced(text) {
        if (_debounce) clearTimeout(_debounce)
        _debounce = setTimeout(function() { runQuery(text) }, 100)
    }
    function runQuery(text) {
        lastQuery = text;
        // AGS parity: prefix dispatch on leading-trim only. (Qt's JS engine
        // has no String.trimStart, so strip leading whitespace by regex.)
        // A full trim would eat the trailing space of bare modes like
        // "cb " / "note " / "emoji " and misroute them to app search.
        const t = String(text || "").replace(/^\s+/, "");

        if (!t || t.trim() === "") { results = []; return; }

        // prefixed modes (in AGS dispatch order)
        if (t.startsWith("cb ")) { results = clipboardResults(t.slice(3)); return; }
        if (t.startsWith("note ")) { results = noteResults(t.slice(5)); return; }
        if (t.startsWith("apps")) { results = appResults(t.slice(4).trim() || ""); return; }

        const conv = tryConversion(t);   if (conv) { results = conv; return; }

        const parts = t.trim().split(/\s+/);

        // custom command filter: "light >"
        if (parts[0].includes(">")) {
            const needle = t.replace(">", "").trim().toLowerCase();
            results = customCommandsList().filter(c => c.name.toLowerCase().includes(needle));
            return;
        }

        // translate "hello > es"
        const trMatch = t.match(/^(.+?)\s*>\s*(\w{2})$/);
        if (trMatch) {
            _trProc.mode = "translate";
            _trProc.command = ["bash", `${Quickshell.env("HOME")}/.config/ags/scripts/translate.sh`, trMatch[1].trim(), trMatch[2]];
            _trProc.running = true;
            results = [mkResult("Translating…", "\u{F10CC}", "", null)];
            return;
        }

        // emoji "emoji <query>"
        if (t.startsWith("emoji ")) { results = emojiResults(t.slice(6)); return; }

        // math / url
        const arith = tryArithmetic(t);  if (arith) { results = arith; return; }
        const url = tryUrl(t);           if (url) { results = url; return; }

        // fallback: app fuzzy search, trailing-args support
        const head = parts[0];
        const rest = parts.slice(1);
        let r = appResults(head, rest);
        if (r.length === 0 && rest.length === 0) {
            r = [mkResult(`Try ${t} in terminal`, "\u{F15BB}", "Run as shell command",
                () => Quickshell.execDetached(["kitty", "-e", "bash", "-c", t]))];
        }
        results = r;
        if (selectedIndex >= results.length) selectedIndex = 0;
    }
}
