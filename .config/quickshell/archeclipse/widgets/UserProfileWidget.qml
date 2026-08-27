import Quickshell
import QtQuick
import qs.theme
import QtQuick.Controls

Item {
    id: root

    property string className: ""

    // User profile data
    property string profilePicture: qs.theme.Settings.profilePicturePath
    property string username: "ayman"
    property string email: "user@example.com"
    property bool isSupporter: false

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // Profile picture
        Rectangle {
            id: profilePic
            width: 100
            height: 100
            radius: 50
            anchors.horizontalCenter: parent.horizontalCenter
            clip: true

            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: root.profilePicture
            }

            Rectangle {
                anchors.fill: parent
                radius: 50
                border.color: qs.theme.Theme.accent
                border.width: 3
            }
        }

        // Username
        Text {
            text: root.username
            font.family: "JetBrainsMono NFP"
            font.pixelSize: 18
            font.bold: true
            color: qs.theme.Theme.foreground
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Email
        Text {
            text: root.email
            font.family: "JetBrainsMono NFP"
            font.pixelSize: 11
            color: qs.theme.Theme.color8
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Supporter badge
        Rectangle {
            visible: root.isSupporter
            width: 100
            height: 28
            radius: 14
            color: qs.theme.Theme.accentBg
            border.color: qs.theme.Theme.accent
            border.width: 1
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.centerIn: parent
                text: "❤ Supporter"
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 10
                color: qs.theme.Theme.accent
            }
        }

        // Action buttons
        Column {
            spacing: 10
            width: parent.width

            Button {
                text: "Sync Settings"
                width: parent.width
                onClicked: {
                    // Sync settings to cloud
                }
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 12
                background: Rectangle { color: qs.theme.Theme.accentBg; border.color: qs.theme.Theme.accent; border.width: 1; radius: 4 }
                padding: 10
            }

            Button {
                text: "Login / Register"
                width: parent.width
                onClicked: {
                    // Open login dialog
                }
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 12
                background: Rectangle { color: qs.theme.Theme.color0; border.color: qs.theme.Theme.color8; border.width: 1; radius: 4 }
                padding: 10
            }
        }
    }
}