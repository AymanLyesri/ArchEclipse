import QtQuick
import Quickshell
import qs.theme
import qs.widgets.lock
import qs.widgets.shared

// Per-screen greeter UI: twin of LockSurface (same 340px card, radius 24,
// top-center) with a user-picker dropdown under the Welcome title, the
// shared AuthCard password box, a session picker below, and lock-twin
// power actions (no logout: no session exists yet).
// CONSUMER CONTRACT (GreeterContext): userName is set before start()/
// tryAuth(), and currentText is cleared between the username and password
// phases so a pending password prompt never answers with the stale username
// (AuthCard emits textChanged; it does not write back to currentText).
MouseArea {
    id: root
    required property var context
    // Fixed-name login wallpaper at the config root (shell.qml passes
    // Qt.resolvedUrl("greeter-wallpaper")); empty/missing = dim only.
    property string wallpaperPath: ""

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onPressed: root.focusActiveField()

    function forceFieldFocus() {
        root.focusActiveField();
    }
    function focusActiveField() {
        authCard.forceFieldFocus();
    }
    function sessionIndex() {
        var ss = root.context.sessions;
        if (!ss || ss.length === 0)
            return -1;
        for (var i = 0; i < ss.length; i++)
            if (ss[i].key === root.context.sessionKey)
                return i;
        return -1;
    }
    Component.onCompleted: {
        root.forceFieldFocus();
        root.expand = 1;
        if (root.context.ready)
            root.context.launchSelected();
    }
    Connections {
        target: root.context
        function onReadyChanged() {
            if (root.context.ready)
                root.context.launchSelected();
        }
        function onShowFailureChanged() {
            if (root.context.showFailure)
                shakeAnim.restart();
        }
    }

    // Island-unfold driver (same spring as the lock card): the card grows
    // down from the top edge like a dynamic island opening.
    property real expand: 0
    Behavior on expand {
        SpringAnimation {
            spring: 3.5
            damping: 0.32
            mass: 1.0
        }
    }

    // No session wallpaper behind the greeter (Hyprland-minimal starts
    // blank), so the plain dim is the whole background — unlike the lock,
    // there is no screenshot blur layer.
    // Login wallpaper behind the dim (content-sniffed, any format; the
    // panel installs it via pkexec). Missing file stays invisible: the
    // plain dim underneath is the fallback. cache:false — the fixed path
    // is reused on every change (same trick as the lock backgrounds).
    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: true
        source: root.wallpaperPath
        visible: status === Image.Ready
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
    }

    // Top-center island: username + password + session picker + actions.
    // Frosted island fill (translucent Theme.surface, like the bar pill):
    // the compositor blurs whatever is behind it; without compositor blur
    // it degrades to clean translucency over the dim.
    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: 340
        height: cardCol.implicitHeight + 40
        Behavior on height {
            Anim {
            }
        }
        radius: 24
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        // Unfold with the expand driver (origin Top: grows downward).
        scale: 0.96 + 0.04 * root.expand
        opacity: Math.max(0, Math.min(1, root.expand * 1.2))
        transformOrigin: Item.Top

        Column {
            id: cardCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 12

            // Shared login-box UI (same component as the lock screen):
            // Welcome title, then the user picker, then password.
            AuthCard {
                id: authCard
                width: parent.width
                title: "Welcome"
                iconText: "\uf007"
                userNames: root.context.users
                pickedUser: root.context.userName
                onUserPicked: name => {
                    root.context.selectUser(name);
                    authCard.forceFieldFocus();
                }
                promptText: root.context.promptText
                errorText: "Incorrect password — try again"
                currentText: root.context.currentText
                onTextChanged: root.context.currentText = text
                showError: root.context.showFailure
                busy: root.context.authInProgress
                logoutVisible: false
                onAccepted: root.context.tryAuth()
                onEscapePressed: {
                    root.context.cancel();
                    root.focusActiveField();
                }
                // No index 0 (logout): this is the login screen, there is
                // no user session to log out of yet.
                onAction: index => {
                    if (index === 1)
                        Quickshell.execDetached(["shutdown", "now"])
                    else if (index === 2)
                        Quickshell.execDetached(["systemctl", "suspend"])
                    else if (index === 3)
                        Quickshell.execDetached(["reboot"])
                }
            }
            AppComboBox {
                id: sessionBox
                width: parent.width
                model: root.context.sessions
                textRole: "name"
                currentIndex: root.sessionIndex()
                enabled: root.context.available
                onActivated: index => {
                    if (root.context.sessions[index])
                        root.context.setSession(root.context.sessions[index].key);
                }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: !root.context.available
                text: "Greetd unavailable — login disabled"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                color: Theme.danger
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: root.context.available && root.context.users.length === 0
                text: "No login users found"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                color: Theme.danger
            }
        }

        // Shake on wrong password (via horizontalCenterOffset: card uses
        // anchors so x is anchor-owned and must not be animated).
        SequentialAnimation {
            id: shakeAnim
            NumberAnimation {
                target: card
                property: "anchors.horizontalCenterOffset"
                to: -14
                duration: 50
            }
            NumberAnimation {
                target: card
                property: "anchors.horizontalCenterOffset"
                to: 14
                duration: 50
            }
            NumberAnimation {
                target: card
                property: "anchors.horizontalCenterOffset"
                to: -8
                duration: 40
            }
            NumberAnimation {
                target: card
                property: "anchors.horizontalCenterOffset"
                to: 8
                duration: 40
            }
            NumberAnimation {
                target: card
                property: "anchors.horizontalCenterOffset"
                to: 0
                duration: 40
            }
        }
    }
}
