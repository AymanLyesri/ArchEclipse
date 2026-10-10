import QtQuick
import QtQuick.Controls
import qs.theme
import qs.services
import qs.widgets.notifications

// Single history card — body shared with the popup toasts via
// widgets/notifications/NotificationCardBody.qml (icon / preview slot,
// title + time row, expandable body, action + control buttons).
// Data comes from a history entry
// {id, time (epoch s, snapshot at receipt), notif (live object)}.
//
// Interactions:
//   - left-click anywhere on the card background copies the content
//     (image payload via wl-copy with its real MIME type, else text),
//   - right-click dismisses (removes it from history everywhere).
// The background MouseArea sits FIRST so the buttons above it stay
// clickable, and it lets presses through so the parent Flickable can
// still drag-scroll starting on the card.
Item {
    id: root
    property var entry: null
    readonly property var notification: entry ? entry.notif : null
    property bool isHovered: false

    // Snapshot receipt time (QS NotificationObject has no .time; popups use
    // toast.stamp the same way). Shown 24h %H:%M.
    readonly property double stamp: entry && entry.time ? entry.time : 0

    // ---- icon chain (Notifications service): appIcon path → appIcon theme
    // name → image path → image theme name → desktopEntry.
    // Recorder toasts show only the red dot, never a preview.
    readonly property bool isRecorder: Notifications.isRecorder(root.notification)
    readonly property bool critical: root.notification ? root.notification.urgency === 2 : false
    readonly property string iconFile: {
        if (!root.notification || root.isRecorder)
            return "";
        return Notifications.imageFile(root.notification);
    }
    readonly property string iconName: {
        if (!root.notification || root.isRecorder)
            return "";
        return Notifications.iconNameFor(root.notification);
    }
    readonly property string previewFile: {
        if (root.isRecorder || root.iconFile === "")
            return "";
        return Notifications.previewFor(root.iconFile);
    }
    readonly property string title: {
        if (!root.notification)
            return "";
        return ((root.notification.summary || root.notification.appName) || "").toString();
    }
    readonly property string bodyText: {
        if (!root.notification)
            return "";
        return ((root.notification.body) || "").toString();
    }
    readonly property bool hideBody: {
        if (root.bodyText === "")
            return true;
        if (root.bodyText === root.openFile)
            return true;
        return Notifications.bodyIsImage(root.notification, root.iconFile);
    }
    readonly property bool longBody: root.bodyText.length > 60 && !Notifications.bodyIsImage(root.notification, root.iconFile)
    // Openable file: screenshot icon path, else a path embedded in the
    // body (Recorder stop toast sends the full recording path).
    readonly property string openFile: {
        if (!root.notification)
            return "";
        if (root.isRecorder)
            return Notifications.filePathInText(root.bodyText);
        return root.iconFile;
    }
    readonly property string videoFile: Notifications.videoFor(root.openFile)

    height: card.height

    Rectangle {
        id: card
        width: parent.width
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
        color: root.critical ? Qt.rgba(0.66, 0.27, 0.27, 0.95) : Theme.surface
        border.color: root.isHovered ? Qt.alpha(Theme.accent, 0.5) : Qt.alpha(Theme.fg, 0.1)
        border.width: 1
        Behavior on border.color {
            ColorAnimation {
                duration: 200
            }
        }
        clip: true

        // Background interaction layer FIRST so buttons above stay
        // clickable. Left-click copies, right-click dismisses.
        // Presses pass through so the parent Flickable keeps
        // press-drag scrolling when the gesture starts on the card.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            propagateComposedEvents: true
            onPressed: mouse => mouse.accepted = false
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton)
                    root.copyContent();
                else if (mouse.button === Qt.RightButton)
                    root.dismiss();
            }
        }
        HoverHandler {
            onHoveredChanged: root.isHovered = hovered
        }

        // All content lifts as one unit on hover. Transforms only —
        // layout untouched.
        Item {
            id: shift
            anchors.fill: parent
            anchors.bottomMargin: 2
            scale: root.isHovered ? 1.012 : 1
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
                iconFile: root.iconFile
                iconName: root.iconName
                previewFile: root.previewFile
                videoFile: root.videoFile
                openFile: root.openFile
                isRecorder: root.isRecorder
                critical: root.critical
                title: root.title
                bodyText: root.bodyText
                hideBody: root.hideBody
                longBody: root.longBody
                stamp: root.stamp
                actionItems: root.notification ? Notifications.liveActions(root.notification) : []
                controlsVisible: root.isHovered
                tapToExpand: true
                copyTip: "Copy (left-click card)"
                dismissTip: "Dismiss (right-click card)"
                onOpenRequested: path => Notifications.openPath(path)
                onCopyRequested: root.copyContent()
                onDismissRequested: root.dismiss()
                onActionClicked: action => {
                    try {
                        action.invoke();
                    } catch (e) {}
                }
            }
        }
    }

    function copyContent() {
        const n = root.notification;
        if (!n)
            return;
        // Screenshot icons arrive as appIcon paths — the service copies
        // with the real MIME type; otherwise the body/title text.
        Notifications.copyToClipboard(root, root.iconFile, root.bodyText || root.title);
    }

    function dismiss() {
        try {
            if (root.notification)
                root.notification.dismiss();
        } catch (e) {}
    }
}
