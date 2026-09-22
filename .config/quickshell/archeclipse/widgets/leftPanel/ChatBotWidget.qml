import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.widgets.shared
import qs.services

// ChatBot widget — port of ChatBot.tsx
// Features: multiple AI providers (OpenRouter), session create/delete,
// markdown rendering (headers/lists/quotes/code w/ copy), message timestamps
// + response time + click-to-copy, image-gen toggle, info/setup guide,
// progress indicator, auto-scroll, auto-focus, multi-line input
Item {
    id: root

    // --- State ---
    property var messages: []
    property string activeSessionId: "default"
    // The provider persists across launches via Settings.chatBotApi.
    property string currentApiModel: Settings.chatBotApi
    property string progressStatus: "idle" // idle | loading | error | success
    property var sessions: []
    property int _sendTime: 0
    property bool _shouldScroll: true
    property var sessionFirsts: ({})
    // chatbot.py owns its files under ~/.cache/quickshell/chatbot
    // (CACHE_DIR hardcoded in the script) — read the same dir it writes,
    // or sessions/history silently fork.
    property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell/chatbot"
    property string pythonScript: Quickshell.env("HOME") + "/.config/quickshell/archeclipse/scripts/chatbot.py"

    // Provider list (from api.constants.ts)
    property var providers: [
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
    }

    // --- Helpers ---
    function apiKey() {
        return Settings.apiKey("openrouter", "key");
    }

    // --- Session Management ---
    function getHistoryPath(sid) {
        return cacheDir + "/" + currentApiModel + "/sessions/" + (sid || activeSessionId) + "/history.json";
    }

    function getSessionsDir() {
        return cacheDir + "/" + currentApiModel + "/sessions";
    }

    function ensureSessionDir(sid) {
        const p = _mkDir.createObject(root);
        p.command = ["bash", "-c", "mkdir -p " + JSON.stringify(cacheDir + "/" + currentApiModel + "/sessions/" + sid)];
        p.running = true;
    }

    function loadSessions() {
        const dir = getSessionsDir();
        const p = _listDir.createObject(root);
        p.command = ["bash", "-c", "mkdir -p " + JSON.stringify(dir) + " && find " + JSON.stringify(dir) + " -mindepth 1 -maxdepth 1 -type d -printf \"%f\\n\""];
        p.running = true;
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
        p.command = ["cat", cacheDir + "/" + currentApiModel + "/sessions/" + sid + "/history.json"];
        p.running = true;
    }

    // NOTE: chatbot.py loads/appends/saves history.json itself (both user
    // and assistant messages, canonical ids/timestamps). Never rewrite the
    // file from QML — a prior saveHistory() via bash printf clobbered the
    // canonical entries and broke on quotes. In-memory state is display-only;
    // after a reply, reload the canonical file (see onExited below).

    // Create new session
    function createSession() {
        const newId = "session-" + Date.now();
        ensureSessionDir(newId);
        const newSession = {
            id: newId,
            name: "Session " + (root.sessions.length + 1),
            createdAt: Date.now()
        };
        root.sessions = root.sessions.concat([newSession]);
        root.activeSessionId = newId;
        root.messages = [];
    }

    // Delete a session
    function deleteSession(sessionId) {
        if (root.sessions.length <= 1) {
            Notifications.notify({
                summary: "Cannot Delete",
                body: "You must have at least one session"
            });
            return;
        }
        const p = _rmDir.createObject(root);
        p.command = ["rm", "-rf", cacheDir + "/" + currentApiModel + "/sessions/" + sessionId];
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

    // --- API Communication ---
    function sendMessage(text) {
        if (!text.trim())
            return;
        root._sendTime = Date.now();
        const sendTime = root._sendTime;
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
            root.progressStatus = "error";
            return;
        }
        root.progressStatus = "loading";
        const p = _chatAPI.createObject(root);
        p.command = ["python3", root.pythonScript, root.currentApiModel, text, key, root.activeSessionId];
        p.running = true;
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
                for (const line of part.split("\n")) {
                    if (line.trim())
                        result.push(formatLine(line));
                }
            }
        }
        return result;
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
        return t.replace(/`([^`]+)`/g, "\u200b<tt>$1</tt>\u200b").replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>").replace(/__([^_]+)__/g, "<b>$1</b>").replace(/(?<!\*)\*(?!\*)([^*]+)\*(?!\*)/g, "<i>$1</i>").replace(/(?<!_)_(?!_)([^_]+)_(?!_)/g, "<i>$1</i>").replace(/\[([^\]]+)\]\([^)]+\)/g, "<u>$1</u>");
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
        Process {}
    }
    Component {
        id: _rmDir
        Process {}
    }
    Component {
        id: _clearFile
        Process {}
    }

    Component {
        id: _listDir
        Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    const output = text.trim();
                    const ids = output ? output.split("\n").filter(s => s.length > 0) : [];
                    if (ids.length === 0) {
                        root.ensureSessionDir("default");
                        root.sessions = [
                            {
                                id: "default",
                                name: "Session 1",
                                createdAt: Date.now()
                            }
                        ];
                        root.activeSessionId = "default";
                    } else {
                        ids.sort((a, b) => {
                            if (a === "default")
                                return -1;
                            if (b === "default")
                                return 1;
                            return a.localeCompare(b);
                        });
                        root.sessions = ids.map((id, i) => ({
                                    id,
                                    name: "Session " + (i + 1),
                                    createdAt: Date.now()
                                }));
                        root.activeSessionId = root.sessions[0].id;
                    }
                    root.loadMessages();
                }
            }
        }
    }

    Component {
        id: _readFile
        Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const msgs = JSON.parse(text);
                        root.messages = Array.isArray(msgs) ? msgs : [];
                    } catch (e) {
                        root.messages = [];
                    }
                }
            }
        }
    }

    // Reads a session's history file to extract the first message (tooltip context)
    Component {
        id: _firstMsg
        Process {
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
                }
            }
        }
    }

    Component {
        id: _chatAPI
        Process {
            stdout: StdioCollector {
                id: _apiStdout
                property string fullText: ""
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
                if (code === 0) {
                    const reply = _apiStdout.fullText.trim();
                    if (reply) {
                        const elapsed = Date.now() - root._sendTime;
                        root.messages = root.messages.concat([
                            {
                                id: "" + (root.messages.length + 1),
                                role: "assistant",
                                content: reply,
                                timestamp: Date.now(),
                                responseTime: elapsed
                            }
                        ]);
                        root.progressStatus = "success";
                        Notifications.notify({
                            summary: root.currentProviderName(),
                            body: reply
                        });
                        // chatbot.py already saved the canonical history —
                        // reload it instead of appending locally (avoids
                        // id/timestamp drift between display and file).
                        root.loadMessages();
                    }
                } else {
                    root.progressStatus = "error";
                    const err = _apiStderr.fullText || "Unknown error";
                    let msg = err;
                    if (err.includes("HTTP 401"))
                        msg = "Invalid API key. Check your OpenRouter API key in settings.";
                    else if (err.includes("HTTP 402"))
                        msg = "Insufficient credits. Add credits to your OpenRouter account.";
                    else if (err.includes("HTTP 429"))
                        msg = "Rate limit exceeded. Please wait before trying again.";
                    else if (err.includes("Connection"))
                        msg = "Network error. Check your internet connection.";
                    else if (err.includes("timed out"))
                        msg = "Request timed out. The API took too long to respond.";
                    else {
                        const m = err.match(/ERROR: (.+)/);
                        if (m)
                            msg = m[1];
                    }
                    Notifications.notify({
                        summary: "ChatBot Error",
                        body: msg
                    });
                }
            }
        }
    }

    // --- UI ---
    // Auto-focus input on hover
    HoverHandler {
        target: root
        onHoveredChanged: {
            if (hovered && inputField)
                inputField.forceActiveFocus();
        }
    }

    // NOTE: ColumnLayout (not Column) — children size via Layout.*
    // attached props; plain width/height bindings on managed children
    // would fight the layout, so they are derived, not hardcoded.
    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // [1] Info: provider name + description (always visible)
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
        }

        // [2] Setup guide (only when API key missing)
        Column {
            Layout.fillWidth: true
            spacing: 4
            visible: root.apiKey() === ""
            Rectangle {
                width: parent.width
                height: setupGuide.implicitHeight + 8
                color: Theme.surfaceActive
                radius: 8
                border.color: Theme.accent

                Column {
                    id: setupGuide
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 6
                    spacing: 4
                    AppButton {
                        text: "1. Visit openrouter and Sign-up for FREE  \u{f08e}"
                        width: parent.width
                        implicitHeight: 28
                        onClicked: Quickshell.execDetached(["xdg-open", "https://openrouter.ai/"])
                    }
                    AppButton {
                        text: "2. Generate a FREE API key  \u{f08e}"
                        width: parent.width
                        implicitHeight: 28
                        onClicked: Quickshell.execDetached(["xdg-open", "https://openrouter.ai/settings/keys"])
                    }
                    AppButton {
                        text: "3. Copy & Paste it in the settings"
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
                spacing: 8

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
                        radius: 8

                        // Fade-in on arrival (NotificationPopups parity).
                        opacity: 0
                        Component.onCompleted: opacity = 1
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }

                        // Click to copy whole message (except code blocks)
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.copyMessage(modelData.content)
                            cursorShape: Qt.PointingHandCursor
                        }

                        Column {
                            id: msgContent
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            spacing: 3

                            Label {
                                text: modelData.role === "user" ? "\u{F007} You" : "\u{E73B} Assistant"
                                font.pixelSize: Theme.fontSize - 1
                                font.bold: true
                                color: Theme.accent
                            }

                            // Message content (flat Labels — no wrapper Column per
                            // block, so no extra spacing/implicitHeight per line)
                            Repeater {
                                model: root.formatMessage(modelData.content)
                                delegate: Label {
                                    property var txt: modelData.type === "list" ? "\u{2022} " + modelData.content : modelData.type === "ordered" ? "  " + modelData.content : modelData.type === "quote" ? "\u{276E} " + modelData.content : modelData.type === "header" ? modelData.content : modelData.content ?? ""
                                    text: modelData.type === "code" ? modelData.content : txt
                                    font.pixelSize: modelData.type === "header" ? Theme.fontSize + 2 : Theme.fontSize
                                    font.bold: modelData.type === "header"
                                    font.family: modelData.type === "code" ? "JetBrainsMono NFP" : Theme.fontFamily
                                    color: modelData.type === "code" ? Theme.fgDim : Theme.fg
                                    wrapMode: Text.WordWrap
                                    textFormat: modelData.type === "code" ? Text.PlainText : Text.RichText
                                    width: msgContent.width
                                    // Code blocks need room for the copy pill
                                    topPadding: modelData.type === "code" ? 22 : 0
                                    // Code block copy button
                                    AppButton {
                                        visible: modelData.type === "code"
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        width: 54
                                        height: 20
                                        cornerRadius: 4
                                        idleBg: Theme.bg
                                        idleFg: Theme.accent
                                        hoverFg: Theme.accent
                                        outlined: true
                                        outlineColor: Theme.accent
                                        text: "copy"
                                        pixelSize: 9
                                        tooltipText: "Copy code"
                                        onClicked: root.copyToClipboard(modelData.content)
                                    }
                                }
                            }

                            // Info: timestamp + response time
                            Row {
                                spacing: 8
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
            spacing: 6

            // Input row (RowLayout: input stretches, buttons keep size)
            RowLayout {
                width: parent.width
                spacing: 6
                // Multiline input (word wrap): Enter sends, Shift+Enter inserts
                // a newline.
                AppTextArea {
                    id: inputField
                    placeholderText: "Ask anything... (Enter send, Shift+Enter newline)"
                    Layout.fillWidth: true
                    inputMethodHints: Qt.ImhPreferLowercase
                    Keys.onReturnPressed: {
                        if (event.modifiers & Qt.ShiftModifier)
                            // newline (default)
                            return;
                        if (inputField.text.trim()) {
                            root.sendMessage(inputField.text);
                            inputField.text = "";
                        }
                        event.accepted = true;
                    }
                    Keys.onEnterPressed: {
                        if (event.modifiers & Qt.ShiftModifier)
                            return;
                        if (inputField.text.trim()) {
                            root.sendMessage(inputField.text);
                            inputField.text = "";
                        }
                        event.accepted = true;
                    }
                }
                AppButton {
                    implicitWidth: 36
                    implicitHeight: 40
                    text: "\uf1f8"
                    onClicked: root.clearMessages()
                    tooltipText: "Clear current session messages"
                }
            }

            // Session tabs + create button
            // Session tabs + create button (RowLayout: tabs stretch)
            RowLayout {
                width: parent.width
                spacing: 4
                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: root.sessions
                        delegate: AppButton {
                            toggle: true
                            checked: modelData.id === root.activeSessionId
                            implicitHeight: 26
                            // Session tab label is the session name
                            text: modelData.name
                            onClicked: {
                                root.activeSessionId = modelData.id;
                                root.loadMessages();
                            }
                            // Right-click to delete
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                onClicked: root.deleteSession(modelData.id)
                            }
                            // Tooltip with first-message context (shows
                            // "Right-click to delete\nContext: {first message}")
                            HoverHandler {
                                onHoveredChanged: if (hovered)
                                    root.fetchFirstMessage(modelData.id)
                            }
                            tooltipText: "<b>Right-click to delete</b>" + (root.sessionFirsts[modelData.id] ? "\n\n<b>Context:</b> " + root.sessionFirsts[modelData.id] : "")
                        }
                    }
                }
                AppButton {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 26
                    text: "\u{F067}"
                    tooltipText: "Create new session"
                    onClicked: root.createSession()
                }
            }

            // API provider tabs (stretched row)
            RowLayout {
                width: parent.width
                spacing: 4
                AppSegmentedControl {
                    Layout.alignment: Qt.AlignHCenter
                    model: root.providers.map(p => ({
                        value: p.value,
                        label: p.icon,
                        tooltip: "<b>" + p.name + "</b>\n" + p.description
                    }))
                    currentIndex: root.providers.findIndex(p => p.value === root.currentApiModel)
                    onActivated: (i, v) => {
                        root.currentApiModel = v;
                        Settings.chatBotApi = v;
                        root.loadSessions();
                    }
                }
            }
        }

        // [5] Progress indicator (shared AppProgress pill)
        AppProgress {
            Layout.fillWidth: true
            status: root.progressStatus
            variant: "pill"
        }
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

    function copyToClipboard(t) {
        const norm = String(t).replace(/\\r\\n/g, "\n").replace(/\\n/g, "\n");
        const shellEsc = "'" + norm.replace(/'/g, "'\"'\"'") + "'";
        Quickshell.execDetached(["bash", "-c", "wl-copy -- " + shellEsc]);
    }
    function copyMessage(t) {
        copyToClipboard(t);
    }

    function goToSettings(target) {
        if (typeof Registry !== "undefined" && Registry.selectLeftTab)
            Registry.selectLeftTab("SettingsWidget", target);
    }
}
