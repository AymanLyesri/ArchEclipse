import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Notifications
import qs.theme
import qs.services
import qs.widgets.shared

// Centered notification pill, owned by Bar.qml (one per monitor).
// Previously a separate top-right PanelWindow (shell.qml Variants); now a
// plain Item positioned below the main pill at center. Geometry is pushed
// in from the bar (pillX/pillY/pillW/pillH + topBar) so this file stays
// independent of Bar internals.
//
// Model rows are Toast snapshot wrappers (plain props resolved once at
// receipt); delegates never touch live NotificationObjects, so bindings
// stay cheap and the exit transition can never null-deref.
//
// Animation model (end4/illogical-impulse reference):
//   - ListView over ScriptModel(Notifications.popupToasts): row-level
//     add/displaced/remove transitions, no full rebuilds, no dual-model
//     syncing, no polling timers anywhere.
//   - Entrance: staggered Emphasized drop-in from the top (y + fade +
//     0.96-scale, island motion language via shared Anim).
//   - Exit: fast rise + shrink + fade (FastEffects); swipe-to-dismiss
//     plays first, then discards.
//   - Timeout bar: ONE PropertyAnimation per card, paused declaratively on
//     hover (hover destroys the service countdown; unhover hides the toast,
//     so bar and expiry can never drift).
Item {
    id: root

    // Pushed in from Bar.qml (stripRoot coordinates).
    property real pillX: 0
    property real pillY: 0
    property real pillW: 0
    property real pillH: 0
    property bool topBar: true
    // Media pill stacking: when the bottom media pill is showing, toasts
    // dock below it instead of overlapping it.
    property bool mediaVisible: false
    property real mediaY: 0
    property real mediaH: 0
    // OSD pill stacking: same treatment one level down — toasts dock
    // below the volume/brightness OSD when it shows (below media+OSD
    // when both show, which is rare: equal-priority states resolve one).
    property bool osdVisible: false
    property real osdY: 0
    property real osdH: 0

    width: 400
    height: popList.contentHeight

    // Centered under the main pill, clamped 8px inside the screen edges.
    // x tracks the pill rigidly (no Behavior — coupled to width animations).
    // y for a bottom bar depends on our own height (no loop: content never
    // reads y back).
    x: {
        if (!parent)
            return 0;
        const centered = pillX + (pillW - width) / 2;
        return Math.max(8, Math.min(parent.width - width - 8, centered));
    }
    y: {
        if (topBar) {
            if (root.osdVisible)
                return root.osdY + root.osdH + 8;
            if (root.mediaVisible)
                return root.mediaY + root.mediaH + 8;
            return pillY + pillH + 8;
        }
        if (root.osdVisible)
            return root.osdY - height - 8;
        if (root.mediaVisible)
            return root.mediaY - height - 8;
        return pillY - height - 8;
    }

    // Grace keeps the pill mapped while the last card slides out.
    property int toastCount: Notifications.popupToasts.length
    onToastCountChanged: {
        if (toastCount > 0)
            exitGuard.stop();
        else
            exitGuard.restart();
    }
    Timer {
        id: exitGuard
        interval: 350
        repeat: false
    }
    property bool hasContent: toastCount > 0 || exitGuard.running
    visible: hasContent

    // Cards float individually (no shared background) — the pill is just
    // positioning. Each card keeps its own surface.
    ListView {
        id: popList
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: contentHeight
            spacing: Theme.spacing
            interactive: false
            model: ScriptModel {
                values: Notifications.popupToasts
            }

            populate: Transition {
                ParallelAnimation {
                    Anim {
                        property: "y"
                        from: -12
                        type: Anim.Emphasized
                    }
                    Anim {
                        property: "opacity"
                        from: 0
                        type: Anim.DefaultEffects
                    }
                    Anim {
                        property: "scale"
                        from: 0.96
                        to: 1
                        type: Anim.Emphasized
                    }
                }
            }
            add: Transition {
                SequentialAnimation {
                    // Stagger: older rows (higher index) trail the newcomer.
                    // Clamped: a retargeted transition can report index -1.
                    PauseAnimation {
                        duration: Math.max(0, ViewTransition.index * 60)
                    }
                    ParallelAnimation {
                        Anim {
                            property: "y"
                            from: -12
                            type: Anim.Emphasized
                        }
                        Anim {
                            property: "opacity"
                            from: 0
                            type: Anim.DefaultEffects
                        }
                        Anim {
                            property: "scale"
                            from: 0.96
                            to: 1
                            type: Anim.Emphasized
                        }
                    }
                }
            }
            displaced: Transition {
                Anim {
                    properties: "x,y"
                    type: Anim.DefaultSpatial
                }
            }
            remove: Transition {
                ParallelAnimation {
                    Anim {
                        property: "y"
                        to: -12
                        type: Anim.FastEffects
                    }
                    Anim {
                        property: "opacity"
                        to: 0
                        type: Anim.FastEffects
                    }
                    Anim {
                        property: "scale"
                        to: 0.96
                        type: Anim.FastEffects
                    }
                }
            }

            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property var toast: modelData
                readonly property int toastId: toast ? toast.notificationId : -1
                readonly property bool critical: toast ? toast.critical : false
                property bool isHovered: false

                width: ListView.view ? ListView.view.width : 400
                // Scale origin at the top so the Emphasized drop-in reads
                // as falling from the bar.
                transformOrigin: Item.Top
                // Content-driven: body is top-anchored inside the fill-item
                // shift, so this never feeds back into itself.
                height: body.height + 22
                Behavior on height {
                    NumberAnimation {
                        duration: 280
                        easing.type: Easing.OutCubic
                    }
                }
                radius: Theme.radius
                color: critical ? Qt.rgba(0.66, 0.27, 0.27, 0.95) : Theme.surface
                border.color: isHovered ? Qt.alpha(Theme.accent, 0.5) : Qt.alpha(Theme.fg, 0.1)
                border.width: 1
                Behavior on border.color {
                    ColorAnimation {
                        duration: 200
                    }
                }
                clip: true

                // Background interaction layer FIRST so buttons above stay
                // clickable. Drag sideways past the threshold to fling-dismiss
                // (end4 destroyWithAnimation); right-click dismisses instantly.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    drag.target: shift
                    drag.axis: Drag.XAxis
                    drag.threshold: 8
                    drag.minimumX: -card.width - 32
                    drag.maximumX: card.width + 32
                    onReleased: {
                        if (Math.abs(shift.x) > 70) {
                            swipeOut.dir = shift.x < 0 ? -1 : 1;
                            swipeOut.start();
                        } else {
                            snapBack.start();
                        }
                    }
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton && card.toastId >= 0)
                            Notifications.discardToast(card.toastId);
                    }
                }
                HoverHandler {
                    onHoveredChanged: {
                        card.isHovered = hovered;
                        if (card.toastId < 0)
                            return;
                        if (hovered)
                            Notifications.holdToast(card.toastId);
                        else
                            Notifications.releaseToast(card.toastId);
                    }
                }

                NumberAnimation {
                    id: snapBack
                    target: shift
                    property: "x"
                    to: 0
                    duration: 280
                    easing.type: Easing.OutCubic
                }
                ParallelAnimation {
                    id: swipeOut
                    property int dir: -1
                    NumberAnimation {
                        target: shift
                        property: "x"
                        to: swipeOut.dir * (card.width + 32)
                        duration: 220
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: shift
                        property: "opacity"
                        to: 0
                        duration: 200
                    }
                    onFinished: {
                        if (card.toastId >= 0)
                            Notifications.discardToast(card.toastId);
                    }
                }

                // All content shifts (drag) and lifts (hover) as one unit.
                // Transforms only — layout untouched.
                Item {
                    id: shift
                    anchors.fill: parent
                    anchors.bottomMargin: 2
                    scale: card.isHovered && shift.x === 0 ? 1.012 : 1
                    Behavior on scale {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                    NotificationCardBody {
                        id: body
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 10
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        iconFile: card.toast ? card.toast.iconFile : ""
                        iconName: card.toast ? card.toast.iconName : ""
                        previewFile: card.toast ? card.toast.previewFile : ""
                        videoFile: card.toast ? card.toast.videoFile : ""
                        openFile: card.toast ? card.toast.openFile : ""
                        isRecorder: card.toast ? card.toast.isRecorder : false
                        critical: card.critical
                        title: (card.toast && card.toast.summary) || ""
                        bodyText: (card.toast && card.toast.body) || ""
                        hideBody: card.toast ? card.toast.hideBody : true
                        longBody: card.toast ? card.toast.longBody : false
                        stamp: card.toast ? card.toast.stamp : 0
                        actionItems: card.toast ? card.toast.actionDefs : []
                        controlsVisible: card.isHovered
                        videoActive: card.toastId >= 0
                        onOpenRequested: path => Notifications.openPath(path)
                        onCopyRequested: {
                            if (!card.toast)
                                return;
                            Notifications.copyToClipboard(card, card.toast.iconFile, card.toast.body || card.toast.summary);
                        }
                        onDismissRequested: {
                            if (card.toastId >= 0)
                                Notifications.discardToast(card.toastId);
                        }
                        onActionClicked: action => {
                            if (card.toastId >= 0)
                                Notifications.invokeToastAction(card.toastId, action.identifier);
                        }
                    }
                }

                // Timeout bar: a single animation (end4 ReloadPopup pattern).
                // Declaratively paused on hover; the service countdown is held
                // alongside, so visuals and expiry can never drift. Firing is
                // idempotent with the service timer.
                Rectangle {
                    id: barTrack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 2
                    visible: card.toast ? card.toast.life > 0 : false
                    color: Qt.alpha(Theme.fg, 0.08)
                    Rectangle {
                        id: barFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: barTrack.width
                        color: card.critical ? Qt.alpha("white", 0.75) : Theme.accent
                        // Transform-only: no layout pass per frame, GPU-composited.
                        transform: Scale {
                            id: barScale
                            origin.x: 0
                            xScale: 1
                        }
                        PropertyAnimation {
                            id: barAnim
                            target: barScale
                            property: "xScale"
                            from: 1
                            to: 0
                            duration: card.toast ? card.toast.life : 4000
                            paused: card.isHovered
                            onFinished: {
                                if (card.toastId >= 0)
                                    Notifications.expireToast(card.toastId);
                            }
                        }
                    }
                }
                Component.onCompleted: {
                    if (card.toast && card.toast.life > 0)
                        barAnim.start();
                }
            }
        }
    }
