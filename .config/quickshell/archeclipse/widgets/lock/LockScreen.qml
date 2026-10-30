import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

// Single owner scope for the secure lock (no per-monitor Variants — the compositor makes one
// WlSessionLockSurface per screen). Input blocking is compositor-enforced; `secure` once covered.
Scope {
    id: root

    property alias context: lockContext

    function lock() {
        lockContext.reset();
        root.captureBackgrounds();
    }
    // Screenshots must be taken BEFORE engaging the lock: once locked the compositor blanks behind
    // session-lock surfaces. The lock engages when all finish, any failure, or the 2s timeout.
    property int _pendingShots: 0
    function engageLock() {
        shotTimeout.stop();
        root._pendingShots = 0;
        lockContext.lockedAt = Date.now();
        lockContext.screenLocked = true;
    }
    function captureBackgrounds() {
        var mons = [];
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var hmon = Hyprland.monitorFor(Quickshell.screens[i]);
            var name = (hmon && hmon.name) ? String(hmon.name).replace(/[^A-Za-z0-9-]/g, "_") : "";
            if (name !== "" && mons.indexOf(name) === -1)
                mons.push(name);
        }
        var paths = {};
        for (var j = 0; j < mons.length; j++)
            paths[mons[j]] = "/tmp/qs-lockbg-" + mons[j] + ".png";
        lockContext.bgPaths = paths;
        if (mons.length === 0) {
            root.engageLock();
            return;
        }
        root._pendingShots = mons.length;
        shotTimeout.restart();
        for (var k = 0; k < mons.length; k++) {
            (function (mon, path) {
                var p = grimComp.createObject(root, {
                    "command": ["grim", "-o", mon, path]
                });
                p.exited.connect(function () {
                    p.destroy();
                    root._pendingShots--;
                    if (root._pendingShots <= 0)
                        root.engageLock();
                });
                p.running = true;
            })(mons[k], paths[mons[k]]);
        }
    }
    Component {
        id: grimComp
        Process {
        }
    }
    Timer {
        id: shotTimeout
        interval: 2000
        onTriggered: root.engageLock()
    }
    function focusLock() {
        lockContext.shouldReFocus();
    }

    Component.onCompleted: Registry.register("lock-screen", root)
    Component.onDestruction: Registry.unregister("lock-screen")

    LockContext {
        id: lockContext
        // Unlock in two beats so the collapse plays: surfaces fold (closing -> expand 0), then the
        // timer drops screenLocked; destroying while locked leaves the unusable fallback lock.
        onUnlocked: {
            lockContext.closing = true;
            closeTimer.restart();
        }
    }
    Timer {
        id: closeTimer
        interval: 350
        onTriggered: {
            lockContext.closing = false;
            lockContext.screenLocked = false;
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: lockContext.screenLocked

        WlSessionLockSurface {
            id: lockSurface
            color: "transparent"
            LockSurface {
                anchors.fill: parent
                context: lockContext
                monitorName: (Hyprland.monitorFor(lockSurface.screen)?.name) ?? ""
            }
        }
    }

    IpcHandler {
        target: "lock"
        function activate(): void {
            root.lock();
        }
        function focus(): void {
            root.focusLock();
        }
    }

    GlobalShortcut {
        name: "lock"
        description: "Locks the screen"
        onPressed: root.lock()
    }
    GlobalShortcut {
        name: "lockFocus"
        description: "Re-focuses the lock screen after wake (Hyprland unfocus workaround)"
        onPressed: root.focusLock()
    }
}
