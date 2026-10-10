pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.theme

// Port of NotificationPopups.tsx + NotificationHistory.tsx + Notification.tsx,
// reworked along end4/illogical-impulse lines: the daemon keeps snapshot
// wrapper objects (plain props, snapshotted once at receipt) instead of
// handing live NotificationObjects to delegates. That makes every binding
// cheap, kills the whole null-during-exit bug class (wrappers outlive the
// row removal that plays the exit transition), and needs zero polling:
//   - toasts:       newest-first wrappers (display strings + live ref)
//   - popupToasts:  derived filter bound by the popup ListView's ScriptModel
//   - one-shot self-destroying ToastTimer per toast; timeout only hides the
//     toast (history keeps it, DND toasts never show)
//   - hover holds the countdown (timer destroyed); unhover hides the toast.
//     No remaining-time bookkeeping, no per-frame timers anywhere.
Singleton {
    id: root

    readonly property int timeoutDelay: 4000
    readonly property int criticalDelay: 8000
    readonly property int maxHistory: 50
    property var history: []            // [{id, time, notif}] newest-first
    readonly property bool dnd: Settings.notifDnd

    // Snapshot of one toast. All display state is plain data resolved once
    // in addPopup; delegates only read these (plus notificationId). `live`
    // is used solely for dismiss/action-invoke and never in bindings.
    component Toast: QtObject {
        required property int notificationId
        property var live: null
        property string summary: ""
        property string body: ""
        property string appName: ""
        property string iconFile: ""
        property string iconName: ""
        property string previewFile: ""
        property string openFile: ""
        property string videoFile: ""
        property bool isRecorder: false
        property bool critical: false
        property bool hideBody: true
        property bool longBody: false
        property var actionDefs: []     // [{identifier, text}] plain snapshot
        property double stamp: 0
        property int life: 4000         // ms, 0 = never auto-hide
        property bool popup: false
        property Timer timer: null
    }
    component ToastTimer: Timer {
        required property int toastId
        repeat: false
        onTriggered: {
            const self = this;
            root.hideToast(toastId);
            root.forgetToastTimer(toastId);
            self.destroy();
        }
    }
    Component {
        id: toastComp
        Toast {}
    }
    Component {
        id: toastTimerComp
        ToastTimer {}
    }

    property var toasts: []             // newest-first Toast wrappers (reassigned on every mutation)
    property var popupToasts: root.toasts.filter(t => t.popup)

    // ---- the daemon ----
    NotificationServer {
        id: server
        keepOnReload: false          // popups die on shell reload
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: true
        persistenceSupported: false

        onNotification: notification => {
            root.notified(notification);          // emit for ControlPanel DND ping etc.
            notification.tracked = true;
            root.watchClosed(notification);
            root.addHistory(notification);
            if (!root.dnd) root.addPopup(notification);
        }
    }

    // Emitted on every incoming notification (even when DND skips the toast),
    // mirrors the notifd "notified" handler used by the DND ping.
    signal notified(var notification)

    // Prune toast + history when the notification closes from anywhere
    // (dismiss button, history clear, external retraction). Mirrors
    // notifd "resolved" handling.
    property var _watched: ({})
    function watchClosed(n) {
        if (!n || root._watched[n.id]) return;
        const ids = Object.assign({}, root._watched);
        ids[n.id] = true;
        root._watched = ids;
        n.closed.connect(() => root.pruneClosed(n.id));
    }
    function pruneClosed(id) {
        root.stopToastTimer(root.findToast(id));
        root.toasts = root.toasts.filter(t => t.notificationId !== id);
        root.history = root.history.filter(h => h.id !== id);
        const ids = Object.assign({}, root._watched);
        delete ids[id];
        root._watched = ids;
    }

    function addHistory(n) {
        const entry = { id: n.id, time: Date.now() / 1000, notif: n };
        const next = [entry].concat(root.history.filter(h => h.id !== n.id));
        // Cap newest-first at maxHistory (dismiss overflow)
        while (next.length > root.maxHistory) {
            const dropped = next.pop();
            try { dropped.notif.dismiss(); } catch (e) {}
        }
        root.history = next;
    }

    function findToast(id) {
        return root.toasts.find(t => t.notificationId === id) || null;
    }

    // Reassigns the array so derived bindings (popupToasts) re-evaluate
    // after in-place wrapper mutations (popup flag flips).
    function touchToasts() {
        root.toasts = root.toasts.slice();
    }

    function addPopup(n) {
        // A replaced toast must not keep its old countdown.
        root.stopToastTimer(root.findToast(n.id));

        const iconFile = root.isRecorder(n) ? "" : root.imageFile(n);
        const iconName = root.iconNameFor(n);
        const previewFile = root.previewFor(iconFile);
        const body = (n.body || "").toString();
        // Openable file: screenshot icon path, else a /abs/path.ext
        // embedded in the body (Recorder stop toast sends the full path).
        const openFile = root.openFileFor(n, iconFile, body);
        const videoFile = root.videoFor(openFile);
        const acts = [];
        try {
            for (const a of n.actions.values())
                acts.push({ identifier: a.identifier, text: a.text });
        } catch (e) {}
        const w = toastComp.createObject(root, {
            notificationId: n.id,
            live: n,
            summary: ((n.summary || n.appName) || "").toString(),
            body: body,
            appName: ((n.appName || "").toString()),
            iconFile: iconFile,
            iconName: iconName,
            previewFile: previewFile,
            openFile: openFile,
            videoFile: videoFile,
            isRecorder: root.isRecorder(n),
            critical: n.urgency === NotificationUrgency.Critical,
            hideBody: body === "" || body === openFile || root.bodyIsImage(n, iconFile),
            longBody: body.length > 60 && !root.bodyIsImage(n, iconFile),
            actionDefs: acts,
            stamp: Date.now() / 1000,
            life: root.toastLifetime(n),
            popup: false
        });
        root.toasts = [w].concat(root.toasts.filter(t => t.notificationId !== n.id));

        // auto-hide the TOAST after its life; critical lingers. Hiding never
        // dismisses from the daemon so history keeps it.
        if (!root.dnd) {
            w.popup = true;
            if (w.life > 0) {
                w.timer = toastTimerComp.createObject(root, { toastId: n.id, interval: w.life });
                w.timer.start();
            }
            root.touchToasts();
        }
    }

    // Toast lifetime in ms (0 = never auto-hide, honors server timeout).
    function toastLifetime(n) {
        const hint = (n && n.expireTimeout != null) ? n.expireTimeout : -1;
        if (hint === 0) return 0;
        if (hint > 0) return hint;
        return (n && n.urgency === NotificationUrgency.Critical) ? root.criticalDelay : root.timeoutDelay;
    }

    // Hide a toast (timeout, hover-leave). Idempotent; history untouched.
    function hideToast(id) {
        const w = root.findToast(id);
        if (!w) return;
        if (w.timer) {
            try { w.timer.stop(); } catch (e) {}
        }
        if (!w.popup) return;
        w.popup = false;
        root.touchToasts();
    }

    function expireToast(id) {
        root.hideToast(id);
    }

    // Hover holds the countdown: the bar freezes via `paused`, the timer is
    // gone so there is nothing to drift. Unhover hides (end4 semantics).
    function holdToast(id) {
        root.stopToastTimer(root.findToast(id));
    }
    function releaseToast(id) {
        root.hideToast(id);
    }

    // Dismiss everywhere (swipe, right-click, button): animated exit via the
    // ListView remove transition, daemon retraction prunes history.
    function discardToast(id) {
        const w = root.findToast(id);
        if (!w) return;
        root.stopToastTimer(w);
        const live = w.live;
        root.toasts = root.toasts.filter(t => t.notificationId !== id);
        if (live) {
            try { live.dismiss(); } catch (e) {}
        }
    }

    function stopToastTimer(w) {
        const t = w ? w.timer : null;
        if (w) w.timer = null;
        if (t) {
            try { t.stop(); t.destroy(); } catch (e) {}
        }
    }
    function forgetToastTimer(id) {
        const w = root.findToast(id);
        if (w) w.timer = null;
    }

    // Invoking an action does NOT dismiss the notification.
    function invokeToastAction(id, identifier) {
        const w = root.findToast(id);
        const acts = (w && w.live) ? liveActions(w.live) : [];
        const a = acts.find(x => x.identifier === identifier);
        if (a) {
            try { a.invoke(); } catch (e) {}
        }
    }

    // Live action list (per-notification QList needs values() call).
    // Keep ALL actions (including "default"); label = last ":" segment.
    function liveActions(n) {
        if (!n || !n.actions) return [];
        try { return Array.from(n.actions.values()); } catch (e) { return []; }
    }

    // Normalizes a notification icon/image value to a local file path.
    // The daemon may hand us a plain absolute path ("/..."), a file://
    // URL (image-path hint), or an image://icon/ URL (Quickshell routes
    // notify-send -i <path> through its icon provider) — accept all,
    // decode %20-style escapes.
    function iconToFile(v) {
        if (!v) return "";
        let s = String(v);
        if (s.startsWith("file://")) {
            s = s.replace(/^file:\/\/[^/]*/, "");
            try { s = decodeURIComponent(s); } catch (e) {}
        } else if (s.startsWith("image://icon/")) {
            s = s.slice("image://icon/".length);
            try { s = decodeURIComponent(s); } catch (e) {}
        }
        return s.startsWith("/") ? s : "";
    }

    // Resolved image file for a notification (preview, copy). Checks
    // appIcon first, then image.
    function imageFile(n) {
        if (!n) return "";
        return root.iconToFile(n.appIcon) || root.iconToFile(n.image);
    }

    // Theme-name/desktop-entry fallback for the small icon slot.
    function iconNameFor(n) {
        if (!n || root.isRecorder(n)) return "";
        const vals = [n.appIcon, n.image];
        for (let i = 0; i < vals.length; ++i) {
            const s = vals[i] ? String(vals[i]) : "";
            if (s !== "" && root.iconToFile(s) === "")
                return s;
        }
        return (n.desktopEntry || "").toString();
    }

    // Large preview candidate for file-path icons (screenshots, etc.).
    function previewFor(iconFile) {
        if (!iconFile) return "";
        if (!/\.(png|jpe?g|webp|gif|bmp|svg|ico)$/i.test(iconFile)) return "";
        return iconFile;
    }

    // First /absolute/path.ext match inside free text (Recorder stop
    // toasts carry the full recording path in the body). Trailing
    // punctuation from markup-wrapped bodies is stripped.
    function filePathInText(s) {
        if (!s) return "";
        const m = String(s).match(/\/\S+\.(mp4|mkv|webm|mov|png|jpe?g|webp|gif|bmp|svg|ico)/i);
        return m ? m[0].replace(/[).,;:'"]+$/, "") : "";
    }

    // Openable file for a live notification: resolved image icon for
    // screenshots, else a path embedded in the body (recordings).
    function openFileFor(n, iconFile, body) {
        if (iconFile) return iconFile;
        return root.filePathInText(body);
    }

    // Video subset of an openable path (mp4/mkv/webm/mov) for the
    // AppVideo thumbnail slot; "" means image-or-nothing.
    function videoFor(path) {
        if (!path) return "";
        return /\.(mp4|mkv|webm|mov)$/i.test(path) ? path : "";
    }

    // Open a toast's file with the default handler (no-op when none).
    function openToastFile(id) {
        const w = root.findToast(id);
        const f = w ? w.openFile : "";
        if (f) Quickshell.execDetached(["xdg-open", f]);
    }

    function openPath(path) {
        if (path) Quickshell.execDetached(["xdg-open", path]);
    }

    // Shared copy: image file payload via wl-copy with its real MIME type
    // (screenshot icons arrive as appIcon paths) + result toast, else plain
    // text. `host` parents the worker Process. Used by both the popup
    // delegate and the history card through NotificationCardBody.
    function copyToClipboard(host, iconFile, fallbackText) {
        if (iconFile !== "") {
            const imgPath = iconFile;
            const p = Qt.createQmlObject("import Quickshell.Io; Process {}", host);
            p.command = ["bash", "-c", "wl-copy --type \"$(file -b --mime-type " + JSON.stringify(imgPath) + ")\" < " + JSON.stringify(imgPath)];
            p.exited.connect(code => {
                root.notify(code === 0 ? {
                    summary: "Copied",
                    body: imgPath
                } : {
                    summary: "Error",
                    body: "Copy failed"
                });
                p.destroy();
            });
            p.running = true;
            return;
        }
        if (fallbackText)
            Quickshell.execDetached(["wl-copy", fallbackText]);
    }

    // Recording toasts (our screenrecord.sh sends -a "Recorder") never
    // get a large preview — just the red record-dot glyph.
    function isRecorder(n) {
        if (!n) return false;
        if (n.appName === "Recorder") return true;
        return /Recording (Started|Stopped)/.test(n.summary || "");
    }

    // True when the body is just the image path (screenshot toasts put
    // the file in the body). Views hide it since the preview shows it.
    function bodyIsImage(n, file) {
        if (!n || !n.body || !file) return false;
        const b = String(n.body);
        return b === file || b === "file://" + file;
    }
    function actionLabel(a) {
        const t = (a && a.text) || "";
        return t.split(":").pop() || "Action";
    }

    function clearHistory() {
        // Dismissing triggers each object's closed signal, which prunes both
        // lists via pruneClosed (dismiss removes from daemon list).
        const all = root.history.slice();
        for (const h of all) {
            try { h.notif.dismiss(); } catch (e) {}
        }
    }

    // Convenience API used by widgets (WallpaperSwitcher, CustomScripts, etc.)
    // to raise a toast notification. Uses notify-send so it flows through the
    // system notification daemon (which this NotificationServer backs), so the
    // popup appears identically to any external notification.
    function notify(opts) {
        const args = ["notify-send"];
        if (opts.appName) { args.push("-a"); args.push(opts.appName); }
        if (opts.icon) { args.push("-i"); args.push(opts.icon); }
        if (opts.summary) args.push(opts.summary);
        if (opts.body) args.push(opts.body);
        Quickshell.execDetached(args);
    }

    // Shorthand used by services (ScreenRecorder, etc.): send(summary, body).
    function send(summary, body) {
        root.notify({ summary: summary, body: body });
    }
}
