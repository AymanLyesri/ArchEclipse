pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Port of widgets/applauncher + utilities: query parsing pipeline and results.
//
// Query grammar (mirrors AGS):
//   cb ...            clipboard history        (placeholder — cliphist)
//   note ...          notes                    (file-backed notes)
//   apps ...          list all apps
//   emoji ...         emoji search
//   translate x > y   translate via trans(1)
//   N unit in/unit M  unit conversion
//   arithmetic        ..*/+-..
//   URL               open link
//   "name > args"     custom commands filtered
//   fallback          fuzzy app search (DesktopEntries), then terminal hint

QtObject {
    id: root

    readonly property int maxItems: 10
    readonly property string historyPath: `${Quickshell.env("HOME")}/.config/quickshell/archeclipse/cache/launcher-history.json`

    property var results: []
    property int selectedIndex: 0
    property string lastQuery: ""

    // launch history persisted across sessions
    property var _historyFile: FileView {
        path: root.historyPath
        watchChanges: false
        printErrors: false
    }
    property var history: {
        try { return JSON.parse(_historyFile.text() || "[]"); }
        catch (e) { return []; }
    }

    function touchHistory(name) {
        let h = history.filter(n => n !== name);
        h.unshift(name);
        h = h.slice(0, 30);
        _historyFile.setText(JSON.stringify(h));
        history = h;
    }

    function selectNext(dir) {
        if (!results.length) return;
        selectedIndex = (selectedIndex + dir + results.length) % results.length;
    }

    function activateSelected() {
        const r = results[selectedIndex];
        if (r && r.launch) r.launch();
    }

    // ---- result row factory ----
    function mkResult(name, icon, description, launch, argText) {
        return { name, icon, description, launch, argText: argText || "" };
    }

    // ---- app search over DesktopEntries ----
    function scoreEntry(e, q) {
        const name = (e.name || "").toLowerCase();
        if (name.startsWith(q)) return 0;
        if (name.includes(q)) return 1;
        if ((e.genericName || "").toLowerCase().includes(q)) return 2;
        if ((e.comment || "").toLowerCase().includes(q)) return 3;
        if ((e.keywords || []).some(k => k.toLowerCase().includes(q))) return 4;
        return 99;
    }

    function appResults(query, withArgs) {
        const q = query.toLowerCase().trim();
        const entries = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        const scored = [];
        for (const e of entries) {
            const s = scoreEntry(e, q);
            if (s < 99) scored.push({ e, s });
        }
        scored.sort((a, b) => {
            // history boost
            const ha = history.indexOf(a.e.name), hb = history.indexOf(b.e.name);
            const ba = ha >= 0 ? -5 : 0, bb = hb >= 0 ? -5 : 0;
            return (a.s + ba) - (b.s + bb);
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

    // ---- custom commands ("light >" style filter from constants/app.constants.ts subset) ----
    readonly property var customCommands: [
        mkResult("Light Theme", "\u{F042}", "Switch to light theme", () => Quickshell.execDetached(["bash", "-c", `${Quickshell.env("HOME")}/.config/hypr/theme/scripts/system-theme.sh switch light`])),
        mkResult("Dark Theme", "\u{F042}", "Switch to dark theme", () => Quickshell.execDetached(["bash", "-c", `${Quickshell.env("HOME")}/.config/hypr/theme/scripts/system-theme.sh switch dark`])),
        mkResult("System Sleep", "\u{F042}", "Suspend system", () => Quickshell.execDetached(["bash", "-c", `${Quickshell.env("HOME")}/.config/hypr/scripts/hyprlock.sh suspend`])),
        mkResult("Lock Screen", "\u{F042}", "Lock session", () => Quickshell.execDetached(["bash", "-c", `${Quickshell.env("HOME")}/.config/hypr/scripts/hyprlock.sh`])),
        mkResult("Reboot", "\u{F042}", "Reboot system", () => Quickshell.execDetached(["reboot"])),
        mkResult("Shutdown", "\u{F042}", "Power off system", () => Quickshell.execDetached(["shutdown", "now"]))
    ]

    // ---- unit conversion ----
    function tryConversion(text) {
        const m = text.match(/^\s*([\d.]+)\s*([a-zA-Z°]+)\s*(?:to|in)\s*([a-zA-Z°]+)\s*$/);
        if (!m) return null;
        const [_, vStr, from, to] = m;
        const v = parseFloat(vStr);
        const conv = {
            "c": { "f": x => x * 9 / 5 + 32, "c": x => x },
            "f": { "c": x => (x - 32) * 5 / 9, "f": x => x },
            "kg": { "lb": x => x * 2.20462, "g": x => x * 1000 },
            "lb": { "kg": x => x / 2.20462 },
            "km": { "mi": x => x * 0.621371, "m": x => x * 1000 },
            "mi": { "km": x => x / 0.621371 },
            "m": { "ft": x => x * 3.28084, "cm": x => x * 100 },
            "ft": { "m": x => x / 3.28084 },
            "l": { "gal": x => x * 0.264172 },
            "gal": { "l": x => x / 0.264172 }
        };
        const key = from.toLowerCase(), target = to.toLowerCase();
        if (conv[key] && conv[key][target]) {
            const out = conv[key][target](v);
            return [mkResult(`${out.toFixed(2)}${key === "c" || key === "f" ? "°" : ""} ${to}`, "\u{F0493}", `Converted from ${v}${from}`, null)];
        }
        return null;
    }

    // ---- arithmetic ----
    function tryArithmetic(text) {
        if (!/^[\d\s.+\-*/()%]+$/.test(text.trim()) || !/[+\-*/]/.test(text)) return null;
        try {
            // limited eval via Function on sanitized input
            const val = Function(`"use strict"; return (${text})`)();
            if (typeof val !== "number" || isNaN(val)) return null;
            return [mkResult(`${val}`, "\u{F018D}", "= " + text.trim(), null)];
        } catch (e) { return null; }
    }

    // ---- URL ----
    function tryUrl(text) {
        const t = text.trim();
        if (/^(https?:\/\/|www\.)\S+$/.test(t) || /^\S+\.com\b/.test(t)) {
            const url = t.startsWith("http") ? t : `https://${t}`;
            return [mkResult(`Open ${url}`, "\u{F05A4}", "Open in browser", () => Quickshell.execDetached(["xdg-open", url]))];
        }
        return null;
    }

    // ---- emoji (small common set; AGS used assets/emojis index) ----
    function emojiResults(query) {
        const set = {
            "smile": ["😀", "😃", "😄", "😁"], "heart": ["❤️", "🧡", "💛", "💚"],
            "fire": ["🔥"], "star": ["⭐", "🌟", "✨"], "check": ["✅", "✔️"],
            "cat": ["🐱", "😺"], "dog": ["🐶"], "thumbs": ["👍", "👎"],
            "rocket": ["🚀"], "eyes": ["👀", "👁️"], "party": ["🎉", "🥳"]
        };
        const q = query.toLowerCase();
        let out = [];
        for (const k in set)
            if (k.includes(q))
                for (const e of set[k])
                    out.push(mkResult(e, "", k, () => Quickshell.execDetached(["sh", "-c", `printf %s '${e}' | wl-copy`])));
        return out.slice(0, maxItems);
    }

    // ---- notes (simple file-backed) ----
    readonly property string notesPath: `${Quickshell.env("HOME")}/.config/quickshell/archeclipse/cache/notes.json`
    property FileView _notesFile: FileView { path: root.notesPath; printErrors: false }
    property var notes: {
        try { return JSON.parse(_notesFile.text() || "[]"); } catch (e) { return []; }
    }

    function saveNotes() {
        _notesFile.setText(JSON.stringify(notes));
    }

    // ---- clipboard placeholder (cliphist if present) ----
    property Process _cbProc: Process {
        command: ["sh", "-c", "command -v cliphist >/dev/null && echo yes || echo no"]
        stdout: StdioCollector { onStreamFinished: root._hasCliphist = text.trim() === "yes" }
    }
    property bool _hasCliphist: false

    function clipboardResults(query) {
        if (!_hasCliphist) return [mkResult("cliphist not installed", "\u{F056C}", "Install cliphist for clipboard history", null)];
        return [mkResult(`Search "${query}"`, "\u{F092E}", "Open cliphist picker in terminal", () =>
            Quickshell.execDetached(["kitty", "-e", "sh", "-c", `cliphist list | fzf | cliphist decode | wl-copy`]))];
    }

    // ---- translate (trans CLI like AGS scripts/translate.sh) ----
    property Process _trProc: Process {
        property string mode: ""
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (parent.mode === "translate")
                    root.results = [root.mkResult(text.trim(), "\u{F10CB}", "Translation", () =>
                        Quickshell.execDetached(["sh", "-c", `printf %s '${text.trim().replace(/'/g, "")}' | wl-copy`]))];
            }
        }
    }

    // ============================================================
    // main entry — mirrors handleEntryChanged()
    // ============================================================
    function runQuery(text) {
        lastQuery = text;
        const t = (text || "").trim();

        if (!t) { results = []; return; }

        // prefixed modes
        if (t.startsWith("cb ")) { results = clipboardResults(t.slice(3)); return; }
        if (t.startsWith("note ")) {
            const body = t.slice(5).trim();
            if (body === "") {
                results = notes.slice(-maxItems).reverse().map((n, i) =>
                    mkResult(n, "\u{F09DB}", "note — click to copy", () => Quickshell.execDetached(["sh", "-c", `printf %s $'${n.replace(/'/g, "")}' | wl-copy`])));
                if (!results.length) results = [mkResult("No notes yet", "\u{F09DB}", 'Type "note something" to add one', null)];
            } else {
                notes.push(body); saveNotes();
                results = [mkResult("Note saved", "\u{F09DB}", body, null)];
            }
            return;
        }
        if (t.startsWith("apps")) { results = appResults(t.slice(4).trim() || ""); return; }
        if (t.startsWith("emoji ")) { results = emojiResults(t.slice(6)); return; }

        // custom command filter: "light >"
        if (t.includes(">")) {
            const needle = t.replace(">", "").trim().toLowerCase();
            results = customCommands.filter(c => c.name.toLowerCase().includes(needle));
            return;
        }

        // translate "hello > es"
        const trMatch = t.match(/^(.+?)\s*>\s*(\w{2})$/);
        if (trMatch) {
            _trProc.mode = "translate";
            _trProc.command = ["trans", "-brief", trMatch[1].trim(), "-t", trMatch[2]];
            _trProc.running = true;
            results = [mkResult("Translating…", "\u{F10CB}", "", null)];
            return;
        }

        // math / conversion / url
        const conv = tryConversion(t);   if (conv) { results = conv; return; }
        const arith = tryArithmetic(t);  if (arith) { results = arith; return; }
        const url = tryUrl(t);           if (url) { results = url; return; }

        // fallback: app fuzzy search, with trailing-args support
        const parts = t.split(/\s+/);
        const head = parts[0];
        const rest = parts.slice(1);
        let r = appResults(head, rest.length > 0 ? undefined : undefined);
        if (r.length === 0 && rest.length === 0) {
            r = [mkResult(`Try ${t} in terminal`, "\u{F05BB}", "Run as shell command",
                () => Quickshell.execDetached(["kitty", "-e", "sh", "-c", t]))];
        }
        results = r;
        if (selectedIndex >= results.length) selectedIndex = 0;
    }
}
