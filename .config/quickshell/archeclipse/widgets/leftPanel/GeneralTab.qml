import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme
import qs.services

// GeneralTab — port of AGS General.tsx
// ArchEclipse avatar, version checking, update, links, GitHub stars
Item {
    id: root
    property string widgetWidth: parent?.width ?? 350

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string repoDir: homeDir
    readonly property string avatarPath: homeDir + "/.config/ags/assets/userpanel/archeclipse_default_pfp.jpg"

    // --- State ---
    property string currentVersion: ""
    property string remoteVersion: ""
    property bool isCheckingVersion: false
    property bool isUpdating: false
    property string updateStatus: ""
    property int starsCount: 0
    property bool isOutdated: currentVersion !== "" && remoteVersion !== "" && currentVersion !== remoteVersion && currentVersion !== "Unknown"

    // --- Process: check local HEAD --
    // (failure sets both Unknown and skips the remote check, like AGS)
    Process {
        id: localHashProc
        command: ["git", "-C", root.repoDir, "rev-parse", "--short", "HEAD"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.currentVersion = text.trim()
        }
        onExited: (code) => {
            if (code !== 0) {
                root.currentVersion = "Unknown"
                root.remoteVersion = "Unknown"
                root.isCheckingVersion = false
                return
            }
            // After local, check remote
            fetchRemoteProc.running = true
        }
    }

    // --- Process: fetch + check remote (AGS: upstream else origin,
    // fetch <remote> master, rev-parse <remote>/master — NOT @{u}, which
    // resolves the current branch's upstream and is wrong on detached HEAD
    // or branches without tracking)
    Process {
        id: fetchRemoteProc
        command: ["bash", "-c", "cd \"" + root.repoDir + "\" && R=$(git remote | grep -qx 'upstream' && echo upstream || echo origin); git fetch \"$R\" master 2>/dev/null; git rev-parse --short \"$R\"/master"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.remoteVersion = text.trim()
        }
        onExited: (code) => {
            root.isCheckingVersion = false
            if (code !== 0) {
                root.remoteVersion = "Unknown"
            }
        }
    }

    // --- Update launcher (AGS hl.dsp.exec_cmd via the Hyprland dispatcher;
    // bare `hyprctl dispatch exec` fails against the Lua registry) --
    function runUpdate() {
        try {
            Hyprland.dispatch("hl.dsp.exec_cmd('kitty zsh -ic \"clear; archeclipse\"')")
            root.isUpdating = false
            root.updateStatus = "Update started"
        } catch (e) {
            root.isUpdating = false
            root.updateStatus = "Update failed"
            Notifications.notify({ summary: "Launch Error", body: "Could not open kitty with archeclipse." })
        }
    }
    function doUpdate() {
        root.isUpdating = true
        root.updateStatus = ""
        root.runUpdate()
    }

    // --- Process: GitHub stars ---
    Process {
        id: starsProc
        command: ["bash", "-c", "curl -s https://api.github.com/repos/AymanLyesri/ArchEclipse | jq '.stargazers_count'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const count = parseInt(text.trim())
                if (!isNaN(count)) root.starsCount = count
            }
        }
    }

    // --- Init ---
    Component.onCompleted: {
        root.isCheckingVersion = true
        localHashProc.running = true
        starsProc.running = true
    }

    function checkVersions() {
        root.isCheckingVersion = true
        root.currentVersion = ""
        root.remoteVersion = ""
        localHashProc.running = true
    }

    // --- UI ---
    Flickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + 20
        clip: true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: contentColumn
            width: parent.width - 20
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16
            topPadding: 10

            // Avatar (circular clip via rounded container, like UserProfile)
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.widgetWidth / 2
                height: root.widgetWidth / 2
                radius: width / 2
                clip: true
                border.width: 2
                border.color: Theme.accent
                Image {
                    anchors.fill: parent
                    source: root.avatarPath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            // Title + Stars
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Text {
                    text: "ArchEclipse"
                    font.pixelSize: Theme.fontSize + 6
                    font.bold: true
                    color: Theme.foreground
                }
                Text {
                    text: root.starsCount > 0 ? "\u{F02D9} " + root.starsCount : ""
                    font.pixelSize: Theme.fontSize
                    color: Theme.accent
                }
            }

            // Link buttons
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                Repeater {
                    model: [
                        { icon: "\u{F09B}", url: "https://github.com/AymanLyesri/ArchEclipse", tip: "GitHub Repository" },
                        { icon: "\u{F188}", url: "https://github.com/AymanLyesri/ArchEclipse/issues", tip: "Issues Tracker" },
                        { icon: "\u{F392}", url: "https://discord.gg/fMGt4vH6s5", tip: "Discord Community" }
                    ]
                    delegate: Rectangle {
                        width: 40; height: 40; radius: 8
                        color: linkMa.containsMouse ? Theme.accentBg : Theme.moduleBg
                        border.width: 1; border.color: linkMa.containsMouse ? Theme.accent : Theme.border
                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.family: "Font Awesome 6 Free"
                            font.pixelSize: 18
                            color: linkMa.containsMouse ? Theme.accent : Theme.fg
                        }
                        MouseArea {
                            id: linkMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["xdg-open", modelData.url])
                            ToolTip { visible: linkMa.containsMouse; text: modelData.tip }
                        }
                    }
                }
            }

            // Separator
            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // Version section
            Column {
                width: parent.width
                spacing: 8

                // Loading state
                Text {
                    visible: root.isCheckingVersion
                    text: "\u{F2F0} Checking for updates..."
                    font.pixelSize: Theme.fontSize
                    color: Theme.fgDim
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // Results (when not checking)
                Column {
                    visible: !root.isCheckingVersion
                    width: parent.width
                    spacing: 10

                    // Outdated → show versions + update button
                    Column {
                        visible: root.isOutdated
                        spacing: 8
                        anchors.horizontalCenter: parent.horizontalCenter

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 10
                            Text { text: root.currentVersion; font.pixelSize: Theme.fontSize; color: Theme.fgDim }
                            Text { text: "\u{F061}"; font.pixelSize: Theme.fontSize; color: Theme.accent }
                            Text { text: root.remoteVersion; font.pixelSize: Theme.fontSize; color: Theme.accent; font.bold: true }
                        }

                        Rectangle {
                            width: updateMa.containsMouse ? 130 : 120; height: 32; radius: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: updateMa.containsMouse ? Theme.accentBg : Theme.accent
                            Behavior on width { NumberAnimation { duration: 150 } }
                            Text {
                                anchors.centerIn: parent
                                text: root.isUpdating ? "\u{F2F0} Updating..." : "\u{F019} Update"
                                font.pixelSize: Theme.fontSize
                                color: root.isUpdating ? Theme.fgDim : Theme.background
                                font.bold: true
                            }
                            MouseArea {
                                id: updateMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.isUpdating
                                onClicked: root.doUpdate()
                            }
                        }

                        Text {
                            visible: root.updateStatus !== ""
                            text: root.updateStatus
                            font.pixelSize: Theme.fontSize - 2
                            color: Theme.fgDim
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    // Up to date
                    Column {
                        visible: !root.isOutdated
                        spacing: 8
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            text: "\u{F00C} Up to date" + (root.updateStatus ? " - " + root.updateStatus : "")
                            font.pixelSize: Theme.fontSize
                            color: "#4CAF50"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Rectangle {
                            width: recheckMa.containsMouse ? 120 : 110; height: 28; radius: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: "transparent"
                            border.width: 1; border.color: Theme.border
                            visible: !root.isUpdating
                            Behavior on width { NumberAnimation { duration: 150 } }
                            Text {
                                anchors.centerIn: parent
                                text: "\u{F2F1} Check Update"
                                font.pixelSize: Theme.fontSize - 1
                                color: Theme.fg
                            }
                            MouseArea {
                                id: recheckMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.checkVersions()
                            }
                        }
                    }
                }
            }
        }
    }
}
