import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme
import qs.widgets.shared
import qs.services

// GeneralTab — ArchEclipse avatar, version checking, update, links, GitHub stars
Item {
    id: root
    // NOTE: real-number width (was string: relied on JS coercion), and an
    // implicitHeight so embeds inside plain Columns (Donations) can size
    // off content instead of collapsing to 0.
    property real widgetWidth: parent ? parent.width : 350
    implicitHeight: contentColumn.implicitHeight + 30

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string repoDir: homeDir
    readonly property string avatarPath: homeDir + "/.config/quickshell/archeclipse/assets/userpanel/archeclipse_default_pfp.jpg"

    // --- State ---
    property string currentVersion: ""
    property string remoteVersion: ""
    property bool isCheckingVersion: false
    property bool isUpdating: false
    property string updateStatus: ""
    property int starsCount: 0
    property bool isOutdated: currentVersion !== "" && remoteVersion !== "" && currentVersion !== remoteVersion && currentVersion !== "Unknown"

    // --- Process: check local HEAD --
    // (failure sets both Unknown and skips the remote check)
    Process {
        id: localHashProc
        command: ["git", "-C", root.repoDir, "rev-parse", "--short", "HEAD"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.currentVersion = text.trim()
        }
        onExited: code => {
            if (code !== 0) {
                root.currentVersion = "Unknown";
                root.remoteVersion = "Unknown";
                root.isCheckingVersion = false;
                return;
            }
            // After local, check remote
            fetchRemoteProc.running = true;
        }
    }

    // --- Process: fetch + check remote (upstream else origin,
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
        onExited: code => {
            root.isCheckingVersion = false;
            if (code !== 0) {
                root.remoteVersion = "Unknown";
            }
        }
    }

    // --- Update launcher (via the Hyprland dispatcher;
    // bare `hyprctl dispatch exec` fails against the Lua registry) --
    function runUpdate() {
        try {
            Hyprland.dispatch("hl.dsp.exec_cmd('foot zsh -ic \"clear; archeclipse\"')");
            root.isUpdating = false;
            root.updateStatus = "Update started";
        } catch (e) {
            root.isUpdating = false;
            root.updateStatus = "Update failed";
            Notifications.notify({
                summary: "Launch Error",
                body: "Could not open foot with archeclipse."
            });
        }
    }
    function doUpdate() {
        root.isUpdating = true;
        root.updateStatus = "";
        root.runUpdate();
    }

    // --- Process: GitHub stars ---
    Process {
        id: starsProc
        command: ["bash", "-c", "curl -s https://api.github.com/repos/AymanLyesri/ArchEclipse | jq '.stargazers_count'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const count = parseInt(text.trim());
                if (!isNaN(count))
                    root.starsCount = count;
            }
        }
    }

    // --- Init ---
    Component.onCompleted: {
        root.isCheckingVersion = true;
        localHashProc.running = true;
        starsProc.running = true;
    }

    function checkVersions() {
        root.isCheckingVersion = true;
        root.currentVersion = "";
        root.remoteVersion = "";
        localHashProc.running = true;
    }

    // --- UI ---
    SmoothFlickable {
        id: generalFlick
        anchors.fill: parent
        contentWidth: generalFlick.width
        contentHeight: contentColumn.height + 20
        clip: true
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: contentColumn
            width: generalFlick.width - 20
            x: 10
            spacing: 16
            topPadding: 10

            // Avatar (circular clip via rounded container, like UserProfile).
            // NOTE: manual x-centering — parent is a Column positioner,
            // which ignores anchors on children.
            Rectangle {
                x: (parent.width - width) / 2
                width: root.widgetWidth / 2
                height: root.widgetWidth / 2
                radius: width / 2
                clip: true
                border.width: 2
                border.color: Theme.accent
                AppImage {
                    anchors.fill: parent
                    source: root.avatarPath
                }
            }

            // Title + Stars
            Row {
                x: (parent.width - width) / 2
                spacing: 8
                Text {
                    text: "ArchEclipse"
                    font.pixelSize: Theme.fontSize + 6
                    font.bold: true
                    color: Theme.fg
                }
                Text {
                    text: root.starsCount > 0 ? "\uf005  " + root.starsCount : ""
                    font.pixelSize: Theme.fontSize
                    color: Theme.accent
                }
            }

            // Link buttons
            Row {
                x: (parent.width - width) / 2
                spacing: 12
                Repeater {
                    model: [
                        {
                            icon: "\uf09b",
                            url: "https://github.com/AymanLyesri/ArchEclipse",
                            tip: "GitHub Repository"
                        },
                        {
                            icon: "\uf188",
                            url: "https://github.com/AymanLyesri/ArchEclipse/issues",
                            tip: "Issues Tracker"
                        },
                        {
                            icon: "\uf1ff",
                            url: "https://discord.gg/fMGt4vH6s5",
                            tip: "Discord Community"
                        }
                    ]
                    delegate: AppButton {
                        width: 40
                        height: 40
                        cornerRadius: 8
                        outlined: true
                        icon: modelData.icon
                        pixelSize: 18
                        tooltipText: modelData.tip
                        onClicked: Quickshell.execDetached(["xdg-open", modelData.url])
                    }
                }
            }

            // Separator
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            // Version section
            Column {
                width: parent.width
                spacing: 8

                // Loading state
                Text {
                    visible: root.isCheckingVersion
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "\u{F2F0} Checking for updates..."
                    font.pixelSize: Theme.fontSize
                    color: Theme.fgDim
                }

                // Results (when not checking)
                Column {
                    visible: !root.isCheckingVersion
                    width: parent.width
                    spacing: 10

                    // Outdated → show versions + update button
                    Column {
                        visible: root.isOutdated
                        width: parent.width
                        spacing: 8

                        Row {
                            x: (parent.width - width) / 2
                            spacing: 10
                            Text {
                                text: root.currentVersion
                                font.pixelSize: Theme.fontSize
                                color: Theme.fgDim
                            }
                            Text {
                                text: "\u{F061}"
                                font.pixelSize: Theme.fontSize
                                color: Theme.accent
                            }
                            Text {
                                text: root.remoteVersion
                                font.pixelSize: Theme.fontSize
                                color: Theme.accent
                                font.bold: true
                            }
                        }

                        AppButton {
                            x: (parent.width - width) / 2
                            width: 120
                            height: 32
                            cornerRadius: 6
                            idleBg: Theme.accent
                            hoverBg: Theme.surfaceActive
                            pressedBg: Theme.surfaceActive
                            idleFg: Theme.bg
                            hoverFg: Theme.bg
                            icon: root.isUpdating ? "\u{F2F0}" : "\u{F019}"
                            text: root.isUpdating ? "Updating..." : "Update"
                            pixelSize: Theme.fontSize
                            enabled: !root.isUpdating
                            onClicked: root.doUpdate()
                        }

                        Text {
                            visible: root.updateStatus !== ""
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: root.updateStatus
                            font.pixelSize: Theme.fontSize - 2
                            color: Theme.fgDim
                        }
                    }

                    // Up to date
                    Column {
                        visible: !root.isOutdated
                        width: parent.width
                        spacing: 8

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "\u{F00C} Up to date" + (root.updateStatus ? " - " + root.updateStatus : "")
                            font.pixelSize: Theme.fontSize
                            color: "#4CAF50"
                        }

                        AppButton {
                            x: (parent.width - width) / 2
                            width: 130
                            height: 28
                            cornerRadius: 6
                            icon: "\u{F2F1}"
                            text: "Check Update"
                            pixelSize: Theme.fontSize - 1
                            visible: !root.isUpdating
                            onClicked: root.checkVersions()
                        }
                    }
                }
            }
        }
    }
}
