import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

// Greetd auth backend. LockContext-compatible subset for the greeter surface:
// shared props (currentText/promptText/authInProgress/showFailure),
// start()/tryAuth()/cancel() verbs, launched()/failed() signals.
// NOTE: GreetdState has no Idle value (Inactive/Authenticating/ReadyToLaunch/
// Launching/Launched) — Inactive is the pre-session state.
// Race guard: the password prompt can arrive before the user submits, or the
// user can submit before the prompt arrives. Submissions stash into
// pendingResponse and flush when the non-echo prompt arrives; prompts wait
// (promptWaiting) instead of answering with a stale/empty currentText.
Scope {
    id: root
    signal launched()
    signal failed()
    property string currentText: ""
    property string userName: ""
    // All human users for the picker. NSS-aware (getent covers
    // LDAP/SSSD, not just /etc/passwd); shells that cannot log in
    // (nologin/false) are not login candidates.
    property var users: []
    function selectUser(name) {
        if (root.userName === name)
            return;
        root.cancel();
        root.userName = name;
    }
    Process {
        command: ["getent", "passwd"]
        running: true
        stdout: StdioCollector {
            id: passwdOut
            onStreamFinished: {
                var names = [];
                var lines = passwdOut.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].split(":");
                    if (f.length < 7)
                        continue;
                    var uid = parseInt(f[2], 10);
                    var shell = f[6].trim();
                    if (uid >= 1000 && uid !== 65534
                            && shell.indexOf("nologin") === -1
                            && !shell.endsWith("/false") && shell !== "false")
                        names.push(f[0]);
                }
                root.users = names;
                if (root.userName === "" && names.length > 0)
                    root.userName = names[0];
            }
        }
    }
    // Initial prompt is the password box's placeholder (the username
    // field has its own): starting as "Username" renders two
    // username-looking inputs. Real prompts arrive via authMessage.
    property string promptText: "Password"
    property string sessionKey: "hyprland"
    property var sessions: ([])
    property bool authInProgress: false
    // Session-open flag, separate from authInProgress: the box must stay
    // typable while the session opens (the password submits on prompt
    // arrival). authInProgress means "verdict pending" only.
    property bool sessionActive: false
    property bool showFailure: false
    property bool ready: Greetd.state === GreetdState.ReadyToLaunch
    property bool available: Greetd.available
    property string pendingResponse: ""
    // Explicit-submission flag: "" is a valid password, so submission state
    // must not be inferred from pendingResponse being non-empty.
    property bool hasPending: false
    property bool promptWaiting: false
    function start() {
        if (!Greetd.available || root.userName === "" || root.sessionActive)
            return;
        // Never clear pendingResponse/hasPending here: tryAuth() stashes
        // the password BEFORE calling start(), and clearing would drop it.
        root.sessionActive = true;
        root.showFailure = false;
        root.promptWaiting = false;
        Greetd.createSession(root.userName);
    }
    function tryAuth() {
        // No emptiness guard: an empty password is submittable, and the
        // explicit Enter press (not text content) marks the submission.
        if (!Greetd.available)
            return;
        // Stash FIRST: on a fresh session the prompt hasn't arrived yet,
        // and it flushes automatically when it does (see onAuthMessage).
        root.pendingResponse = root.currentText;
        root.hasPending = true;
        if (Greetd.state === GreetdState.Inactive) {
            // Fresh or died session: (re)create. Clearing first covers a
            // session that died without authFailure/onError firing.
            root.sessionActive = false;
            root.start();
            return;
        }
        if (Greetd.state === GreetdState.ReadyToLaunch)
            return;
        if (root.promptWaiting) {
            root.promptWaiting = false;
            Greetd.respond(root.pendingResponse);
            root.authInProgress = true;
            root.pendingResponse = "";
            root.hasPending = false;
        }
    }
    function cancel() {
        Greetd.cancelSession();
        root.authInProgress = false;
        root.sessionActive = false;
        root.currentText = "";
        root.pendingResponse = "";
        root.hasPending = false;
        root.promptWaiting = false;
    }
    function setSession(k) {
        root.sessionKey = k;
    }
    onCurrentTextChanged: {
        if (currentText.length > 0)
            root.showFailure = false;
    }
    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (error) {
                root.showFailure = true;
                root.authInProgress = false;
                root.pendingResponse = "";
                root.hasPending = false;
                root.promptWaiting = false;
                root.failed();
                return;
            }
            if (!responseRequired)
                return;
            root.promptText = message;
            if (echoResponse)
                return;
            // Only answer with an explicitly submitted password (tryAuth
            // stashed it). Auto-answering with currentText here would send
            // a half-typed password — or the still-uncleared username.
            if (root.hasPending) {
                Greetd.respond(root.pendingResponse);
                root.authInProgress = true;
                root.pendingResponse = "";
                root.hasPending = false;
            } else {
                root.promptWaiting = true;
            }
        }
        function onAuthFailure(message) {
            root.currentText = "";
            root.pendingResponse = "";
            root.hasPending = false;
            root.promptWaiting = false;
            root.authInProgress = false;
            root.sessionActive = false;
            root.showFailure = true;
            root.failed();
        }
        function onReadyToLaunch() {
            root.authInProgress = false;
            root.sessionActive = false;
            root.pendingResponse = "";
            root.hasPending = false;
            root.promptWaiting = false;
        }
        function onError(error) {
            root.authInProgress = false;
            root.sessionActive = false;
            root.pendingResponse = "";
            root.hasPending = false;
            root.promptWaiting = false;
            root.showFailure = true;
            root.failed();
        }
    }
    function launchSelected() {
        var cmd = ["/usr/bin/start-hyprland"];
        for (var i = 0; i < root.sessions.length; i++)
            if (root.sessions[i].key === root.sessionKey)
                cmd = root.sessions[i].exec;
        Greetd.launch(cmd);
        root.launched();
    }
}
