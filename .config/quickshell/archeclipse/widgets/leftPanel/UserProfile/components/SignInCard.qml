import QtQuick
import QtQuick.Controls
import qs.theme
import qs.widgets.shared

// Sign-in card (magic link + listener status + manual callback import). Exposes
// `callbackText` so the host can clear the paste field after a successful import.
Rectangle {
    id: root
    required property var store
    property alias callbackText: callbackField.text
    width: parent.width
    implicitHeight: signCol.implicitHeight + 20
    visible: !store.profile
    color: Theme.bg
    radius: Theme.radius

    Column {
        id: signCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.pad
        spacing: Theme.spacing
        Label {
            text: "Sign in to sync"
            font.pixelSize: Theme.fontSize + 1
            font.bold: true
            color: Theme.fg
        }
        Label {
            width: parent.width
            text: "\u2022 Profile picture\n\u2022 Settings\n\u2022 More to come"
            font.pixelSize: Theme.fontSize - 1
            color: Theme.fgDim
            wrapMode: Text.WordWrap
        }
        AppTextField {
            id: emailField
            width: parent.width
            cornerRadius: 4
            placeholderText: "you@example.com"
            text: ""
            onAccepted: store.sendMagicLink(emailField.text)
            onTextChanged: {
                if (store.magicState !== "Send Magic Link")
                    store.magicState = "Send Magic Link";
            }
        }
        AppButton {
            tooltipText: "Email a sign-in link"
            text: store.magicState
            width: parent.width
            enabled: emailField.text.trim().length > 0
            onClicked: store.sendMagicLink(emailField.text)
        }
        Label {
            width: parent.width
            text: store.authServerActive ? "Listener: running on :53100 — open the email link now." : store.authServerStatus === "error" ? "Listener failed — paste the link below instead." : "Listener: idle (starts when you send a link)."
            font.pixelSize: Theme.fontSize - 2
            color: Theme.fgDim
            wrapMode: Text.WordWrap
        }
        AppTextField {
            id: callbackField
            width: parent.width
            cornerRadius: 4
            placeholderText: "Paste callback URL here if the link fails…"
            onTextChanged: store.callbackUrlText = text
            onAccepted: store.importCallbackUrl(text)
        }
        AppButton {
            tooltipText: "Complete sign-in from a pasted link"
            text: "Import Pasted Link"
            width: parent.width
            enabled: store.callbackUrlText.trim().length > 0
            outlined: true
            onClicked: store.importCallbackUrl(callbackField.text)
        }
    }
}
