import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Notifications
import qs.theme
import qs.services
import qs.widgets.shared

// Centered notification pill owned by Bar.qml (one per monitor), geometry pushed in from the bar.
// Rows are Toast snapshot wrappers, so bindings stay cheap and exit never null-derefs.
Item {
    id: root

    property string monitorName: ""
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
    // OSD stacking one level down: toasts dock below the volume/brightness OSD when it shows
    // (below media+OSD when both, which is rare: equal-priority states resolve one).
    property bool osdVisible: false
    property real osdY: 0
    property real osdH: 0
    // Workspace-wave push: an extra y offset while the hang is up so toasts dock beneath the
    // folding buttons (mediaY/osdY arrive already pushed).
    property real waveHang: 0

    width: 400
    height: popList.contentHeight

    // Centered under the main pill, clamped 8px inside the screen. x tracks the pill rigidly;
    // y for a bottom bar reads our own height (no loop, nothing reads y back).
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
            return pillY + pillH + 8 + root.waveHang;
        }
        if (root.osdVisible)
            return root.osdY - height - 8;
        if (root.mediaVisible)
            return root.mediaY - height - 8;
        return pillY - height - 8;
    }

    // Grace keeps the pill mapped while the last card slides out.
    readonly property var localToasts: Notifications.popupToastsFor(root.monitorName)
    property int toastCount: root.localToasts.length
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
                values: root.localToasts
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
                color: critical ? Theme.dangerSurface : Theme.surface
                border.color: isHovered ? Qt.alpha(Theme.accent, 0.5) : Qt.alpha(Theme.fg, 0.1)
                border.width: 1
                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.anim.defaultEffects
                    }
                }
                clip: true

                // Background interaction layer FIRST so buttons stay clickable: drag sideways past
                // the threshold to fling-dismiss, right-click dismisses instantly.
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
                        if (hovered) {
                            if (card.toastId >= 0)
                                Notifications.holdToast(card.toastId);
                        } else if (!card.toast || card.toast.progress < 0) {
                            // Progress toasts persist through unhover (no countdown to replace);
                            // they only leave via completion, swipe or right-click.
                            if (card.toastId >= 0)
                                Notifications.releaseToast(card.toastId);
                        }
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
                        duration: Theme.anim.defaultEffects
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

                // Timeout bar: one animation, paused declaratively on hover, so bar and expiry
                // cannot drift. A progress toast instead GROWS with the job (xScale per tick).
                Rectangle {
                    id: barTrack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 2
                    visible: card.toast ? (card.toast.life > 0 || card.toast.progress >= 0) : false
                    color: Qt.alpha(Theme.fg, 0.08)
                    Rectangle {
                        id: barFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: barTrack.width
                        color: card.critical ? Qt.alpha(Theme.criticalFg, Theme.opacity.hoverDim) : Theme.accent
                        // Transform-only: no layout pass per frame, GPU-composited.
                        transform: Scale {
                            id: barScale
                            origin.x: 0
                            xScale: card.toast && card.toast.progress >= 0 ? Math.max(0.015, card.toast.progress) : 1
                            Behavior on xScale {
                                Anim {
                                    duration: 180
                                }
                            }
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
