import Quickshell
import QtQuick
import QtQuick.Controls
import qs.theme
import qs.services

Item {
    id: root

    property string className: ""

    // User profile data
    property string profilePicture: Settings.profilePicturePath
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
                border.color: Theme.accent
                border.width: 3
            }
        }

        // Username
        Text {
            text: root.username
            font.family: "JetBrainsMono NFP"
            font.pixelSize: 18
            font.bold: true
            color: Theme.foreground
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Email
        Text {
            text: root.email
            font.family: "JetBrainsMono NFP"
            font.pixelSize: 11
            color: Theme.color8
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Supporter badge
        Rectangle {
            visible: root.isSupporter
            width: 100
            height: 28
            radius: 14
            color: Theme.accentBg
            border.color: Theme.accent
            border.width: 1
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.centerIn: parent
                text: "\u{2764} Supporter"
                font.family: "JetBrainsMono NFP"
                font.pixelSize: 10
                color: Theme.accent
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
                background: Rectangle { color: Theme.accentBg; border.color: Theme.accent; border.width: 1; radius: 4 }
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
                background: Rectangle { color: Theme.color0; border.color: Theme.color8; border.width: 1; radius: 4 }
                padding: 10
            }
        }
    }
}