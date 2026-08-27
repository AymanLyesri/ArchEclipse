import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.services

// User Profile widget ported from widgets/leftPanel/components/UserProfile.tsx
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    Column {
        anchors.fill: parent
        spacing: 10

        // Profile Picture
        Rectangle {
            width: Math.min(parent.width * 0.5, 150)
            height: Math.min(parent.width * 0.5, 150)
            radius: width / 2
            border.width: 2
            border.color: Theme.accent
            clip: true

            // Placeholder - in real implementation would load from settings
            Rectangle {
                anchors.fill: parent
                color: Theme.accentBg
            }
            Text {
                anchors.centerIn: parent
                text: "👤"
                font.pixelSize: 48
                color: Theme.accent
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // TODO: Open file dialog for profile picture
                }
            }
        }

        // Profile Form
        Column {
            spacing: 5
            width: parent.width

            Label {
                text: "Profile"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
            }

            TextField {
                id: usernameField
                placeholderText: "Username"
                text: "User"
                Layout.fillWidth: true
                background: Rectangle {
                    color: Theme.bg
                    radius: 4
                    border.width: 1
                    border.color: Theme.border
                }
            }

            Row {
                spacing: 5
                Label {
                    text: "user@example.com"
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fgDim
                }
                Label {
                    text: "|"
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fgDim
                }
                Label {
                    text: "Supporter: No"
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fgDim
                }
            }
        }

        // Profile Actions
        Column {
            spacing: 5
            width: parent.width

            Button {
                text: "Update Profile"
                Layout.fillWidth: true
                onClicked: {
                    // TODO: Update profile
                }
                background: Rectangle {
                    color: Theme.accentBg
                    radius: 4
                    border.width: 1
                    border.color: Theme.accent
                }
                contentItem: Text {
                    anchors.centerIn: parent
                    color: Theme.accent
                    font.pixelSize: Theme.fontSize
                }
            }

            Button {
                text: "Refresh Profile"
                Layout.fillWidth: true
                onClicked: {
                    // TODO: Refresh profile
                }
                background: Rectangle {
                    color: Theme.moduleBg
                    radius: 4
                    border.width: 1
                    border.color: Theme.border
                }
                contentItem: Text {
                    anchors.centerIn: parent
                    color: Theme.fg
                    font.pixelSize: Theme.fontSize
                }
            }

            Button {
                text: "Logout"
                Layout.fillWidth: true
                onClicked: {
                    // TODO: Logout
                }
                background: Rectangle {
                    color: Theme.dangerBg
                    radius: 4
                    border.width: 1
                    border.color: Theme.danger
                }
                contentItem: Text {
                    anchors.centerIn: parent
                    color: Theme.danger
                    font.pixelSize: Theme.fontSize
                }
            }
        }

        // Settings Sync Section
        Column {
            spacing: 5
            width: parent.width

            Label {
                text: "Settings Sync"
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
                color: Theme.fg
            }

            Row {
                spacing: 8
                Button {
                    text: "Download"
                    Layout.fillWidth: true
                    onClicked: {
                        // TODO: Download settings
                    }
                    background: Rectangle {
                        color: Theme.accentBg
                        radius: 4
                        border.width: 1
                        border.color: Theme.accent
                    }
                    contentItem: Text {
                        anchors.centerIn: parent
                        color: Theme.accent
                        font.pixelSize: Theme.fontSize
                    }
                }
                Button {
                    text: "Upload"
                    Layout.fillWidth: true
                    onClicked: {
                        // TODO: Upload settings
                    }
                    background: Rectangle {
                        color: Theme.moduleBg
                        radius: 4
                        border.width: 1
                        border.color: Theme.border
                    }
                    contentItem: Text {
                        anchors.centerIn: parent
                        color: Theme.fg
                        font.pixelSize: Theme.fontSize
                    }
                }
            }

            Label {
                text: "Last sync: Never"
                font.pixelSize: Theme.fontSize - 1
                color: Theme.fgDim
            }
            Label {
                text: "Last result: -"
                font.pixelSize: Theme.fontSize - 1
                color: Theme.fgDim
            }
            Label {
                text: "Remote updated: Never"
                font.pixelSize: Theme.fontSize - 1
                color: Theme.fgDim
            }
        }

        // Login Section (when not logged in)
        Column {
            visible: false  // Set to true when not logged in
            spacing: 10
            width: parent.width

            Label {
                text: "Login to sync:"
                font.pixelSize: Theme.fontSize
                font.bold: true
                color: Theme.fg
            }

            Column {
                spacing: 4
                Label {
                    text: "- Profile picture"
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fgDim
                }
                Label {
                    text: "- Settings"
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fgDim
                }
                Label {
                    text: "More to come"
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fgDim
                }
            }

            TextField {
                placeholderText: "you@example.com"
                Layout.fillWidth: true
                background: Rectangle {
                    color: Theme.bg
                    radius: 4
                    border.width: 1
                    border.color: Theme.border
                }
            }

            Button {
                text: "Sign up / Login"
                Layout.fillWidth: true
                onClicked: {
                    // TODO: Send magic link
                }
                background: Rectangle {
                    color: Theme.accentBg
                    radius: 4
                    border.width: 1
                    border.color: Theme.accent
                }
                contentItem: Text {
                    anchors.centerIn: parent
                    color: Theme.accent
                    font.pixelSize: Theme.fontSize
                }
            }
        }
    }
}