import QtQuick
import QtQuick.Controls
import Quickshell.Widgets
import qs.theme
import qs.widgets.shared

// Identity block: circular avatar standing alone above the card container.
// The card below holds the username + email/supporter flow + status.
// Exposes `username` (alias of the edit field) for the host's updateProfile().
Column {
    id: root
    required property var store
    property alias username: usernameField.text
    width: parent.width
    spacing: 12
    // Explicit height: plain Column parents position by explicit height.
    height: avatarBox.height + card.height + spacing

    // Avatar outside the container, centered.
    ClippingRectangle {
        id: avatarBox
        // Centered manually: parent is a Column positioner,
        // which ignores anchors on children.
        x: (parent.width - width) / 2
        width: Math.min(parent.width * 0.55, 180)
        height: width
        radius: width / 2
        color: Theme.bg
        AppImage {
            id: avatarImg
            anchors.fill: parent
            source: store.avatarSrc
            visible: status === Image.Ready
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.surfaceActive
            visible: avatarImg.status !== Image.Ready
            Text {
                anchors.centerIn: parent
                text: "\u{F007}"
                font.pixelSize: 48
                color: Theme.accent
            }
        }
        MouseArea {
            id: avatarMa
            anchors.fill: parent
            onClicked: store.chooseAvatar()
            AppTooltip {
                visible: avatarMa.containsMouse
                text: "Click to set up profile picture"
            }
        }
    }

    // Card container: identity fields only, no banner.
    Rectangle {
        id: card
        width: parent.width
        height: cardCol.implicitHeight + 20
        color: Theme.bg
        radius: 8

        Column {
            id: cardCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 10

            Column {
                id: idCol
                width: parent.width
                spacing: 6
                AppTextField {
                    id: usernameField
                    width: parent.width
                    cornerRadius: 4
                    placeholderText: store.homeDir.split("/").pop()
                    text: store.profile?.username ?? ""
                    horizontalAlignment: TextInput.AlignHCenter
                    onAccepted: store.updateProfile()
                    // Username entry tooltip
                    AppTooltip {
                        visible: usernameField.hovered
                        text: "Click to edit username"
                    }
                }
                Flow {
                    width: parent.width
                    spacing: 5
                    Label {
                        text: store.maskEmail(store.profile?.email ?? "")
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fgDim
                    }
                    Label {
                        text: "|"
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fgDim
                    }
                    AppBadge {
                        text: store.profile?.is_supporter === true ? "Supporter" : store.profile?.is_supporter === false ? "Member" : "…"
                        color: store.profile?.is_supporter === true ? Theme.accent : Theme.muted
                    }
                }
                AppProgress {
                    width: parent.width
                    // Plain Column ignores implicitHeight — bind it explicitly.
                    height: implicitHeight
                    status: store.progressStatus
                    variant: "inline"
                    loadingText: store.progressText !== "" ? store.progressText : "Working..."
                    errorText: store.progressText !== "" ? store.progressText : "Error — see notification"
                    successText: store.progressText !== "" ? store.progressText : "Ready"
                    idleText: store.progressText
                    showSuccess: true
                    showIdle: true
                }
            }
        }
    }
}
