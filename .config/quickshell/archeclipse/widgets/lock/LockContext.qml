import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.theme

// Shared auth state for all lock surfaces: default `login` PAM stack, respond only when
// responseRequired, clear the password on success/failure/lock/idle, never start PAM empty.
Scope {
    id: root

    signal shouldReFocus()
    signal unlocked()
    signal failed()

    property bool screenLocked: false
    // Grace period: Esc dismisses without a password within this window after locking.
    // Settings-driven (seconds) so it follows the lockscreen category live.
    readonly property int gracePeriodMs: Settings.lockGraceSeconds * 1000
    property double lockedAt: 0
    function inGracePeriod() {
        return root.screenLocked && root.lockedAt > 0 && (Date.now() - root.lockedAt) < root.gracePeriodMs;
    }
    function handleEscape() {
        if (root.currentText !== "") {
            root.clearText();
            return;
        }
        if (root.unlockInProgress)
            return;
        if (root.inGracePeriod())
            root.unlocked();
    }
    // Close handshake: set on successful auth so surfaces collapse via the
    // expand spring before screenLocked drops and destroys them.
    property bool closing: false
    // Screenshot backgrounds per monitor, captured just before locking: Hyprland blanks behind
    // session-lock surfaces, so the blurred screenshot is the visible background.
    property var bgPaths: ({})
    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property bool screenUnlockFailed: false

    function clearText() {
        root.currentText = "";
    }
    function reset() {
        root.clearText();
        root.unlockInProgress = false;
        root.showFailure = false;
        root.screenUnlockFailed = false;
    }
    function resetClearTimer() {
        passwordClearTimer.restart();
    }
    function tryUnlock() {
        if (root.currentText === "" || root.unlockInProgress)
            return;
        root.unlockInProgress = true;
        pam.start();
    }

    Timer {
        id: passwordClearTimer
        interval: 10000
        onTriggered: root.reset()
    }
    onCurrentTextChanged: {
        if (currentText.length > 0) {
            root.showFailure = false;
            root.screenUnlockFailed = false;
        }
        passwordClearTimer.restart();
    }

    PamContext {
        id: pam
        onPamMessage: {
            if (this.responseRequired)
                this.respond(root.currentText);
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.clearText();
                root.unlockInProgress = false;
                root.unlocked();
            } else {
                root.clearText();
                root.unlockInProgress = false;
                root.screenUnlockFailed = true;
                root.showFailure = true;
                root.failed();
            }
        }
        onError: {
            root.clearText();
            root.unlockInProgress = false;
            root.screenUnlockFailed = true;
            root.showFailure = true;
            root.failed();
        }
    }
}
