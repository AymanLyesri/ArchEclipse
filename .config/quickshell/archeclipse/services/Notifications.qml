pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.theme

// Port of NotificationPopups.tsx + NotificationWidget — but inverted:
// AstalNotifd was a notification *client*; here Quickshell IS the daemon.
// Popup lifecycle mirrors AGS: show on notified(), auto-expire after 4s
// (unless critical), remove on resolved/dismiss. DND honored from settings.
Singleton {
    id: root

    readonly property int timeoutDelay: 4000
    property var popups: []            // [{id, summary, body, appName, appIcon, image, urgency, actions, notif}]
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
            if (root.dnd) {
                notification.tracked = false;   // drop silently in DND (history kept by sender)
                return;
            }
            root.addPopup(notification);
        }
    }

    // Emitted on every incoming notification (even when DND drops it),
    // mirrors AGS notifd "notified" handler used by the DND ping.
    signal notified(var notification)

    function addPopup(n) {
        n.tracked = true;
        const entry = {
            id: n.id,
            summary: n.summary || "",
            body: n.body || "",
            appName: n.appName || "",
            appIcon: n.appIcon || "",
            image: n.image || "",
            urgency: n.urgency,
            actions: Array.from(n.actions.values()).filter(a => a.identifier !== "default").map(a => ({ text: a.text, invoke: () => a.invoke() })),
            notif: n
        };
        const next = [entry].concat(root.popups);
        root.popups = next;

        // auto-dismiss after delay; critical stays 8s
        const life = entry.urgency === NotificationUrgency.Critical ? 8000 : timeoutDelay;
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
        const entry = popups.find(p => p.id === id);
        if (!entry) return;
        if (dismiss && entry.notif) {
            try { entry.notif.dismiss(); } catch (e) {}
        }
        popups = popups.filter(p => p.id !== id);
    }

    function invokeAction(id, index) {
        const entry = popups.find(p => p.id === id);
        if (entry && entry.actions[index]) entry.actions[index].invoke();
        closePopup(id, true);
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
