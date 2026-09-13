import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.widgets.shared
import qs.services

// Custom Scripts widget — scrollable list of utility scripts. Record
// entries route through the ScreenRecorder service, the file manager entry
// uses Settings.fileManager, reset shows a Yes/No confirmation, everything
// else spawns via Quickshell.execDetached. Scripts requiring an installed
// binary show an install button when the app is missing (yay/paru/pacman
// via kitty).
Item {
    id: root

    // Utility script definitions — icons are Nerd Font codepoints. kind
    // marks entries whose callback does more than a plain exec (record
    // toggle, dynamic file manager, reset confirmation).
    property var scriptDefs: [
        {
            name: "Restart Bar",
            icon: "󰜉",
            description: "Restart the shell bar",
            keybind: ["SUPER", "B"],
            command: "bash -c \"$HOME/.config/hypr/scripts/bar.sh\""
        },
        {
            name: "HyprPicker",
            icon: "",
            description: "Color Picker for Hyprland",
            app: "hyprpicker",
            command: "hyprpicker"
        },
        {
            name: "Change Resolution",
            icon: "󰍹",
            description: "Change Resolution",
            app: "nwg-displays",
            package: "nwg-displays",
            command: "kitty nwg-displays -m ~/.config/hypr/config/custom/monitors.conf"
        },
        {
            name: "Update Packages",
            icon: "󰏗",
            description: "Update Packages (pacman)",
            command: "kitty -e sudo pacman -Syu"
        },
        {
            name: "Clear Clipboard",
            icon: "󰃢",
            description: "Clear clipboard history",
            app: "wl-copy",
            package: "wl-clipboard",
            command: "wl-copy --clear"
        },
        {
            name: "Screenshot Screen",
            icon: "",
            description: "Screenshot entire screen",
            keybind: ["SUPER", "SHIFT", "S"],
            app: "grimblast",
            package: "grimblast-git",
            command: "bash -c \"$HOME/.config/hypr/scripts/screenshot.sh --now\""
        },
        {
            name: "Screenshot Area",
            icon: "",
            description: "Select area to screenshot",
            keybind: ["SUPER", "CTRL", "SHIFT", "S"],
            app: "grimblast",
            package: "grimblast-git",
            command: "bash -c \"$HOME/.config/hypr/scripts/screenshot.sh --area\""
        },
        {
            name: "Record Screen",
            icon: "",
            description: "Record entire screen",
            keybind: ["SUPER", "SHIFT", "R"],
            app: "wf-recorder",
            kind: "record-now"
        },
        {
            name: "Record Area",
            icon: "",
            description: "Record selected area",
            keybind: ["SUPER", "CTRL", "SHIFT", "R"],
            app: "wf-recorder",
            kind: "record-area"
        },
        {
            name: "Refresh Hyprland",
            icon: "󰑓",
            description: "Refresh Hyprland (reload config)",
            command: "hyprctl reload"
        },
        {
            name: "System Monitor",
            icon: "󰍛",
            description: "Open system monitor",
            app: "btop",
            command: "kitty -e btop"
        },
        {
            name: "Volume Control",
            icon: "󰕾",
            description: "Adjust volume",
            app: "pavucontrol",
            command: "pavucontrol"
        },
        {
            name: "File Manager",
            icon: "󰉋",
            description: "Open the configured file manager",
            kind: "file-manager"
        },
        {
            name: "Lazygit",
            icon: "󰊢",
            description: "Git Manager",
            app: "lazygit",
            command: "bash -c \"lazygit\""
        },
        {
            name: "Visual Studio Code",
            icon: "󰨞",
            description: "Code Editor",
            app: "code",
            package: "visual-studio-code-bin",
            command: "code"
        },
        {
            name: "Spotube",
            icon: "",
            description: "Spotify Client (lightweight - downloaded music)",
            app: "spotube",
            package: "spotube-bin",
            command: "spotube"
        },
        {
            name: "Steam",
            icon: "",
            description: "Game Launcher",
            app: "steam",
            command: "steam"
        },
        {
            name: "Pipes.sh",
            icon: "󰟥",
            description: "Pipes Animation",
            app: "pipes.sh",
            command: "kitty -e pipes.sh"
        },
        {
            name: "Cava",
            icon: "󰕾",
            description: "Audio Visualizer",
            app: "cava",
            command: "kitty -e cava"
        },
        {
            name: "CMatrix",
            icon: "󱔼",
            description: "Matrix Digital Rain",
            app: "cmatrix",
            command: "kitty -e cmatrix"
        },
        {
            name: "Asciiquarium",
            icon: "",
            description: "Aquarium Animation",
            app: "asciiquarium",
            command: "kitty -e asciiquarium"
        },
        {
            name: "Pacgraph",
            icon: "󰏗",
            description: "Visualize package sizes (pacgraph -c)",
            app: "pacgraph",
            command: "kitty -e bash -c \"pacgraph -c; read -n 1 -s -r -p 'Press any key to continue...'\""
        },
        {
            name: "Reset Settings",
            icon: "󰜉",
            description: "Reset all shell settings to default",
            kind: "reset-settings"
        }
    ]

    // app availability: filled async on load. Reassigned (not mutated) so
    // bindings re-evaluate when each check finishes.
    property var appStatus: ({})

    // Replayable staggered reveal: StackLayout builds all tabs once at
    // startup (hidden), so creation-time timers would fire unseen and the
    // tab switch would only play the container-wide fade. Instead a
    // counter steps 0→N each time this tab becomes visible and rows key
    // their opacity off their index.
    property int revealCount: 0
    Timer {
        id: revealTimer
        interval: 30
        repeat: true
        onTriggered: {
            if (root.revealCount >= root.scriptDefs.length)
                revealTimer.stop();
            else
                root.revealCount++;
        }
    }
    function playReveal() {
        root.revealCount = 0;
        revealTimer.restart();
    }
    onVisibleChanged: {
        if (visible)
            root.playReveal();
    }

    Component.onCompleted: {
        refreshAppStatus();
        if (visible)
            playReveal();
    }

    function refreshAppStatus() {
        const needed = [];
        for (const s of scriptDefs)
            if (s.app)
                needed.push(s.app);
        const unique = needed.filter((v, i, a) => a.indexOf(v) === i);
        for (const app of unique) {
            const chk = appCheckComp.createObject(root, {
                appName: app
            });
            chk.running = true;
        }
    }

    property Component appCheckComp: Component {
        Process {
            id: _appChk
            property string appName: ""
            command: ["bash", "-c", "command -v " + appName + " >/dev/null 2>&1 && echo true || echo false"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const s = Object.assign({}, root.appStatus);
                    s[_appChk.appName] = text.trim() === "true";
                    root.appStatus = s;
                    _appChk.destroy();
                }
            }
        }
    }

    property Component installProcComp: Component {
        // Spawn the install through `kitty -e` so that sudo pacman can
        // prompt for the password interactively in a terminal. Headless
        // pacman will hang on the password prompt and lock up forever.
        // We exec kitty with the bash branch inline so the user sees the
        // progress and can enter their sudo password when prompted.
        Process {
            id: _instProc
            property string pkgName: ""
            // kitty's argv doesn't take "-e cmd; cmd2", so wrap in bash -c
            command: ["kitty", "-e", "bash", "-c", "if command -v yay >/dev/null 2>&1; then yay -S " + pkgName + "; elif command -v paru >/dev/null 2>&1; then paru -S " + pkgName + "; else sudo pacman -S " + pkgName + "; fi; echo; " + "echo 'Press any key to close...'; read -n 1 -s -r"]
            onExited: code => {
                if (code === 0)
                    root.refreshAppStatus();
                else
                    Notifications.notify({
                        summary: "Error",
                        body: "Failed to install " + pkgName + ". Please install it manually."
                    });
                _instProc.destroy();
            }
        }
    }

    property Component resetProcComp: Component {
        Process {
            id: _resetProc
            command: ["bash", "-c", "rm -rf $HOME/.cache/quickshell/settings/settings.json"]
            stdout: StdioCollector {
                onStreamFinished: {
                    // NOTE: must not go through Hyprland.dispatch("exec ...") —
                    // Hyprland >= 0.55 uses a Lua config and rejects the legacy
                    // string-dispatch exec syntax. execDetached spawns directly.
                    Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/bar.sh"]);
                    _resetProc.destroy();
                }
            }
        }
    }

    function displayName(def) {
        if (def.kind === "file-manager") {
            const fm = Settings.fileManager || "";
            return fm ? fm + " File Manager" : "File Manager";
        }
        return def.name;
    }

    function runScript(def) {
        // Special-kind callbacks that are more than a plain exec
        if (def.kind === "record-now") {
            ScreenRecorder.toggleRecording("now");
            return;
        }
        if (def.kind === "record-area") {
            ScreenRecorder.toggleRecording("area");
            return;
        }
        // NOTE: spawn via Quickshell.execDetached, NOT Hyprland.dispatch("exec ...").
        // Hyprland >= 0.55 (Lua config) rejects the legacy string-dispatch exec
        // syntax ("... ')' expected ..."), so every click silently did nothing.
        // Running through bash -c preserves the complex quoted commands below.
        if (def.kind === "file-manager") {
            Quickshell.execDetached(["bash", "-c", (Settings.fileManager || "thunar")]);
            return;
        }
        if (def.command)
            Quickshell.execDetached(["bash", "-c", def.command]);
    }

    function appInstalled(def) {
        if (!def.app)
            return true;
        const st = root.appStatus[def.app];
        return st === undefined ? true : st;
    }

    function installApp(def) {
        const pkg = def.package || def.app;
        const proc = installProcComp.createObject(root, {
            pkgName: pkg
        });
        proc.running = true;
    }

    function doReset() {
        const proc = resetProcComp.createObject(root);
        proc.running = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Label {
            text: "Custom Scripts"
            font.pixelSize: Theme.fontSize + 4
            font.bold: true
            color: Theme.fg
            Layout.fillWidth: true
        }

        SmoothFlickable {
            id: scriptScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: scriptCol.height
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            Column {
                id: scriptCol
                spacing: 8
                width: scriptScroll.width

                Repeater {
                    model: root.scriptDefs
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        property bool confirming: false
                        width: parent.width
                        implicitHeight: rowContent.implicitHeight + 20
                        color: Theme.surface
                        radius: 8
                        // Row appears when the reveal counter passes its
                        // position (see root.playReveal).
                        opacity: index < root.revealCount ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }

                        // The whole row is the script button — click runs it.
                        // Reset shows a Yes/No confirmation instead.
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.appInstalled(modelData)
                            onClicked: {
                                if (modelData.kind === "reset-settings")
                                    confirming = true;
                                else
                                    root.runScript(modelData);
                            }
                            AppTooltip {
                                visible: rowMouse.containsMouse
                                text: root.appInstalled(modelData) ? modelData.description : modelData.description + " (Requires installation)"
                            }
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            // NOTE: RowLayout (not Row) — verticalCenter anchors
                            // are ignored inside positioners, so alignment
                            // goes through Layout.alignment instead.
                            RowLayout {
                                id: rowContent
                                spacing: 12
                                width: parent.width

                                Label {
                                    text: modelData.icon
                                    width: 28
                                    font.pixelSize: Theme.fontSize + 4
                                    color: Theme.accent
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Column {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2
                                    Label {
                                        text: root.displayName(modelData)
                                        font.pixelSize: Theme.fontSize + 1
                                        font.bold: true
                                        color: Theme.fg
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        width: parent.width
                                    }
                                    Label {
                                        text: root.appInstalled(modelData) ? modelData.description : modelData.description + " (Requires installation)"
                                        font.pixelSize: Theme.fontSize - 1
                                        color: Theme.fgDim
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        width: parent.width
                                    }
                                }

                                // Keybind display (shared AppKeybind widget)
                                AppKeybind {
                                    keys: modelData.keybind || []
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Install button (only when app missing)
                                AppButton {
                                    id: installBtn
                                    visible: modelData.app !== undefined && !root.appInstalled(modelData)
                                    Layout.preferredWidth: 32
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "\u{F019}" // download glyph (raw U+F019, kept as escape)
                                    tooltipText: "Install " + (modelData.package || modelData.app)
                                    onClicked: root.installApp(modelData)
                                }
                            }

                            // Reset confirmation (Yes/No buttons)
                            RowLayout {
                                visible: modelData.kind === "reset-settings" && confirming
                                spacing: 10
                                width: parent.width
                                Label {
                                    text: "Reset all settings?"
                                    color: Theme.fg
                                    font.pixelSize: Theme.fontSize
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                AppButton {
                                    text: "Yes"
                                    Layout.alignment: Qt.AlignVCenter
                                    onClicked: {
                                        confirming = false;
                                        root.doReset();
                                    }
                                }
                                AppButton {
                                    text: "No"
                                    Layout.alignment: Qt.AlignVCenter
                                    onClicked: confirming = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
