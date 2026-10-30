import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme
import qs.widgets.shared
import qs.services

// GeneralTab — ArchEclipse identity: hero (avatar + version chip), repo stats, contributors,
// activity grid, update footer. Embedded in two hosts, so implicit sizes are the contract.
Item {
    id: root
    property real widgetWidth: parent ? parent.width : 350
    implicitWidth: Math.max(0, widgetWidth)
    // Full-bleed: parents (DonationsWidget, UserProfile About) own margins
    implicitHeight: contentColumn.implicitHeight

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string repoDir: homeDir
    readonly property string repoSlug: "AymanLyesri/ArchEclipse"
    readonly property string avatarPath: homeDir + "/.config/quickshell/archeclipse/assets/userpanel/archeclipse_default_pfp.jpg"

    // --- State ---
    property string currentVersion: ""
    property string remoteVersion: ""
    property bool isCheckingVersion: false
    property bool isUpdating: false
    property string updateStatus: ""
    // -1 = fetch failed / rate-limited → render as "–", never a fake 0
    property int starsCount: -1
    property int forksCount: -1
    property int issuesCount: -1
    property var contributors: []   // [{login, url, avatar, count}]
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

    // --- Process: fetch + check remote (upstream else origin). rev-parse <remote>/master,
    // NOT @{u} — that resolves the current branch and is wrong on detached HEAD ---
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

    // --- Process: repo meta (stars, forks, open issues — one call) ---
    Process {
        id: metaProc
        command: ["bash", "-c", "curl -s --max-time 10 https://api.github.com/repos/" + root.repoSlug + " | jq -r '[.stargazers_count, .forks_count, .open_issues_count] | @tsv'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("\t");
                const num = i => parseInt(p[i]);
                root.starsCount = isNaN(num(0)) ? -1 : num(0);
                root.forksCount = isNaN(num(1)) ? -1 : num(1);
                root.issuesCount = isNaN(num(2)) ? -1 : num(2);
            }
        }
    }

    // --- Process: contributors (top N by GitHub's ranking) ---
    Process {
        id: contributorsProc
        command: ["bash", "-c", "curl -s --max-time 10 'https://api.github.com/repos/" + root.repoSlug + "/contributors?per_page=20' | jq -r '.[] | [.login, .html_url, .avatar_url, .contributions] | @tsv'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const f = lines[i].split("\t");
                    if (f.length === 4)
                        out.push({ login: f[0], url: f[1], avatar: f[2] + "&s=64", count: parseInt(f[3]) });
                }
                root.contributors = out;
            }
        }
    }

    // --- Init ---
    Component.onCompleted: {
        root.isCheckingVersion = true;
        localHashProc.running = true;
        metaProc.running = true;
        contributorsProc.running = true;
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
        contentHeight: contentColumn.height
        clip: true
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: contentColumn
            width: generalFlick.width
            spacing: Theme.spacing

            // ── Hero: avatar + title + version chip + links ──
            Column {
                width: parent.width
                spacing: Theme.spacing

                // Circular avatar with accent ring (manual x-center —
                // parent is a Column positioner, anchors don't apply)
                Rectangle {
                    x: (parent.width - width) / 2
                    width: 84
                    height: 84
                    radius: width / 2
                    clip: true
                    border.width: 2
                    border.color: Theme.accent
                    AppImage {
                        anchors.fill: parent
                        source: root.avatarPath
                        // small circle → 160px decode is plenty (was 384)
                        sourceWidth: 160
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "ArchEclipse"
                    font.pixelSize: Theme.fontSize + 4
                    font.bold: true
                    color: Theme.fg
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.currentVersion !== "" && root.currentVersion !== "Unknown" ? "build " + root.currentVersion : ""
                    font.pixelSize: Theme.fontSizeCaption
                    color: Theme.fgDim
                    visible: text !== ""
                }

                Row {
                    x: (parent.width - width) / 2
                    spacing: Theme.spacing
                    Repeater {
                        model: [
                            {
                                icon: Icons.github,
                                url: "https://github.com/" + root.repoSlug,
                                tip: "GitHub Repository"
                            },
                            {
                                icon: Icons.bug,
                                url: "https://github.com/" + root.repoSlug + "/issues",
                                tip: "Issues Tracker"
                            },
                            {
                                icon: Icons.discord,
                                url: "https://discord.gg/fMGt4vH6s5",
                                tip: "Discord Community"
                            }
                        ]
                        delegate: AppButton {
                            width: 38
                            height: 38
                            cornerRadius: 8
                            outlined: true
                            icon: modelData.icon
                            pixelSize: Theme.fs(1.4)
                            tooltipText: modelData.tip
                            onClicked: Quickshell.execDetached(["xdg-open", modelData.url])
                        }
                    }
                }
            }

            // ── Stats: stars / forks / issues (one repo API call) ──
            Card {
                width: parent.width
                height: statsRow.implicitHeight + Theme.pad * 2
                contentSpacing: 0
                Row {
                    id: statsRow
                    width: parent.width
                    Repeater {
                        model: [
                            { icon: Icons.star, label: "Stars", count: root.starsCount },
                            { icon: Icons.codeFork, label: "Forks", count: root.forksCount },
                            { icon: Icons.issue, label: "Issues", count: root.issuesCount }
                        ]
                        delegate: Column {
                            width: statsRow.width / 3
                            spacing: 2
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 5
                                Text {
                                    text: modelData.icon
                                    font.pixelSize: Theme.fontSize
                                    color: Theme.accent
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.count < 0 ? "–" : modelData.count
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                    color: Theme.fg
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeCaption
                                color: Theme.fgDim
                            }
                        }
                    }
                }
            }

            // ── Contributors face-pile (hidden until the API answers) ──
            Card {
                width: parent.width
                visible: root.contributors.length > 0
                contentSpacing: Theme.spacing
                height: visible ? faceCol.implicitHeight + Theme.pad * 2 : 0
                Column {
                    id: faceCol
                    width: parent.width
                    spacing: Theme.spacing

                    Row {
                        spacing: 6
                        Text {
                            text: Icons.users
                            font.pixelSize: Theme.fontSize
                            color: Theme.accent
                        }
                        Text {
                            text: "Contributors"
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                            color: Theme.fg
                        }
                    }

                    Item {
                        width: parent.width
                        height: 34
                        // Overlapping face-pile: manual x per member (Row
                        // can't do negative spacing)
                        Repeater {
                            model: root.contributors.slice(0, 10)
                            delegate: Rectangle {
                                x: index * 26
                                width: 34
                                height: 34
                                radius: width / 2
                                clip: true
                                border.width: 2
                                border.color: Theme.surface
                                AppImage {
                                    anchors.fill: parent
                                    source: modelData.avatar
                                    sourceWidth: 68
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["xdg-open", modelData.url])
                                }
                            }
                        }
                        Text {
                            visible: root.contributors.length > 10
                            anchors.verticalCenter: parent.verticalCenter
                            x: 10 * 26 + 8
                            text: "+" + (root.contributors.length - 10)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.fgDim
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/" + root.repoSlug + "/graphs/contributors"])
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.contributors.length > 0 ? "Thanks to everyone building ArchEclipse." : ""
                        font.pixelSize: Theme.fontSizeCaption
                        color: Theme.fgDim
                        visible: text !== ""
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ── Activity: commit grid ──
            Card {
                width: parent.width
                height: activityCol.implicitHeight + Theme.pad * 2
                contentSpacing: Theme.spacing
                Column {
                    id: activityCol
                    width: parent.width
                    spacing: Theme.spacing

                    Row {
                        spacing: 6
                        Text {
                            text: Icons.chart
                            font.pixelSize: Theme.fontSize
                            color: Theme.accent
                        }
                        Text {
                            text: "Activity"
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                            color: Theme.fg
                        }
                    }

                    CommitGrid {}
                }
            }

            // ── Update footer ──
            Card {
                width: parent.width
                height: updateCol.implicitHeight + Theme.pad * 2
                contentSpacing: Theme.spacing
                Column {
                    id: updateCol
                    width: parent.width
                    spacing: Theme.spacing

                    // Loading state
                    Text {
                        visible: root.isCheckingVersion
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Icons.spinner + " Checking for updates..."
                        font.pixelSize: Theme.fontSize
                        color: Theme.fgDim
                    }

                    // Results (when not checking)
                    Column {
                        visible: !root.isCheckingVersion
                        width: parent.width
                        spacing: Theme.spacing

                        // Outdated → show versions + update button
                        Column {
                            visible: root.isOutdated
                            width: parent.width
                            spacing: Theme.spacing

                            Row {
                                x: (parent.width - width) / 2
                                spacing: Theme.spacing
                                Text {
                                    text: root.currentVersion
                                    font.pixelSize: Theme.fontSize
                                    color: Theme.fgDim
                                }
                                Text {
                                    text: Icons.arrowRight
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
                                tooltipText: "Download and install updates"
                                height: 32
                                cornerRadius: 6
                                idleBg: Theme.accent
                                hoverBg: Theme.surfaceActive
                                pressedBg: Theme.surfaceActive
                                idleFg: Theme.bg
                                hoverFg: Theme.bg
                                icon: root.isUpdating ? Icons.spinner : Icons.download
                                text: root.isUpdating ? "Updating..." : "Update"
                                pixelSize: Theme.fontSize
                                enabled: !root.isUpdating
                                onClicked: root.doUpdate()
                            }
                        }

                        // Up to date
                        Column {
                            visible: !root.isOutdated
                            width: parent.width
                            spacing: Theme.spacing

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: Icons.check + " Up to date" + (root.updateStatus ? " - " + root.updateStatus : "")
                                font.pixelSize: Theme.fontSize
                                color: Theme.success
                            }

                            AppButton {
                                x: (parent.width - width) / 2
                                width: 130
                                tooltipText: "Check for new versions"
                                height: 28
                                cornerRadius: 6
                                icon: Icons.sync
                                text: "Check Update"
                                pixelSize: Theme.fontSize - 1
                                visible: !root.isUpdating
                                onClicked: root.checkVersions()
                            }
                        }
                    }

                    Text {
                        visible: root.updateStatus !== "" && root.isOutdated
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.updateStatus
                        font.pixelSize: Theme.fontSizeCaption
                        color: Theme.fgDim
                    }
                }
            }
        }
    }
}
