pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.theme

// Port of NotificationPopups.tsx + NotificationHistory.tsx + Notification.tsx.
// AGS is a notification *client* (history binds the daemon's retained list,
// popups are ephemeral widgets whose timeout does NOT dismiss from daemon).
// Here Quickshell IS the daemon, so we keep the same split explicitly:
//   - history: retained entries (survive popup expiry, DND keeps them too)
//   - popups:  ephemeral toast entries (4s timeout, 8s critical)
// Popup timeout only removes the toast; history is pruned on dismiss/close.
Singleton {
    id: root

    readonly property int timeoutDelay: 4000
    readonly property int maxHistory: 50
    property var popups: []             // [{id, time, notif}]
    property var history: []            // [{id, time, notif}] newest-first
    readonly property bool dnd: Settings.notifDnd

    // ---- the daemon ----
    NotificationServer {
        id: server
        keepOnReload: false          // match AGS: popups die on shell reload
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
    // mirrors AGS notifd "notified" handler used by the DND ping.
    signal notified(var notification)

    // Prune toast + history when the notification closes from anywhere
    // (dismiss button, history clear, external retraction). Mirrors AGS
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
        root.popups = root.popups.filter(p => p.id !== id);
        root.history = root.history.filter(h => h.id !== id);
        const ids = Object.assign({}, root._watched);
        delete ids[id];
        root._watched = ids;
    }

    function addHistory(n) {
        const entry = { id: n.id, time: Date.now() / 1000, notif: n };
        const next = [entry].concat(root.history.filter(h => h.id !== n.id));
        // Cap newest-first at maxHistory (AGS dismisses overflow)
        while (next.length > root.maxHistory) {
            const dropped = next.pop();
            try { dropped.notif.dismiss(); } catch (e) {}
        }
        root.history = next;
    }

    function addPopup(n) {
        const entry = { id: n.id, time: Date.now() / 1000, notif: n };
        root.popups = [entry].concat(root.popups.filter(p => p.id !== n.id));

        // auto-expire the TOAST after delay; critical stays 8s. Expiry never
        // dismisses from the daemon (AGS parity) so history keeps it.
        const life = n.urgency === NotificationUrgency.Critical ? 8000 : timeoutDelay;
        Qt.callLater(() => expireTimerFor(entry.id, life));
    }

    property var _expireTimers: ({})

    function expireTimerFor(id, ms) {
        if (_expireTimers[id]) return;
        const t = Qt.createQmlObject("import QtQuick; Timer { repeat:false }", root);
        t.interval = ms;
        t.triggered.connect(() => {
            delete _expireTimers[id];
            t.destroy();
            root.closePopup(id, false);
        });
        t.start();
        _expireTimers[id] = t;
    }

    function closePopup(id, dismiss) {
        const entry = root.popups.find(p => p.id === id);
        if (!entry) return;
        // AGS parity: timeout only hides the toast; dismiss removes everywhere
        // (closed handler prunes both lists).
        if (dismiss && entry.notif) {
            try { entry.notif.dismiss(); } catch (e) {}
        }
        root.popups = root.popups.filter(p => p.id !== id);
    }

    // AGS parity: invoking an action does NOT dismiss the notification.
    function invokeAction(id, index) {
        const entry = root.popups.find(p => p.id === id)
            || root.history.find(h => h.id === id);
        const acts = entry ? liveActions(entry.notif) : [];
        if (acts[index]) {
            try { acts[index].invoke(); } catch (e) {}
        }
    }

    // Live action list (per-notification QList needs values() call).
    // AGS keeps ALL actions (including "default"); label = last ":" segment.
    function liveActions(n) {
        if (!n || !n.actions) return [];
        try { return Array.from(n.actions.values()); } catch (e) { return []; }
    }
    function actionLabel(a) {
        const t = (a && a.text) || "";
        return t.split(":").pop() || "Action";
    }

    function clearHistory() {
        // Dismissing triggers each object's closed signal, which prunes both
        // lists via pruneClosed (AGS: dismiss removes from daemon list).
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
        if (opts.summary) args.push(opts.summary);
        if (opts.body) args.push(opts.body);
        Quickshell.execDetached(args);
    }
}
