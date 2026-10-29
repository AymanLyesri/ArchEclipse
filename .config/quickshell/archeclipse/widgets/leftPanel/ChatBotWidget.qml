import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme
import qs.widgets.shared
import qs.services

// ChatBot widget — port of ChatBot.tsx
// Features: multiple AI providers (OpenRouter), session create/delete,
// markdown rendering (headers/lists/quotes/code w/ copy), message timestamps
// + response time + click-to-copy, image-gen toggle, info/setup guide,
// thinking indicator, auto-scroll, auto-focus, multi-line input
Item {
    id: root
    property string monitorName: ""

    // --- State ---
    property var messages: []
    property string activeSessionId: "default"
    // The provider persists across launches via Settings.chatBotApi.
    property string currentApiModel: Settings.chatBotApi
    property string progressStatus: "idle" // idle | loading | error | success
    property string lastError: ""
    property var sessions: []
    property int _sendTime: 0
    property bool _shouldScroll: true
    property var sessionFirsts: ({})
    // Live streaming state (ChatGPT-style): stdout grows via waitForEnd:false,
    // rendered line-by-line in the streaming bubble until onExited reloads.
    property string streamingText: ""
    property var activeProc: null
    property int _requestSerial: 0
    property bool _stopRequested: false
    // Incremental line model for the streaming bubble. Rows are only ever
    // APPENDED (new delegates fade in once) or updated IN PLACE via set() /
    // setProperty() (growing tail line, code-flag restyles — never refade).
    // Reset on every send; cleared when the stream ends.
    ListModel {
        id: streamLines
    }
    // chatbot.py owns its files under ~/.cache/quickshell/chatbot
    // (CACHE_DIR hardcoded in the script) — read the same dir it writes,
    // or sessions/history silently fork.
    property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell/chatbot"
    property string pythonScript: Quickshell.env("HOME") + "/.config/quickshell/archeclipse/scripts/chatbot/main.py"
    property string sessionsScript: Quickshell.env("HOME") + "/.config/quickshell/archeclipse/scripts/chatbot/sessions.py"
    property string modelsScript: Quickshell.env("HOME") + "/.config/quickshell/archeclipse/scripts/chatbot/models.py"
    property string activeFileScript: Quickshell.env("HOME") + "/.config/quickshell/archeclipse/scripts/chatbot/activefile.py"
    // Live OpenRouter model ids (empty = unknown/offline → show all hardcoded).
    property var modelCache: []
    // File detected in the focused editor ({path, name}); refreshed from
    // Hyprland focus/title events for the preview label. The backend
    // re-detects at send time, so this preview may briefly lag events.
    property var autoFile: ({
        path: "",
        name: ""
    })
    onSessionsChanged: { for (const s of root.sessions) root.fetchFirstMessage(s.id); }

    // Session tab currently being renamed ("").
    property string renamingSessionId: ""

    // Tabs actually offered: hardcoded entries filtered by the live model
    // list when known; the selected model is never hidden.
    function visibleProviders() {
        return root.providers.filter(p => root.modelCache.length === 0 || root.modelCache.indexOf(p.value) !== -1 || p.value === root.currentApiModel);
    }

    function loadModels() {
        const p = _modelsProc.createObject(root);
        p.command = ["python3", root.modelsScript];
        p.running = true;
    }

    // Context envelope for main.py stdin (active file is detected
    // backend-side at send time; the QML preview never sends content).
    function buildContextJson() {
        return JSON.stringify({
            flags: Settings.chatBotContext
        });
    }

    // Provider list (OpenRouter ids; validated against the live /models
    // list when reachable — entries missing from a fresh cache are hidden).
    property var providers: [
        {
            name: "OpenRouter Auto",
            value: "openrouter/auto",
            icon: "ORA",
            description: "Auto-routes to a current strong model",
            imageGenerationSupport: false
        },
        {
            name: "OpenRouter Free",
            value: "openrouter/free",
            icon: "ORF",
            description: "Legacy free router (hidden when not served)",
            imageGenerationSupport: false
        },
        {
            name: "Gpt 4o mini",
            value: "openai/gpt-4o-mini",
            icon: "G4o",
            description: "OpenAI's gpt-4o-mini model, versatile and efficient",
            imageGenerationSupport: false
        },
        {
            name: "Qwen3.5 9B",
            value: "qwen/qwen3.5-9b",
            icon: "Q3.5",
            description: "Qwen's 3.5 9B model, designed for a wide range of applications with strong performance",
            imageGenerationSupport: false
        },
        {
            name: "Meta Llama 3.2 1B Instruct",
            value: "meta-llama/llama-3.2-1b-instruct",
            icon: "L3.2",
            description: "Meta's Llama 3.2 1B Instruct model, designed for instruction following",
            imageGenerationSupport: false
        },
        {
            name: "Mistral 8B",
            value: "mistralai/ministral-8b-2512",
            icon: "M8B",
            description: "Mistral AI's Ministral 8B model, optimized for efficiency and performance",
            imageGenerationSupport: false
        }
    ]

    Component.onCompleted: {
        loadSessions();
        loadModels();
        refreshAutoFile();
    }

    // Coalesce compositor events so a focus/title burst causes one lookup.
    Timer {
        id: autoFileRefreshTimer
        interval: 100
        repeat: false
        onTriggered: root.refreshAutoFile()
    }

    // Refresh the preview when Hyprland reports a focus, title, or window
    // lifecycle change. The backend still re-detects the file at send time.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!BarState.isOpenFor("left", root.monitorName) || !(Settings.chatBotContext.file ?? true))
                return;
            const name = event?.name ?? "";
            if (name === "activewindow" || name === "activewindowv2" ||
                name === "windowtitle" || name === "openwindow" ||
                name === "closewindow")
                autoFileRefreshTimer.restart();
        }
    }

    Connections {
        target: BarState
        function onPanelStatesByMonitorChanged() {
            if (BarState.isOpenFor("left", root.monitorName) && (Settings.chatBotContext.file ?? true))
                root.refreshAutoFile();
            else
                autoFileRefreshTimer.stop();
        }
    }

    Connections {
        target: Settings
        function onChatBotContextChanged() {
            if (BarState.isOpenFor("left", root.monitorName) && (Settings.chatBotContext.file ?? true))
                root.refreshAutoFile();
            else
                autoFileRefreshTimer.stop();
        }
    }

    // --- Helpers ---
    function apiKey() {
        return Settings.apiKey("openrouter", "key");
    }

    // --- Session Management ---
    function getHistoryPath(sid) {
        return cacheDir + "/sessions/" + (sid || activeSessionId) + "/history.json";
    }

    function getSessionsDir() {
        return cacheDir + "/sessions";
    }

    function ensureSessionDir(sid) {
        const p = _mkDir.createObject(root);
        p.command = ["mkdir", "-p", getSessionsDir() + "/" + sid];
        p.running = true;
    }

    function loadSessions() {
        // Single sessions.py call: ensures dir, lists ids + meta names.
        // The reply carries its model (envelope) so a listing that
        // arrives after a provider switch is ignored (stale-guard).
        const p = _listDir.createObject(root);
        p.command = ["python3", root.sessionsScript, root.currentApiModel, "list"];
        p.running = true;
    }

    function commitRename(sid, newName) {
        const p = _renameProc.createObject(root);
        p._sid = sid;
        p._name = newName;
        p.command = ["python3", root.sessionsScript, root.currentApiModel, "rename", sid, newName];
        p.running = true;
    }

       function autoNameSessionFromMessage(text) {
        if (!text || root.messages.length > 0)
            return;
        for (const s of root.sessions) {
            if (s.id !== root.activeSessionId)
                continue;
            const currentName = String(s.name || "");
            if (currentName && !/^Session \d+$/.test(currentName))
                return;
            const name = String(text).trim().replace(/\s+/g, " ").slice(0, 80);
            if (name)
                root.commitRename(s.id, name);
            return;
        }
    }

    function loadMessages() {
        const p = _readFile.createObject(root);
        p.command = ["cat", getHistoryPath()];
        p.running = true;
    }

    // Fetch first message content for a session — used for the session tab
    // tooltip context preview. Cached in sessionFirsts.
    function fetchFirstMessage(sid) {
        if (root.sessionFirsts[sid] !== undefined)
            return;
        root.sessionFirsts[sid] = ""; // mark as loading to avoid duplicate fetches
        const p = _firstMsg.createObject(root);
        p._sid = sid;
        p.command = ["cat", getSessionsDir() + "/" + sid + "/history.json"];
        p.running = true;
    }

    // NOTE: chatbot.py loads/appends/saves history.json itself (both user
    // and assistant messages, canonical ids/timestamps). Never rewrite the
    // file from QML — a prior saveHistory() via bash printf clobbered the
    // canonical entries and broke on quotes. In-memory state is display-only;
    // after a reply, reload the canonical file (see onExited below).

    // Create new session (optional display name; persisted via rename).
    function createSession(name) {
        const clean = (name === undefined || name === null) ? "" : String(name).trim().slice(0, 80);
        const newId = "session-" + Date.now();
        ensureSessionDir(newId);
        const newSession = {
            id: newId,
            name: clean || "Session " + (root.sessions.length + 1),
            createdAt: Date.now()
        };
        root.sessions = root.sessions.concat([newSession]);
        root.activeSessionId = newId;
        root.messages = [];
        if (clean)
            root.commitRename(newId, clean);
    }

    // Delete a session
    function deleteSession(sessionId) {
        if (sessionId === "" || sessionId.indexOf("..") !== -1 || sessionId.indexOf("/") !== -1)
            return;
        if (root.sessions.length <= 1) {
            Notifications.notify({
                summary: "Cannot Delete",
                body: "You must have at least one session"
            });
            return;
        }
        const p = _rmDir.createObject(root);
        p.command = ["rm", "-rf", getSessionsDir() + "/" + sessionId];
        p.running = true;
        root.sessions = root.sessions.filter(s => s.id !== sessionId);
        if (root.activeSessionId === sessionId) {
            root.activeSessionId = root.sessions[0].id;
            root.loadMessages();
        }
    }

    // Clear current session messages
    function clearMessages() {
        const p = _clearFile.createObject(root);
        p.command = ["rm", "-f", getHistoryPath()];
        p.running = true;
        root.messages = [];
    }

    // Refresh the auto-detected editor file (preview only; one-shot).
    function refreshAutoFile() {
        const p = _autoFileProc.createObject(root);
        p.command = ["python3", root.activeFileScript];
        p.running = true;
    }

    // --- API Communication ---
    function sendMessage(text) {
        if (!text.trim())
            return;
        if (root.progressStatus === "loading")
            return;
        root._sendTime = Date.now();
        root._shouldScroll = true;
        root.streamingText = "";
        root.lastError = "";
        streamLines.clear();
        root.messages = root.messages.concat([
            {
                id: "" + (root.messages.length + 1),
                role: "user",
                content: text,
                timestamp: Date.now()
            }
        ]);
        const key = root.apiKey();
        if (!key) {
            Notifications.notify({
                summary: "ChatBot Error",
                body: "OpenRouter API key is not configured. Please set it in settings."
            });
            root.lastError = "OpenRouter API key is not configured. Please set it in settings.";
            root.progressStatus = "error";
            return;
        }
        root.progressStatus = "loading";
        root._requestSerial++;
        root._stopRequested = false;
        const p = _chatAPI.createObject(root);
        p._requestId = root._requestSerial;
        // Key via environment (never argv — argv is visible in ps).
        // Context JSON via stdin: write() on started (no close-stdin in
        // Quickshell; main.py drains with a quiet-gap timeout instead).
        p.command = ["python3", "-u", root.pythonScript, root.currentApiModel, text, root.activeSessionId];
        p.environment = ({
            "OPENROUTER_API_KEY": key
        });
        p.stdinEnabled = true;
        p.started.connect(() => p.write(root.buildContextJson()));
        root.activeProc = p;
        p.running = true;
    }

    function stopGeneration() {
        const p = root.activeProc;
        if (!p || !p.running)
            return;
        // Unlock the editor immediately. The child may take a moment to
        // handle SIGTERM and emit onExited; its callback reconciles the
        // partial history without putting this request back into loading.
        root._stopRequested = true;
        root.progressStatus = "idle";
        root.activeProc = null;
        p.running = false; // SIGTERM -> chatbot.py saves partial, exits 0
    }

    // Revert to a user message (OpenCode-style): drop it and everything
    // after it from history + file, load its text back into the input
    // for editing. Never while streaming (backend appends mid-flight).
    function revertMessage(idx) {
        if (root.progressStatus === "loading")
            return;
        if (idx < 0 || idx >= root.messages.length)
            return;
        const m = root.messages[idx];
        if (!m || m.role !== "user" || !(m.content || "").trim())
            return;
        const text = m.content;
        root.messages = root.messages.slice(0, idx);
        const p = _truncateFile.createObject(root);
        p.command = ["python3", "-c", "import json,os,sys\np,n=sys.argv[1],int(sys.argv[2])\ntry:\n h=json.loads(open(p).read())\nexcept Exception:\n h=[]\nif isinstance(h,list) and len(h)>n:\n h=h[:n]\n t=p+'.tmp'\n open(t,'w').write(json.dumps(h,indent=2))\n os.replace(t,p)\n", getHistoryPath(), String(idx)];
        p.running = true;
        inputField.text = text;
        inputField.forceActiveFocus();
        root._shouldScroll = true;
    }

    // --- Slash commands (/new /list /switch /rename /delete /clear /revert) ---
    // Mirrors scripts/chatbot/commands.py (parse_slash/match_session) —
    // that module is the tested spec, keep both in sync.
    property var slashCommands: [
        {
            name: "new",
            description: "Create new session",
            usage: "/new [name]"
        },
        {
            name: "list",
            description: "List sessions",
            usage: "/list"
        },
        {
            name: "sessions",
            description: "List sessions (alias)",
            usage: "/sessions"
        },
        {
            name: "switch",
            description: "Switch session by number, id or name",
            usage: "/switch <n|name>"
        },
        {
            name: "rename",
            description: "Rename active session",
            usage: "/rename <name>"
        },
        {
            name: "delete",
            description: "Delete session (active when bare)",
            usage: "/delete [n|name]"
        },
        {
            name: "clear",
            description: "Wipe current session messages",
            usage: "/clear"
        },
        {
            name: "revert",
            description: "Revert to the last message for editing",
            usage: "/revert"
        }
    ]
    property int slashIndex: 0

    function isSessionListCmd(cmd) {
        return cmd === "list" || cmd === "sessions" || cmd === "switch" || cmd === "delete";
    }

    // "/cmd arg..." -> {cmd, arg} or null (not a slash invocation).
    function parseSlash(text) {
        if (typeof text !== "string" || text.charAt(0) !== "/")
            return null;
        const body = text.slice(1).trim();
        if (!body)
            return null;
        const sp = body.search(/\s/);
        if (sp === -1)
            return {
                cmd: body.toLowerCase(),
                arg: ""
            };
        return {
            cmd: body.slice(0, sp).toLowerCase(),
            arg: body.slice(sp + 1).trim()
        };
    }

    function findSlashCommand(cmd) {
        for (const c of root.slashCommands)
            if (c.name === cmd)
                return c;
        return null;
    }

    // Match a session by 1-based index, exact id, or name substring.
    function matchSession(query) {
        if (query === undefined || query === null || !root.sessions)
            return null;
        const q = String(query).trim();
        if (!q)
            return null;
        const idx = parseInt(q, 10);
        if (!isNaN(idx) && String(idx) === q && idx >= 1 && idx <= root.sessions.length)
            return root.sessions[idx - 1];
        const ql = q.toLowerCase();
        for (const s of root.sessions)
            if (String(s.id).toLowerCase() === ql)
                return s;
        for (const s of root.sessions)
            if (String(s.name).toLowerCase().indexOf(ql) !== -1)
                return s;
        return null;
    }

    // Sessions filtered by the arg of a list/switch/delete invocation.
    function sessionMatches() {
        const p = root.parseSlash(inputField.text);
        if (!p || !root.isSessionListCmd(p.cmd))
            return [];
        if (!p.arg)
            return root.sessions;
        const ql = p.arg.toLowerCase();
        const out = [];
        for (let i = 0; i < root.sessions.length; i++) {
            const s = root.sessions[i];
            if (String(i + 1) === p.arg.trim() || String(s.id).toLowerCase() === ql || String(s.name).toLowerCase().indexOf(ql) !== -1)
                out.push(s);
        }
        return out;
    }

    function activeSessionName() {
        for (const s of root.sessions)
            if (s.id === root.activeSessionId)
                return s.name || s.id;
        return root.activeSessionId;
    }

    function switchToSession(sid) {
        if (!sid)
            return;
        root.activeSessionId = sid;
        root.slashIndex = 0;
        root.loadMessages();
    }

    function lastUserIndex() {
        for (let i = root.messages.length - 1; i >= 0; i--)
            if (root.messages[i].role === "user")
                return i;
        return -1;
    }

    // Commands matching the input: "/xx" prefix-filters; "/cmd args"
    // resolves to the single exact command so Enter runs it with args.
    function slashFilter() {
        if (inputField.text === "/")
            return root.slashCommands;
        const p = root.parseSlash(inputField.text);
        if (!p)
            return [];
        if (p.arg !== "")
            return root.findSlashCommand(p.cmd) ? [root.findSlashCommand(p.cmd)] : [];
        return root.slashCommands.filter(c => c.name.startsWith(p.cmd));
    }

    // Combined popup length (commands + session hits) for Up/Down cycling.
    function slashPopupCount() {
        return root.slashFilter().length + root.sessionMatches().length;
    }

    function runSlashCommand(name, arg) {
        arg = (arg === undefined || arg === null) ? "" : String(arg).trim();
        inputField.text = "";
        root.slashIndex = 0;
        if (name === "clear") {
            root.clearMessages();
            return;
        }
        if (name === "revert") {
            root.revertMessage(root.lastUserIndex());
            return;
        }
        if (name === "new") {
            root.createSession(arg);
            return;
        }
        if (name === "list" || name === "sessions") {
            if (arg) {
                const hit = root.matchSession(arg);
                if (hit)
                    root.switchToSession(hit.id);
                else
                    Notifications.notify({
                        summary: "No matching session",
                        body: "No session matches \"" + arg + "\""
                    });
            } else {
                // Bare /list stays a menu: keep the command in the input
                // so the popup keeps showing the session rows and Down/Enter
                // picks one. Rewriting the text to "/switch " made /list look
                // like /switch had been chosen; a toast hid the rows.
                inputField.text = "/" + name + " ";
                inputField.forceActiveFocus();
            }
            return;
        }
        if (name === "switch") {
            if (!arg) {
                inputField.text = "/switch ";
                inputField.forceActiveFocus();
                return;
            }
            const hit = root.matchSession(arg);
            if (hit)
                root.switchToSession(hit.id);
            else
                Notifications.notify({
                    summary: "No matching session",
                    body: "No session matches \"" + arg + "\""
                });
            return;
        }
        if (name === "rename") {
            if (!arg) {
                Notifications.notify({
                    summary: "Usage",
                    body: "/rename <name>"
                });
                return;
            }
            root.commitRename(root.activeSessionId, arg.slice(0, 80));
            return;
        }
        if (name === "delete") {
            if (!arg) {
                root.deleteSession(root.activeSessionId);
                return;
            }
            const hit = root.matchSession(arg);
            if (hit)
                root.deleteSession(hit.id);
            else
                Notifications.notify({
                    summary: "No matching session",
                    body: "No session matches \"" + arg + "\""
                });
            return;
        }
    }

    // Enter-key entry: run the slash command when the input is one.
    // Unknown "/..." stays plain chat text (returns false → sent).
    // Returns true when a command ran (key event is consumed).
    function trySlashCommand() {
        const p = root.parseSlash(inputField.text);
        const cmds = root.slashFilter();
        // The popup is the source of truth for what Enter runs: bare "/"
        // and bare prefixes ("/li") have no parseSlash def, yet the list
        // is showing rows to pick from — honour the highlighted row.
        if (cmds.length > 0 && (!p || p.arg === "")) {
            const def = p ? root.findSlashCommand(p.cmd) : null;
            // Bare list/switch/delete with the popup highlighting a
            // session: Enter activates the highlighted session row
            // instead of the command row (highlight past the rows).
            if (def && root.isSessionListCmd(def.name)) {
                const sess = root.sessionMatches();
                if (sess.length > 0 && root.slashIndex >= cmds.length) {
                    const pick = sess[Math.min(root.slashIndex - cmds.length, sess.length - 1)];
                    inputField.text = "";
                    root.slashIndex = 0;
                    if (def.name === "delete")
                        root.deleteSession(pick.id);
                    else
                        root.switchToSession(pick.id);
                    return true;
                }
            }
            root.runSlashCommand(cmds[Math.min(root.slashIndex, cmds.length - 1)].name, p ? p.arg : "");
            return true;
        }
        // "/cmd args": exact command, run it with the arg.
        if (!p)
            return false;
        const def = root.findSlashCommand(p.cmd);
        if (!def)
            return false;
        root.runSlashCommand(def.name, p.arg);
        return true;
    }

    // Live stdout chunk -> streaming bubble only (bound to streamLines
    // below the Repeater). Never touches root.messages: reassigning that
    // array per token rebuilds EVERY Repeater delegate (fade loop + stutter).
    function onStreamText(text) {
        if (root.progressStatus !== "loading")
            return;
        if (!text)
            return;
        root.streamingText = text;
        root._shouldScroll = true;
        root.updateStreamLines(text);
    }

    // Diff full streamed text against the streamLines model: append new
    // lines, update the growing tail in place, restyle code flags in place.
    // Streaming text is append-only, so kept rows never move (algorithm
    // mirror verified in /tmp/opencode/stream_lines_test.py).
    function updateStreamLines(text) {
        const lines = text.split("\n");
        // ``` fence parity: lines inside code blocks render as plain mono.
        const inCode = [];
        let open = false;
        for (let i = 0; i < lines.length; i++) {
            inCode.push(open);
            const fences = (lines[i].match(/```/g) || []).length;
            if (fences % 2 === 1)
                open = !open;
        }
        // Common prefix: rows whose line text is already final.
        let keep = 0;
        while (keep < streamLines.count && keep < lines.length && streamLines.get(keep).line === lines[keep])
            keep++;
        // Code flags on kept rows may flip as fences resolve — restyle in
        // place via setProperty (delegate preserved, no refade).
        for (let i = 0; i < keep; i++) {
            if (streamLines.get(i).code !== inCode[i])
                streamLines.setProperty(i, "code", inCode[i]);
        }
        // Growing tail line: update in place via set (never refades).
        if (keep < streamLines.count && keep < lines.length) {
            streamLines.set(keep, {
                line: lines[keep],
                code: inCode[keep]
            });
            keep++;
        }
        // Safety net: drop rows past the end (append-only streams never
        // hit this, but a shrunk payload must not leave stale rows).
        while (streamLines.count > lines.length)
            streamLines.remove(streamLines.count - 1);
        // Genuinely new lines: appended delegates fade in exactly once.
        for (let i = keep; i < lines.length; i++)
            streamLines.append({
                line: lines[i],
                code: inCode[i]
            });
    }

    // --- Markdown (port of formatText) ---
    function formatMessage(text) {
        const parts = text.split(/```(\w*)?\n?([\s\S]*?)```/g);
        const result = [];
        for (let i = 0; i < parts.length; i++) {
            const part = parts[i];
            if (!part?.trim())
                continue;
            if (i % 3 === 2)
                result.push({
                    type: "code",
                    content: part.trim()
                });
            else if (i % 3 === 0) {
                for (const block of root.formatTextBlock(part))
                    result.push(block);
            }
        }
        return result;
    }

    // Groups contiguous `| cell |` rows into {type:"table"} blocks; every
    // other non-blank line goes through formatLine as before.
    function formatTextBlock(part) {
        const out = [];
        let rows = [];
        const flush = () => {
            if (rows.length > 0) {
                out.push({
                    type: "table",
                    content: rows
                });
                rows = [];
            }
        };
        for (const line of part.split("\n")) {
            if (/^\s*\|.*\|\s*$/.test(line))
                rows.push(line.trim().split("|").slice(1, -1).map(c => c.trim()));
            else {
                flush();
                if (line.trim())
                    out.push(formatLine(line));
            }
        }
        flush();
        return out;
    }

    // Markdown table rows -> Qt RichText table (first row headers).
    // Drops the `| --- |` separator row when present.
    function tableHtml(rows) {
        const body = rows.filter(r => !r.every(c => /^:?-{1,}:?$/.test(c)));
        let h = "<table>";
        body.forEach((r, ri) => {
            h += "<tr>";
            for (const c of r)
                h += ri === 0 ? "<th>" + inline(c) + "</th>" : "<td>" + inline(c) + "</td>";
            h += "</tr>";
        });
        return h + "</table>";
    }

    function formatLine(line) {
        let h = line.match(/^(#{1,6})\s+(.+)$/);
        if (h)
            return {
                type: "header",
                content: inline(h[2])
            };
        let l = line.match(/^(\s*)([-*])\s+(.+)$/);
        if (l)
            return {
                type: "list",
                content: inline(l[3])
            };
        let o = line.match(/^(\s*)(\d+\.)\s+(.+)$/);
        if (o)
            return {
                type: "ordered",
                content: inline(o[3])
            };
        let q = line.match(/^>\s+(.+)$/);
        if (q)
            return {
                type: "quote",
                content: inline(q[1])
            };
        return {
            type: "text",
            content: inline(line)
        };
    }

    function inline(t) {
        return t.replace(/`([^`]+)`/g, "\u200b<tt>$1</tt>\u200b").replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>").replace(/__([^_]+)__/g, "<b>$1</b>").replace(/(?<!\*)\*(?!\*)([^*]+)\*(?!\*)/g, "<i>$1</i>").replace(/(?<!_)_(?!_)([^_]+)_(?!_)/g, "<i>$1</i>").replace(/\[([^\]]+)\]\(([^)]+)\)/g, "<u>$1</u> ($2)");
    }

    function formatTime(ts) {
        const d = new Date(ts);
        const h = String(d.getHours()).padStart(2, "0");
        const m = String(d.getMinutes()).padStart(2, "0");
        return h + ":" + m;
    }

    // Post-process assistant response (already handles via onExited)

    // --- Process Components ---
    Component {
        id: _mkDir
        Process {
            onExited: destroy()
        }
    }
    Component {
        id: _rmDir
        Process {
            onExited: destroy()
        }
    }
    Component {
        id: _clearFile
        Process {
            onExited: destroy()
        }
    }
    Component {
        id: _truncateFile
        Process {
            onExited: destroy()
        }
    }

    Component {
        id: _listDir
        Process {
            id: proc
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const obj = JSON.parse(text);
                        // Envelope {model, sessions} lets us drop a listing
                        // that arrives after a provider switch (stale-guard).
                        // A bare array is the legacy shape: accept it.
                        const arr = Array.isArray(obj) ? obj : obj.sessions;
                        const m = Array.isArray(obj) ? null : obj.model;
                        if (m && m !== root.currentApiModel)
                            return;
                        if (Array.isArray(arr) && arr.length > 0) {
                            root.sessions = arr.map(s => ({
                                        id: s.id,
                                        name: s.name || s.id,
                                        createdAt: Date.now()
                                    }));
                            // Keep the active tab when it still exists
                            // (provider switches share the "default" id).
                            if (!root.sessions.some(s => s.id === root.activeSessionId))
                                root.activeSessionId = root.sessions[0].id;
                        } else {
                            throw new Error("empty");
                        }
                    } catch (e) {
                        root.sessions = [
                            {
                                id: "default",
                                name: "Session 1",
                                createdAt: Date.now()
                            }
                        ];
                        root.activeSessionId = "default";
                    }
                    root.loadMessages();
                    proc.destroy();
                }
            }
        }
    }

    Component {
        id: _modelsProc
        Process {
            id: proc
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const ids = JSON.parse(text);
                        if (Array.isArray(ids) && ids.length > 0)
                            root.modelCache = ids;
                    } catch (e) {}
                    proc.destroy();
                }
            }
        }
    }

    Component {
        id: _renameProc
        Process {
            id: proc
            property string _sid: ""
            property string _name: ""
            onExited: code => {
                if (code === 0) {
                    const sid = _sid;
                    const nm = _name;
                    root.sessions = root.sessions.map(s => s.id === sid ? {
                                id: s.id,
                                name: nm,
                                createdAt: s.createdAt
                            } : s);
                }
                root.renamingSessionId = "";
                proc.destroy();
            }
        }
    }

    Component {
        id: _autoFileProc
        Process {
            id: proc
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const obj = JSON.parse(text);
                        if (obj && typeof obj.path === "string" && typeof obj.name === "string")
                            root.autoFile = {
                                path: obj.path,
                                name: obj.name
                            };
                    } catch (e) {}
                    proc.destroy();
                }
            }
        }
    }

    Component {
        id: _readFile
        Process {
            id: proc
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const msgs = JSON.parse(text);
                        root.messages = Array.isArray(msgs) ? msgs : [];
                    } catch (e) {
                        root.messages = [];
                    }
                    proc.destroy();
                }
            }
        }
    }

    // Reads a session's history file to extract the first message (tooltip context)
    Component {
        id: _firstMsg
        Process {
            id: proc
            property string _sid: ""
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const msgs = JSON.parse(text);
                        if (Array.isArray(msgs) && msgs.length > 0) {
                            root.sessionFirsts[parent._sid] = String(msgs[0].content || "").substring(0, 100);
                        } else {
                            root.sessionFirsts[parent._sid] = "";
                        }
                    } catch (e) {
                        root.sessionFirsts[parent._sid] = "";
                    }
                    proc.destroy();
                }
            }
        }
    }

    Component {
        id: _chatAPI
        Process {
            id: proc
            property int _requestId: 0
            stdout: StdioCollector {
                id: _apiStdout
                // Live tokens: text updates per chunk, not just at process end.
                waitForEnd: false
                property string fullText: ""
                onTextChanged: root.onStreamText(text)
                onStreamFinished: {
                    fullText = text;
                }
            }
            stderr: StdioCollector {
                id: _apiStderr
                property string fullText: ""
                onStreamFinished: {
                    fullText = text;
                }
            }
            onExited: code => {
                // Deferred: the rest of this (synchronous) handler still
                // reads the collectors' buffered text fine.
                proc.destroy();
                if (root._requestSerial !== _requestId)
                    return;
                const stopped = root._stopRequested;
                root._stopRequested = false;
                root.activeProc = null;
                const hadStream = root.streamingText !== "";
                root.streamingText = "";
                streamLines.clear();
                if (stopped) {
                    root.progressStatus = "idle";
                    root.loadMessages();
                    return;
                }
                if (code === 0) {
                    const reply = _apiStdout.fullText.trim();
                    if (reply) {
                        const elapsed = Date.now() - root._sendTime;
                        // Streaming already shows the full text in a placeholder —
                        // skip the transient append to avoid a duplicate bubble,
                        // just notify + reload canonical history.
                        if (!hadStream) {
                            root.messages = root.messages.concat([
                                {
                                    id: "" + (root.messages.length + 1),
                                    role: "assistant",
                                    content: reply,
                                    timestamp: Date.now(),
                                    responseTime: elapsed
                                }
                            ]);
                        }
                        root.progressStatus = "success";
                        if (Settings.chatBotNotify)
                            Notifications.notify({
                                summary: root.currentProviderName(),
                                body: reply
                            });
                        // chatbot.py already saved the canonical history —
                        // reload it instead of appending locally (avoids
                        // id/timestamp drift between display and file).
                        root.loadMessages();
                    } else if (hadStream) {
                        // Stop with empty buffer: drop placeholder, reload partial.
                        root.progressStatus = "success";
                        root.loadMessages();
                    }
                } else {
                    root.progressStatus = "error";
                    const err = _apiStderr.fullText || "Unknown error";
                    let msg = err;
                    if (code === 2 || err.includes("HTTP 401"))
                        msg = "Invalid API key. Check your OpenRouter API key in settings.";
                    else if (err.includes("HTTP 402"))
                        msg = "Insufficient credits. Add credits to your OpenRouter account.";
                    else if (code === 3 || err.includes("HTTP 429"))
                        msg = "Rate limit exceeded. Please wait before trying again.";
                    else if (code === 4)
                        msg = "Conversation too long — trimmed and retried once. Try a fresh session if this repeats.";
                    else if (err.includes("Connection"))
                        msg = "Network error. Check your internet connection.";
                    else if (err.includes("timed out"))
                        msg = "Request timed out. The API took too long to respond.";
                    else {
                        const m = err.match(/ERROR: (.+)/);
                        if (m)
                            msg = m[1];
                    }
                    root.lastError = msg;
                    Notifications.notify({
                        summary: "ChatBot Error",
                        body: msg
                    });
                    // Mid-stream error after partial chunks: canonical file holds
                    // the partial reply (saved by chatbot.py) — reload it so the
                    // streamed text isn't lost behind the error.
                    if (hadStream)
                        root.loadMessages();
                }
            }
        }
    }

    // --- UI ---
    // NOTE: no hover auto-focus on the input — stealing focus on hover
    // clears mouse selection in the message TextEdits above.

    // NOTE: ColumnLayout (not Column) — children size via Layout.*
    // attached props; plain width/height bindings on managed children
    // would fight the layout, so they are derived, not hardcoded.
    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing

        // [1] Info: provider name + description + session (always visible)
        Column {
            Layout.fillWidth: true
            spacing: 2
            Label {
                text: "[" + root.currentProviderName() + "]"
                font.pixelSize: Theme.fontSize
                font.bold: true
                color: Theme.accent
                width: parent.width
                wrapMode: Text.WordWrap
            }
            Label {
                text: root.currentProviderDescription()
                font.pixelSize: Theme.fontSize - 1
                color: Theme.fgDim
                width: parent.width
                wrapMode: Text.WordWrap
            }
            Label {
                text: "Session: " + root.activeSessionName()
                font.pixelSize: Theme.fontSize - 1
                color: Theme.fgDim
                width: parent.width
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
            }
        }

        // [2] Setup guide (only when API key missing)
        Column {
            Layout.fillWidth: true
            spacing: Theme.spacing
            visible: root.apiKey() === ""
            Rectangle {
                width: parent.width
                height: setupGuide.implicitHeight + 8
                color: Theme.surfaceActive
                radius: Theme.radius
                border.color: Theme.accent

                Column {
                    id: setupGuide
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 6
                    spacing: Theme.spacing
                    AppButton {
                        text: "1. Visit openrouter and Sign-up for FREE  \u{f08e}"
                        tooltipText: "Open openrouter.ai in the browser"
                        width: parent.width
                        implicitHeight: 28
                        onClicked: Quickshell.execDetached(["xdg-open", "https://openrouter.ai/"])
                    }
                    AppButton {
                        text: "2. Generate a FREE API key  \u{f08e}"
                        tooltipText: "Open the OpenRouter API key page"
                        width: parent.width
                        implicitHeight: 28
                        onClicked: Quickshell.execDetached(["xdg-open", "https://openrouter.ai/settings/keys"])
                    }
                    AppButton {
                        text: "3. Copy & Paste it in the settings"
                        tooltipText: "Open the OpenRouter key in settings"
                        width: parent.width
                        implicitHeight: 28
                        onClicked: root.goToSettings("openrouter.key")
                    }
                }
            }
        }

        // [3] Messages (fills leftover space; no hardcoded height math)
        SmoothFlickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: flick.width
            contentHeight: msgColumn.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            ScrollBar.vertical: ScrollBar {}

            Column {
                id: msgColumn
                width: flick.width
                spacing: Theme.spacing

                Repeater {
                    id: msgRepeater
                    model: root.messages
                    delegate: Rectangle {
                        width: msgColumn.width
                        // NOTE: msgColumn is a Column positioner, not a
                        // ColumnLayout — it positions children by their
                        // explicit height, ignoring implicitHeight.
                        // An implicitHeight-only binding leaves height == 0
                        // (content overflows) so the bubble never hugs text.
                        height: msgContent.implicitHeight + 16
                        color: modelData.role === "user" ? Theme.surfaceActive : Theme.surface
                        radius: Theme.radius

                        // Message text is mouse/keyboard selectable
                        // (bubble-wide click-to-copy removed — it swallowed
                        // drag gestures and blocked selection).

                        Column {
                            id: msgContent
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: Theme.pad
                            spacing: 3

                            Row {
                                id: messageHeader
                                width: parent.width
                                spacing: Theme.spacing

                                Label {
                                    id: roleLabel
                                    anchors.verticalCenter: messageHeader.verticalCenter
                                    text: modelData.role === "user" ? "\u{F007} You" : "\u{E73B} Assistant"
                                    font.pixelSize: Theme.fontSize - 1
                                    font.bold: true
                                    color: Theme.accent
                                }

                                Item {
                                    width: Math.max(0, messageHeader.width - roleLabel.width - actionsRow.implicitWidth - 12)
                                    height: 1
                                }

                                Row {
                                    id: actionsRow
                                    spacing: Theme.spacing
                                    anchors.verticalCenter: messageHeader.verticalCenter

             // Per-message revert (user only, OpenCode-style):
                                    // drop this message and everything after it,
                                    // restore its text into the input for editing.
                                    AppButton {
                                        anchors.verticalCenter: actionsRow.verticalCenter
                                        visible: modelData.role === "user"
                                        text: "\uf0e2"
                                        pixelSize: Theme.fontSizeBadge
                                        tooltipText: "Revert to this message"
                                        onClicked: root.revertMessage(index)
                                    }
                                    // Whole-message copy (raw markdown).
                                    AppButton {
                                        anchors.verticalCenter: actionsRow.verticalCenter
                                        text: "\uf0c5"
                                        pixelSize: Theme.fontSizeBadge
                                        tooltipText: "Copy whole message"
                                        onClicked: root.copyToClipboard(modelData.content)
                                    }
                       
                                }
                            }

                            // Message content (flat selectable TextEdits — no wrapper Column per
                            // block, so no extra spacing/implicitHeight per line)
                            Repeater {
                                model: root.formatMessage(modelData.content)
                                delegate: TextEdit {
                                    property var txt: modelData.type === "list" ? "\u{2022} " + modelData.content : modelData.type === "ordered" ? "  " + modelData.content : modelData.type === "quote" ? "\u{276E} " + modelData.content : modelData.type === "header" ? modelData.content : modelData.type === "table" ? root.tableHtml(modelData.content) : modelData.content ?? ""
                                    text: modelData.type === "code" ? modelData.content : txt
                                    font.pixelSize: modelData.type === "header" ? Theme.fontSize + 2 : Theme.fontSize
                                    font.bold: modelData.type === "header"
                                    font.family: modelData.type === "code" ? "JetBrainsMono NFP" : Theme.fontFamily
                                    color: modelData.type === "code" ? Theme.fgDim : Theme.fg
                                    selectionColor: Theme.accent
                                    selectedTextColor: Theme.accentFg
                                    wrapMode: TextEdit.WordWrap
                                    textFormat: modelData.type === "code" ? TextEdit.PlainText : TextEdit.RichText
                                    readOnly: true
                                    selectByMouse: true
                                    selectByKeyboard: true
                                    activeFocusOnPress: true
                                    width: msgContent.width
                                    // Code blocks need room for the copy pill
                                    topPadding: modelData.type === "code" ? 22 : 0
                                    // Code block copy button
                                    AppButton {
                                        visible: modelData.type === "code"
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                       
                                        idleBg: Theme.bg
                                        idleFg: Theme.accent
                                        hoverFg: Theme.accent
                                        text: "\uf0c5"
                                        pixelSize: Theme.fontSizeBadge
                                        tooltipText: "Copy code"
                                        onClicked: root.copyToClipboard(modelData.content)
                                    }
                                }
                            }

                            // Info: timestamp + response time
                            Row {
                                spacing: Theme.spacing
                                Label {
                                    text: root.formatTime(modelData.timestamp)
                                    font.pixelSize: Theme.fontSize - 2
                                    color: Theme.fgDim
                                }
                                Label {
                                    text: modelData.responseTime ? "Response Time: " + modelData.responseTime + " ms" : ""
                                    font.pixelSize: Theme.fontSize - 2
                                    color: Theme.fgDim
                                }
                            }

                            // Assistant-generated image (scaled down)
                            // NOTE: Column positioners do NOT collapse
                            // visible:false children — a fixed height:200
                            // reserves ~200px in every text-only bubble.
                            // Collapse to 0 when there is no image.
                            // IMPORTANT: derive hasImage from the string in
                            // modelData, NOT from `source` (a url alias):
                            // `source !== ""` is always true for urls, so the
                            // image slot never collapsed.
                            AppImage {
                                property bool hasImage: modelData.image !== undefined && modelData.image !== null && String(modelData.image).length > 0
                                width: msgContent.width
                                height: hasImage ? 200 : 0
                                source: hasImage ? modelData.image : ""

                                clip: true
                                visible: hasImage
                            }
                        }
                    }
                }

                // Live streaming bubble — OUTSIDE the Repeater, driven by the
                // incremental streamLines model (see updateStreamLines).
                // Only brand-new lines are appended (their delegates fade in
                // once); the growing tail updates in place. The settled
                // history Repeater is never touched mid-stream.
                // NOTE: explicit height (Column ignores implicitHeight, see
                // above) + height 0 when empty: Column positioners do NOT
                // collapse visible:false children (see AppImage note above).
                Rectangle {
                    property bool hasStream: root.streamingText !== ""
                    width: msgColumn.width
                    height: hasStream ? streamingContent.implicitHeight + 16 : 0
                    visible: hasStream
                    color: Theme.surface
                    radius: Theme.radius
                    clip: true

                    Column {
                        id: streamingContent
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Theme.pad
                        spacing: 3

                        Label {
                            text: "\u{E73B} Assistant  \u25CF streaming..."
                            font.pixelSize: Theme.fontSize - 1
                            font.bold: true
                            color: Theme.accent
                        }

                        // Incremental line view: one delegate per streamed line.
                        // Appends fade in; in-place tail/code updates don't.
                        // No per-line copy buttons — this is a transient view,
                        // the settled bubble carries block copy on reload.
                        Repeater {
                            model: streamLines
                            delegate: TextEdit {
                                property var block: model.code ? {
                                    type: "code",
                                    content: model.line
                                } : root.formatLine(model.line)
                                property var txt: block.type === "list" ? "\u{2022} " + block.content : block.type === "ordered" ? "  " + block.content : block.type === "quote" ? "\u{276E} " + block.content : block.type === "header" ? block.content : block.content ?? ""
                                text: block.type === "code" ? block.content : txt
                                font.pixelSize: block.type === "header" ? Theme.fontSize + 2 : Theme.fontSize
                                font.bold: block.type === "header"
                                font.family: block.type === "code" ? "JetBrainsMono NFP" : Theme.fontFamily
                                color: block.type === "code" ? Theme.fgDim : Theme.fg
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.accentFg
                                wrapMode: TextEdit.WordWrap
                                textFormat: block.type === "code" ? TextEdit.PlainText : TextEdit.RichText
                                readOnly: true
                                selectByMouse: true
                                selectByKeyboard: true
                                activeFocusOnPress: true
                                width: streamingContent.width
                                // Blank lines stay in the model to keep row
                                // indices stable; collapse them to 0 height.
                                height: model.line === "" ? 0 : implicitHeight
                                visible: model.line !== ""
                                // Fade-in per generated line. ListModel set() /
                                // setProperty() never refire onCompleted, so
                                // only genuinely new lines animate.
                                opacity: 0
                                Component.onCompleted: opacity = 1
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }

                        // Mainstream-style block cursor while tokens stream.
                        Rectangle {
                            width: 8
                            height: Theme.fontSize + 2
                            color: Theme.accent
                            radius: width / 2
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation {
                                    from: 1
                                    to: 0.15
                                    duration: 530
                                }
                                NumberAnimation {
                                    from: 0.15
                                    to: 1
                                    duration: 530
                                }
                            }
                        }
                    }
                }

                // Thinking bubble — visible while waiting for the first
                // token (loading but nothing streamed yet). The loading
                // indicator lives in the messages flow, styled as an
                // assistant bubble.
                // NOTE: explicit height + 0 when idle (Column positioners
                // do NOT collapse visible:false children).
                Rectangle {
                    id: thinkingBubble
                    property bool isThinking: root.progressStatus === "loading" && root.streamingText === ""
                    property int dots: 1
                    width: msgColumn.width
                    height: isThinking ? thinkingContent.implicitHeight + 16 : 0
                    visible: isThinking
                    color: Theme.surface
                    radius: Theme.radius
                    clip: true

                    Timer {
                        interval: 500
                        repeat: true
                        running: thinkingBubble.isThinking
                        onTriggered: thinkingBubble.dots = thinkingBubble.dots % 3 + 1
                    }

                    Row {
                        id: thinkingContent
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Theme.pad
                        spacing: Theme.spacing

                        BusyIndicator {
                            width: 16
                            height: 16
                            running: thinkingBubble.isThinking
                        }

                        Label {
                            text: "\u{E73B} Assistant  Thinking" + ".".repeat(thinkingBubble.dots)
                            font.pixelSize: Theme.fontSize - 1
                            font.bold: true
                            color: Theme.fgDim
                        }
                    }
                }

                // Error bubble — surfaces the last failure inline in the
                // messages flow (replaces the old bottom pill error state).
                Rectangle {
                    property bool hasError: root.progressStatus === "error"
                    width: msgColumn.width
                    height: hasError ? errorContent.implicitHeight + 16 : 0
                    visible: hasError
                    color: Theme.dangerBg
                    radius: Theme.radius
                    border.color: Theme.danger
                    clip: true

                    Column {
                        id: errorContent
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Theme.pad
                        spacing: 3

                        Label {
                            text: "⚠ Assistant — error"
                            font.pixelSize: Theme.fontSize - 1
                            font.bold: true
                            color: Theme.danger
                        }

                        Label {
                            text: root.lastError
                            font.pixelSize: Theme.fontSize
                            color: Theme.fg
                            width: errorContent.width
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Item {
                    width: 1
                    height: 4
                }
            }

            // Auto-scroll to bottom on new messages (100ms delay after content
            // update). Stops auto-scrolling once the user scrolls up.
            onContentHeightChanged: {
                if (root._shouldScroll) {
                    var target = Math.max(0, contentHeight - height);
                    contentY = target;
                }
            }
            Component.onCompleted: root._shouldScroll = true
            onMovementStarted: root._shouldScroll = false
        }

        // [4] BottomBar: input + clear + image toggle + session tabs + API tabs
        Column {
            Layout.fillWidth: true
            spacing: Theme.spacing

                Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fgDim
                    elide: Text.ElideMiddle
                    text: (Settings.chatBotContext.file ?? true) ? (root.autoFile.name !== "" ? "📄 " + root.autoFile.name : "no file focused") : "auto-file off"
                    HoverHandler {
                        id: autoFileHover
                    }
                    AppTooltip {
                        visible: autoFileHover.hovered && root.autoFile.path !== ""
                        text: root.autoFile.path
                    }
                }
 

            // Slash-command popup: commands + session hits for
            // /list /sessions /switch /delete.
            Rectangle {
                width: parent.width
                // Column positions by explicit height: collapse to 0 hidden.
                height: visible ? slashList.implicitHeight + 12 : 0
                visible: root.slashPopupCount() > 0 && root.progressStatus !== "loading"
                color: Theme.surface
                radius: Theme.radius
                border.color: Theme.border
                clip: true

                Column {
                    id: slashList
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6
                    spacing: 2

                    Repeater {
                        model: root.slashFilter()
                        delegate: AppButton {
                            toggle: true
                            checked: index === root.slashIndex
                            width: slashList.width
                            implicitHeight: 30
                            text: "/" + modelData.name + "  —  " + modelData.description
                            tooltipText: "Run command /" + modelData.name
                            onClicked: {
                                const p = root.parseSlash(inputField.text);
                                root.runSlashCommand(modelData.name, p ? p.arg : "");
                            }
                        }
                    }
                    Repeater {
                        model: root.sessionMatches()
                        delegate: AppButton {
                            property int cmdCount: root.slashFilter().length
                            toggle: true
                            checked: (index + cmdCount) === root.slashIndex
                            width: slashList.width
                            implicitHeight: 30
                            text: (index + 1) + ". " + modelData.name + (modelData.id === root.activeSessionId ? "  (active)" : "")
                            tooltipText: (root.sessionFirsts[modelData.id] || "") + "\n" + modelData.id
                            onClicked: {
                                const p = root.parseSlash(inputField.text);
                                const cmd = p ? p.cmd : "switch";
                                if (cmd === "delete")
                                    root.deleteSession(modelData.id);
                                else
                                    root.switchToSession(modelData.id);
                                inputField.text = "";
                            }
                        }
                    }
                }
            }

            // Input row (RowLayout: input stretches, buttons keep size)
            RowLayout {
                width: parent.width
                spacing: Theme.spacing
                // Multiline input (word wrap): Enter sends, Shift+Enter inserts
                // a newline. TextArea is NOT scrollable by itself (Qt docs),
                // so it lives inside a ScrollView: grows with content up to
                // 120px, then the view clips + scrolls (wheel/drag/cursor).
                ScrollView {
                    id: inputScroll
                    Layout.fillWidth: true
                    // Single-line height when empty, grows with content up to
                    // 120px then scrolls internally.
                    Layout.preferredHeight: Math.min(120, Math.max(inputField.font.pixelSize + inputField.topPadding + inputField.bottomPadding + 4, inputField.contentHeight + inputField.topPadding + inputField.bottomPadding))
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    AppTextArea {
                        id: inputField
                        width: inputScroll.availableWidth
                        placeholderText: root.progressStatus === "loading" ? "Streaming... press Stop or wait" : "Ask anything... (/ commands, Enter send)"
                        inputMethodHints: Qt.ImhPreferLowercase
                    onTextChanged: root.slashIndex = 0
                    Keys.onReturnPressed: {
                        root.submitInput(event);
                    }
                    Keys.onEnterPressed: {
                        root.submitInput(event);
                    }
                    Keys.onUpPressed: {
                        if (root.slashPopupCount() > 1) {
                            root.slashIndex = (root.slashIndex + root.slashPopupCount() - 1) % root.slashPopupCount();
                            event.accepted = true;
                        } else {
                            event.accepted = false;
                        }
                    }
                    Keys.onDownPressed: {
                        if (root.slashPopupCount() > 1) {
                            root.slashIndex = (root.slashIndex + 1) % root.slashPopupCount();
                            event.accepted = true;
                        } else {
                            event.accepted = false;
                        }
                    }
                    Keys.onEscapePressed: {
                        if (root.slashPopupCount() > 0) {
                            inputField.text = "";
                            event.accepted = true;
                        } else {
                            event.accepted = false;
                        }
                    }
                    }
                }
                // Stop only (Enter sends; /clear wipes): visible while streaming.
                // Stop kills the process (SIGTERM -> backend saves the partial reply).
                AppButton {
                    visible: root.progressStatus === "loading"
                    implicitWidth: 36
                    implicitHeight: 40
                    text: "\uf04d"
                    tooltipText: "Stop generation"
                    onClicked: root.stopGeneration()
                }
            }

            // Context bar (Minimal+explicit): chips toggle what is injected,
            // path field attaches a file head. Chips persist via Settings.
            // Centered like the provider segmented control below.
            RowLayout {
                width: parent.width
                spacing: Theme.spacing
                AppFilterChips {
                    Layout.alignment: Qt.AlignHCenter
                    chipHeight: 26
                    model: [
                        {
                            value: "ws",
                            label: "WS",
                            tooltip: "Include active workspace in prompt context"
                        },
                        {
                            value: "win",
                            label: "Win",
                            tooltip: "Include focused window in prompt context"
                        },
                        {
                            value: "clip",
                            label: "Clip",
                            tooltip: "Include clipboard head in prompt context"
                        },
                        {
                            value: "file",
                            label: "File",
                            tooltip: "Auto-include the file open in the focused editor"
                        }
                    ]
                    checkedValues: {
                        const onValues = [];
                        if (Settings.chatBotContext.ws ?? true)
                            onValues.push("ws");
                        if (Settings.chatBotContext.win ?? true)
                            onValues.push("win");
                        if (Settings.chatBotContext.clip ?? true)
                            onValues.push("clip");
                        if (Settings.chatBotContext.file ?? true)
                            onValues.push("file");
                        return onValues;
                    }
                    allowEmpty: true
                    onToggled: (i, value, checked) => {
                        Settings.chatBotContext = Object.assign({}, Settings.chatBotContext, {
                            [value]: checked
                        });
                        if (value === "file")
                            root.refreshAutoFile();
                    }
                }
            }

            // Session management is slash-only now (/new /list /switch
            // /rename /delete) — no tab UI. Active session shows in [1].

            // API provider tabs (stretched row; filtered by live model list)
            RowLayout {
                width: parent.width
                spacing: Theme.spacing
                AppSegmentedControl {
                    Layout.alignment: Qt.AlignHCenter
                    model: root.visibleProviders().map(p => ({
                        value: p.value,
                        label: p.icon,
                        tooltip: "<b>" + p.name + "</b>\n" + p.description
                    }))
                    currentIndex: Math.max(0, root.visibleProviders().findIndex(p => p.value === root.currentApiModel))
                    onActivated: (i, v) => {
                        root.currentApiModel = v;
                        Settings.chatBotApi = v;
                        root.loadSessions();
                    }
                }
            }
        }

        // [5] removed: loading/error now render inline in the messages
        // flow (thinking bubble + error bubble above), not as a bottom pill.
    }

    // --- utility funcs ---
    function currentProviderName() {
        for (const p of root.providers)
            if (p.value === root.currentApiModel)
                return p.name;
        return root.currentApiModel;
    }
    function currentProviderDescription() {
        for (const p of root.providers)
            if (p.value === root.currentApiModel)
                return p.description;
        return "";
    }
    function currentImageGenSupport() {
        for (const p of root.providers)
            if (p.value === root.currentApiModel)
                return p.imageGenerationSupport;
        return false;
    }

    // Enter submits; Shift+Enter inserts a newline (default TextArea
    // behaviour). Return and keypad Enter share this one path.
    function submitInput(event) {
        if (root.trySlashCommand()) {
            event.accepted = true;
            return;
        }
        if (event.modifiers & Qt.ShiftModifier) {
            event.accepted = false;
            return;
        }
        if (root.progressStatus === "loading") {
            event.accepted = true;
            return;
        }
        if (inputField.text.trim()) {
            root.sendMessage(inputField.text);
            inputField.text = "";
        }
        event.accepted = true;
    }

    function copyToClipboard(t) {
        // Model text carries literal \n escapes; unescape before copying.
        const norm = String(t).replace(/\\r\\n/g, "\n").replace(/\\n/g, "\n");
        ClipboardService.copy(norm);
    }
    function copyMessage(t) {
        copyToClipboard(t);
    }

    function goToSettings(target) {
        if (typeof Registry !== "undefined" && Registry.selectLeftTab)
            Registry.selectLeftTab("SettingsWidget", target, root.monitorName);
    }
}
