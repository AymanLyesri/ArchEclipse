import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.widgets.shared

// Minimal mode (avatar + username): used by the lockscreen overlay.
Item {
    id: root
    required property var store
    anchors.fill: parent
    visible: store.minimal
    Column {
        anchors.centerIn: parent
        width: store.width
        spacing: 10
        ClippingRectangle {
            // Centered manually: parent is a Column positioner,
            // which ignores anchors on children.
            x: (parent.width - width) / 2
            width: Math.min(store.width * 0.5, 140)
            height: Math.min(store.width * 0.5, 140)
            radius: width / 2
            AppImage {
                id: minAvatarImg
                anchors.fill: parent
                source: store.avatarSrc

                visible: status === Image.Ready
            }
            Rectangle {
                anchors.fill: parent
                color: Theme.surfaceActive
                visible: minAvatarImg.status !== Image.Ready
                Text {
                    anchors.centerIn: parent
                    text: "\u{F007}"
                    font.pixelSize: 56
                    color: Theme.accent
                }
            }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: store.profile?.username ?? "Not signed in"
            font.pixelSize: Theme.fontSize * 2
            font.bold: true
            color: Theme.fg
            elide: Text.ElideRight
        }
        AppBadge {
            x: (parent.width - width) / 2
            visible: store.profile?.is_supporter === true
            text: "Supporter"
            color: Theme.accent
        }
    }
}
