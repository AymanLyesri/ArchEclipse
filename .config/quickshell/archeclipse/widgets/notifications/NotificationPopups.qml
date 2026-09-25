import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
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
    y: topBar ? pillY + pillH + 8 : pillY - height - 8

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
                property bool bodyExpanded: false
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

                    Column {
                        id: body
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 10
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 6

                        Row {
                            id: contentRow
                            width: parent.width
                            spacing: 10

                            // ---- app icon / image: the image takes the icon's
                            // place, spanning the text height (72-120px) ----
                            Item {
                                id: iconSlot
                                readonly property bool showPreview: card.toast && card.toast.previewFile !== "" && previewImg.status !== Image.Error
                                readonly property real previewSize: Math.min(Math.max(textCol.height, 72), 120)
                                width: showPreview ? previewSize : 28
                                height: showPreview ? previewSize : 28
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 250
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on height {
                                    NumberAnimation {
                                        duration: 250
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                IconImage {
                                    id: iconImg
                                    visible: !parent.showPreview && status === Image.Ready && card.toast && (card.toast.iconFile !== "" || card.toast.iconName !== "")
                                    anchors.fill: parent
                                    source: card.toast ? (card.toast.iconFile !== "" ? card.toast.iconFile : card.toast.iconName) : ""
                                }
                                Text {
                                    visible: !iconImg.visible && !parent.showPreview
                                    width: parent.width
                                    height: parent.height
                                    text: (card.toast && card.toast.isRecorder) ? "\uf111" : (card.critical ? "\u{F0266}" : "\u{F059A}")
                                    color: (card.toast && card.toast.isRecorder) ? "#c95454" : (card.critical ? "white" : Theme.fg)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 22
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Rectangle {
                                    visible: parent.showPreview
                                    opacity: previewImg.status === Image.Ready ? 1 : 0
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 250
                                        }
                                    }
                                    anchors.fill: parent
                                    radius: 8
                                    clip: true
                                    color: Qt.alpha(Theme.fg, 0.06)
                                    Image {
                                        id: previewImg
                                        anchors.fill: parent
                                        source: (card.toast && card.toast.previewFile !== "") ? "file://" + card.toast.previewFile : ""
                                        asynchronous: true
                                        cache: false
                                        fillMode: Image.PreserveAspectCrop
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (card.toast)
                                                Quickshell.execDetached(["xdg-open", card.toast.previewFile]);
                                        }
                                    }
                                }
                            }

                            Column {
                                id: textCol
                                width: (card.toast && card.toast.previewFile !== "") ? parent.width - 130 : parent.width - 38
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 250
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                spacing: 3

                                // ---- top bar: title + time (24h %H:%M) ----
                                RowLayout {
                                    spacing: 6
                                    width: parent.width
                                    Text {
                                        text: (card.toast && card.toast.summary) || ""
                                        textFormat: Text.StyledText
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        color: card.critical ? "white" : Theme.fg
                                        font.family: Theme.fontFamily
                                        font.bold: true
                                        font.pixelSize: Theme.fontSize
                                    }
                                    Text {
                                        text: (card.toast && card.toast.stamp > 0) ? new Date(card.toast.stamp * 1000).toLocaleTimeString([], {
                                            hour: "2-digit",
                                            minute: "2-digit",
                                            hour12: false
                                        }) : ""
                                        color: card.critical ? Qt.alpha("white", 0.7) : Theme.fgDim
                                        font.pixelSize: Theme.fontSize - 2
                                        visible: text !== ""
                                    }
                                }

                                // ---- body (expandable, markup handling) ----
                                // Hidden when it's just the image path — the
                                // image beside it already shows it.
                                Text {
                                    width: parent.width
                                    visible: card.toast ? !card.toast.hideBody : false
                                    text: (card.toast && card.toast.body) || ""
                                    textFormat: Text.StyledText
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: card.bodyExpanded ? undefined : 4
                                    elide: card.bodyExpanded ? Text.ElideNone : Text.ElideRight
                                    color: card.critical ? Qt.alpha("white", 0.85) : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                }
                            }
                        }

                        // ---- action buttons (all actions, invoke, NO dismiss) ----
                        Row {
                            id: actionsRow
                            visible: card.toast ? card.toast.actionDefs.length > 0 : false
                            spacing: 4
                            Repeater {
                                model: card.toast ? card.toast.actionDefs : []
                                delegate: AppButton {
                                    required property var modelData
                                    text: Notifications.actionLabel(modelData)
                                    height: 24
                                    pixelSize: Theme.fontSize - 2
                                    cornerRadius: 4
                                    idleBg: Theme.surface
                                    outlined: true
                                    onClicked: {
                                        if (card.toastId >= 0)
                                            Notifications.invokeToastAction(card.toastId, modelData.identifier);
                                    }
                                }
                            }
                        }

                        // ---- popup control buttons: copy, expand, dismiss ----
                        Row {
                            id: buttonsRow
                            visible: card.isHovered
                            opacity: card.isHovered ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 180
                                }
                            }
                            spacing: 4
                            AppButton {
                                icon: "󰃅"
                                pixelSize: 11
                                cornerRadius: 4
                                idleBg: Theme.surface
                                outlined: true
                                onClicked: {
                                    if (!card.toast)
                                        return;
                                    // Image payload via wl-copy + toast. Uses the
                                    // resolved file icon (screenshot arrives as
                                    // appIcon, not image) with its real MIME type.
                                    if (card.toast.iconFile !== "") {
                                        const imgPath = card.toast.iconFile;
                                        const p = Qt.createQmlObject("import Quickshell.Io; Process {}", card);
                                        p.command = ["bash", "-c", "wl-copy --type \"$(file -b --mime-type " + JSON.stringify(imgPath) + ")\" < " + JSON.stringify(imgPath)];
                                        p.exited.connect(code => {
                                            Notifications.notify(code === 0 ? {
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
                                    const t = card.toast.body || card.toast.summary;
                                    if (t)
                                        Quickshell.execDetached(["wl-copy", t]);
                                }
                            }
                            AppButton {
                                icon: card.bodyExpanded ? "󰁾" : "󰁼"
                                pixelSize: 11
                                cornerRadius: 4
                                idleBg: Theme.surface
                                outlined: true
                                visible: card.toast ? card.toast.longBody : false
                                onClicked: card.bodyExpanded = !card.bodyExpanded
                            }
                            AppButton {
                                icon: "󰀍"
                                pixelSize: 11
                                cornerRadius: 4
                                idleBg: Theme.surface
                                outlined: true
                                onClicked: {
                                    if (card.toastId >= 0)
                                        Notifications.discardToast(card.toastId);
                                }
                            }
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
