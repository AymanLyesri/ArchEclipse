//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import qs.widgets.greeter

// archeclipse-greeter: minimal greetd login shell (runs under
// Hyprland-minimal on the greeter VT).
// One GreeterSurface per screen sharing a single GreeterContext.
// Sessions come from the checked-in sessions.json stub first (never an
// empty picker, also the offline fallback), then refresh live from
// /usr/share/wayland-sessions: ls enumerates the .desktop files, one grep
// pulls their Name=/Exec= lines, Exec is parsed per the desktop-entry
// spec (quoting, escapes, % field codes dropped). Entries whose launcher
// binary is missing are dropped (stale .desktop safety); default session
// is hyprland with hyprland-uwsm fallback.
ShellRoot {
    id: root

    property string sessionDir: "/usr/share/wayland-sessions"
    property var _sessionOrder: []
    property var _pendingSessions: []
    property bool _liveSessions: false

    GreeterContext {
        id: greeter
        // Quit only after greetd acks the launch (state reaches Launched):
        // launched() fires synchronously after Greetd.launch(), pre-ack,
        // and greetd restarts greeters that linger after their session
        // starts, so quitting on the signal alone could exit pre-ack while
        // never quitting at all leaves a zombie greeter behind.
        onLaunched: {
            if (Greetd.state === GreetdState.Launched)
                Qt.quit();
        }
    }

    Connections {
        target: Greetd
        // Backup: launched() normally fires before the ack, so watch for
        // the ack itself.
        function onStateChanged() {
            if (Greetd.state === GreetdState.Launched)
                Qt.quit();
        }
    }

    // Stub ships next to shell.qml in both layouts (source tree and the
    // /etc/xdg mirror), so resolve it relative to this file.
    FileView {
        id: sessionsFile
        path: String(Qt.resolvedUrl("sessions.json")).replace(/^file:\/\//, "")
        printErrors: false
        onLoaded: root.applyStub(text())
    }
    Process {
        id: lsProc
        command: ["ls", "/usr/share/wayland-sessions/"]
        stdout: StdioCollector {
            onStreamFinished: root.parseSessionList(text)
        }
    }
    Process {
        id: grepProc
        stdout: StdioCollector {
            onStreamFinished: root.applySessionDetails(text)
        }
    }
    // Drops sessions whose launcher binary is missing (e.g. a stale
    // hyprland-uwsm.desktop with no uwsm installed): launching those dies
    // instantly and bounces straight back to the greeter with no message.
    Process {
        id: binProc
        stdout: StdioCollector {
            onStreamFinished: root.applyBinaryFilter(text)
        }
    }

    Component.onCompleted: {
        lsProc.running = true;
    }

    function applyStub(text) {
        if (root._liveSessions)
            return;
        try {
            var parsed = JSON.parse(text || "[]");
            if (!Array.isArray(parsed) || parsed.length === 0)
                return;
            var valid = [];
            for (var i = 0; i < parsed.length; i++) {
                var e = parsed[i];
                if (e && e.key && Array.isArray(e.exec) && e.exec.length > 0)
                    valid.push({
                        "key": String(e.key),
                        "name": String(e.name || e.key),
                        "exec": e.exec.map(String)
                    });
            }
            if (valid.length === 0)
                return;
            greeter.sessions = valid;
            root.pickDefault();
        } catch (e) {
            // Malformed stub: leave the default empty list, ls refresh next.
        }
    }

    function parseSessionList(text) {
        var order = [];
        var lines = String(text || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
            var f = lines[i].trim();
            if (f.endsWith(".desktop") && f.indexOf("/") === -1)
                order.push(f.slice(0, -8));
        }
        if (order.length === 0)
            return; // keep the stub
        root._sessionOrder = order;
        var cmd = ["grep", "-H", "^Name=\\|^Exec="];
        for (var j = 0; j < order.length; j++)
            cmd.push(root.sessionDir + "/" + order[j] + ".desktop");
        grepProc.command = cmd;
        grepProc.running = true;
    }

    function parseExec(value) {
        var argv = [];
        var cur = "";
        var has = false;
        var quote = "";
        var push = function () {
            if (has)
                argv.push(cur);
            cur = "";
            has = false;
        };
        var i = 0;
        while (i < value.length) {
            var c = value[i];
            if (quote !== "") {
                if (c === "\\" && quote === "\"" && i + 1 < value.length) {
                    cur += value[i + 1];
                    has = true;
                    i += 2;
                    continue;
                }
                if (c === quote) {
                    quote = "";
                    i++;
                    continue;
                }
                cur += c;
                has = true;
                i++;
                continue;
            }
            if (c === "\"" || c === "'") {
                quote = c;
                has = true;
                i++;
            } else if (c === "\\" && i + 1 < value.length) {
                cur += value[i + 1];
                has = true;
                i += 2;
            } else if (c === " " || c === "\t") {
                push();
                i++;
            } else if (c === "%" && i + 1 < value.length) {
                if (value[i + 1] === "%") {
                    cur += "%";
                    has = true;
                }
                i += 2; // any other field code is dropped
            } else {
                cur += c;
                has = true;
                i++;
            }
        }
        push();
        return argv;
    }

    function applySessionDetails(text) {
        var byKey = {};
        var lines = String(text || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            var sep = line.indexOf(".desktop:");
            if (sep === -1)
                continue;
            var key = line.slice(root.sessionDir.length + 1, sep);
            var rest = line.slice(sep + 9);
            var eq = rest.indexOf("=");
            if (eq === -1)
                continue;
            var field = rest.slice(0, eq);
            var val = rest.slice(eq + 1);
            if (!byKey[key])
                byKey[key] = {};
            if (field === "Name" && !byKey[key].name)
                byKey[key].name = val;
            else if (field === "Exec" && !byKey[key].exec)
                byKey[key].exec = root.parseExec(val);
        }
        var sessions = [];
        for (var j = 0; j < root._sessionOrder.length; j++) {
            var k = root._sessionOrder[j];
            var e = byKey[k];
            if (e && e.exec && e.exec.length > 0)
                sessions.push({
                    "key": k,
                    "name": e.name || k,
                    "exec": e.exec
                });
        }
        if (sessions.length === 0)
            return; // keep the stub
        // Resolve each launcher binary once (absolute path: test -x, bare
        // name: command -v). Unresolvable entries never reach the picker.
        root._pendingSessions = sessions;
        var bins = {};
        for (var m = 0; m < sessions.length; m++)
            bins[sessions[m].exec[0]] = true;
        var cmd = ["sh", "-c", "for c in \"$@\"; do case \"$c\" in /*) [ -x \"$c\" ] && echo \"$c\";; *) command -v \"$c\" >/dev/null && echo \"$c\";; esac; done", "sh"];
        for (var b in bins)
            cmd.push(b);
        binProc.command = cmd;
        binProc.running = true;
    }

    function applyBinaryFilter(text) {
        var ok = {};
        var lines = String(text || "").split("\n");
        for (var i = 0; i < lines.length; i++)
            if (lines[i] !== "")
                ok[lines[i]] = true;
        var sessions = [];
        var pending = root._pendingSessions || [];
        for (var j = 0; j < pending.length; j++)
            if (ok[pending[j].exec[0]])
                sessions.push(pending[j]);
        root._pendingSessions = [];
        if (sessions.length === 0)
            return; // keep the stub
        root._liveSessions = true;
        greeter.sessions = sessions;
        root.pickDefault();
    }

    function pickDefault() {
        var keys = [];
        for (var i = 0; i < greeter.sessions.length; i++)
            keys.push(greeter.sessions[i].key);
        // Absolute-path entry first: it works wherever Hyprland runs.
        // uwsm-managed second (optional tooling, may be absent).
        if (keys.indexOf("hyprland") !== -1)
            greeter.setSession("hyprland");
        else if (keys.indexOf("hyprland-uwsm") !== -1)
            greeter.setSession("hyprland-uwsm");
        else if (keys.length > 0 && keys.indexOf(greeter.sessionKey) === -1)
            greeter.setSession(keys[0]);
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property ShellScreen modelData

            screen: modelData
            // The greeter owns the VT: without this the compositor never
            // routes keys here (layer-shell keyboard interactivity defaults
            // to none) and no field is typable. The lock screen doesn't
            // need it — ext-session-lock grabs input by protocol.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            color: "black"

            GreeterSurface {
                anchors.fill: parent
                context: greeter
                wallpaperPath: Qt.resolvedUrl("greeter-wallpaper")
            }
        }
    }
}
