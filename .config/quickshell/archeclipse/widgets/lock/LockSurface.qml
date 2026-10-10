import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import qs.theme
import qs.widgets.shared

// Per-screen lock UI, hosted inside a transparent WlSessionLockSurface.
// Fullscreen MouseArea keeps the password focused (click/hover refocus,
// Esc clears); fullscreen dim lets the Hyprland compositor blur show through.
MouseArea {
    id: root
    required property var context
    required property string monitorName

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onPressed: authCard.forceFieldFocus()
    onPositionChanged: authCard.forceFieldFocus()

    function forceFieldFocus() {
        authCard.forceFieldFocus();
    }
    Connections {
        target: root.context
        function onShouldReFocus() {
            root.forceFieldFocus();
        }
        // Close beat: fold the island away before screenLocked drops.
        function onClosingChanged() {
            if (root.context.closing)
                root.expand = 0;
        }
    }
    Component.onCompleted: {
        root.forceFieldFocus();
        root.expand = 1;
        graceAnim.start();
    }

    // Island-unfold driver (same spring as the bar islands): the card grows
    // down from the top edge like a dynamic island opening.
    property real expand: 0
    // Grace-period hint state, polled so it clears exactly at expiry.
    property bool graceActive: false
    property int graceSeconds: Settings.lockGraceSeconds
    Timer {
        id: graceTimer
        interval: 1000
        repeat: true
        running: root.context.screenLocked
        triggeredOnStart: true
        onTriggered: {
            var g = root.context.inGracePeriod();
            if (root.graceActive && !g)
                authCard.forceFieldFocus();
            root.graceActive = g;
            root.graceSeconds = Math.max(0, Math.ceil((root.context.gracePeriodMs - (Date.now() - root.context.lockedAt)) / 1000));
        }
    }
    Behavior on expand {
        SpringAnimation {
            spring: 3.5
            damping: 0.32
            mass: 1.0
        }
    }

    Keys.onPressed: event => {
        root.context.resetClearTimer();
        if (event.key === Qt.Key_Escape)
            root.context.handleEscape();
        root.forceFieldFocus();
    }

    // Session background: a grim screenshot captured just before locking,
    // shown blurred (screenshot-style). The plain dim underneath is the
    // fallback when no screenshot exists for this monitor.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
    }
    Item {
        id: bgShot
        anchors.fill: parent
        visible: false
        Image {
            id: bgImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            // cache:false (same path is reused every lock) but synchronous:
            // the file is local and grim already exited, so decode costs one
            // short hitch while the first painted frame is already blurred
            // instead of flashing the dark base dim for several frames.
            cache: false
            asynchronous: false
            source: {
                var p = root.context.bgPaths[root.monitorName];
                return p ? ("file://" + p) : "";
            }
        }
    }
    MultiEffect {
        id: bgBlur
        anchors.fill: parent
        source: bgShot
        blurEnabled: true
        blur: 0.85
        visible: bgImage.status === Image.Ready
        opacity: bgImage.status === Image.Ready ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.2)
        visible: bgBlur.visible
        opacity: bgBlur.opacity
    }

    // Top-center island: lock icon + password + 4 direct actions.
    // Frosted island fill (translucent Theme.surface, like the bar pill):
    // Hyprland blurs whatever is behind it; without compositor blur it
    // degrades to clean translucency over the dim.
    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: 340
        height: cardCol.implicitHeight + 40
        Behavior on height {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
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

            // Shared login-box UI (also used by the future greeter).
            AuthCard {
                id: authCard
                width: parent.width
                title: "Locked"
                iconText: "\uf023"
                promptText: "Enter password"
                errorText: "Incorrect password \u2014 try again"
                currentText: root.context.currentText
                onTextChanged: root.context.currentText = text
                showError: !root.graceActive && root.context.showFailure
                inputVisible: !root.graceActive
                busy: root.context.unlockInProgress
                onAccepted: root.context.tryUnlock()
                onEscapePressed: root.context.handleEscape()
                onAction: index => {
                    if (index === 0)
                        Hyprland.dispatch("hl.dsp.exit()")
                    else if (index === 1)
                        Quickshell.execDetached(["shutdown", "now"])
                    else if (index === 2)
                        Quickshell.execDetached(["systemctl", "suspend"])
                    else if (index === 3)
                        Quickshell.execDetached(["reboot"])
                }
            }
            // Grace countdown: visible timer while dismissal is free.
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: root.graceActive
                text: root.graceSeconds + "s"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 2
                font.bold: true
                color: Theme.fg
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: root.graceActive
                text: "Esc to dismiss"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                color: Theme.fgDim
            }
        }

        // Grace timeout bar (notification toast pattern): transform-only
        // shrink, GPU-composited, no layout pass per frame. Gone with the
        // countdown once the password is required.
        Rectangle {
            id: graceTrack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.bottomMargin: 13
            height: 3
            radius: 2
            visible: root.graceActive
            color: Qt.alpha(Theme.fg, 0.12)
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width
                radius: 2
                color: Theme.accent
                transform: Scale {
                    id: graceScale
                    origin.x: 0
                    xScale: 1
                }
                PropertyAnimation {
                    id: graceAnim
                    target: graceScale
                    property: "xScale"
                    from: 1
                    to: 0
                    duration: root.context.gracePeriodMs
                }
            }
        }

        // Shake on wrong password (via horizontalCenterOffset: card uses
        // anchors.centerIn so x is anchor-owned and must not be animated).
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
        Connections {
            target: root.context
            function onShowFailureChanged() {
                if (root.context.showFailure)
                    shakeAnim.restart();
            }
        }
    }
}
