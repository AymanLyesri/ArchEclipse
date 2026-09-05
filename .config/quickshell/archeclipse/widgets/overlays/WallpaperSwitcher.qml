import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs.theme
import qs.services
import qs.widgets.shared

// WallpaperSwitcher — pick a wallpaper per workspace, or set the sddm /
// lockscreen background, browse a category, add a new wallpaper (with
// automatic thumbnail generation), or delete one.
//
// Ground-up Quickshell port of AGS/Astal's WallpaperSwitcher.tsx. Rewritten
// (not adapted) from the earlier QML draft — that draft hardcoded a home
// directory, dropped target-type switching, the per-workspace strip,
// right-click delete, "add wallpaper", and the loading/error indicator.
// All of that is restored here; see the notes below the code.
PanelWindow {
    id: root

    required property ShellScreen screen
    readonly property string monitorName: Hyprland.monitorFor(screen)?.name ?? ""

    // Bottom-anchored overlay panel, not a full-screen dimmer — matches the
    // original AGS window (LEFT|BOTTOM|RIGHT anchor, OVERLAY layer, IGNORE
    // exclusivity, ON_DEMAND keyboard focus).
    anchors { left: true; right: true; bottom: true }
    exclusiveZone: -1
    implicitHeight: 340
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "wallpaper-switcher"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Namespace matches AGS ("wallpaper-switcher") so the hypr
    // layerrule + SUPER+W togglePanel binding keep working.
    // Registry key stays per-monitor for IPC lookup.
    Component.onCompleted: {
        Registry.register(`wallpaper-switcher-${monitorName}`, root);
        fetchWallpapers();
        fetchCurrentWallpapers();
        const ws = Hyprland.focusedWorkspace;
        if (ws) root.selectedWorkspaceId = ws.id;
    }

    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: root.visible = false
    }

    readonly property string home: Quickshell.env("HOME")
    readonly property string wallpaperScript: home + "/.config/ags/scripts/get-wallpapers.sh"
    readonly property string setScript: home + "/.config/hypr/wallpaper-daemon/set-wallpaper.sh"
    readonly property string reloadScript: home + "/.config/hypr/wallpaper-daemon/reload.sh"

    function toThumbnailPath(file) {
        return file
            .replace(home + "/.config/wallpapers/", home + "/.config/ags/cache/thumbnails/")
            .replace(/\.[^/.]+$/, ".jpg");
    }

    // ---------------------------------------------------------------- state

    readonly property var targetTypes: ["workspace", "sddm", "lockscreen"]
    property string targetType: "workspace"
    property int selectedWorkspaceId: 1

    property string progressStatus: "idle" // idle | loading | success | error
    function setProgress(status) {
        progressStatus = status;
        if (status === "success" || status === "error")
            progressResetTimer.restart();
    }
    Timer {
        id: progressResetTimer
        interval: 1500
        onTriggered: root.progressStatus = "idle"
    }

    property var wallpapers: ({})               // category -> [paths]
    readonly property var categories: Object.keys(wallpapers)
    // Persisted via Settings (AGS globalSettings wallpaperSwitcher.category).
    property string selectedCategory: Settings.wallpaperCategory
    onSelectedCategoryChanged: {
        if (Settings.wallpaperCategory !== selectedCategory)
            Settings.wallpaperCategory = selectedCategory;
    }
    onCategoriesChanged: if (!categories.includes(selectedCategory))
        selectedCategory = categories.includes(Settings.wallpaperCategory)
            ? Settings.wallpaperCategory : (categories[0] ?? "")
    readonly property var selectedWallpapers: wallpapers[selectedCategory] ?? []

    property var currentWallpapers: []           // path per workspace index, this monitor

    onVisibleChanged: if (visible) {
        fetchWallpapers();
        fetchCurrentWallpapers();
    }

    // Keep the selected workspace synced to whatever's focused when the
    // switcher opens, like the AGS version's focusedWorkspace.subscribe().
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            const ws = Hyprland.focusedWorkspace;
            if (ws) root.selectedWorkspaceId = ws.id;
        }
    }

    function notifyError(context, err) {
        setProgress("error");
        console.warn("[WallpaperSwitcher]", context, err);
        Notifications.notify({ summary: "Error", body: String(err) }); // adjust to your notify service
    }

    // ---------------------------------------------------------- data fetch

    Process {
        id: fetchProc
        command: ["bash", root.wallpaperScript]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.wallpapers = JSON.parse(text);
                } catch (e) {
                    root.notifyError("fetching wallpapers", e);
                }
            }
        }
    }
    function fetchWallpapers() { fetchProc.running = true; }

    Process {
        id: fetchCurrentProc
        command: ["bash", root.wallpaperScript, "--current", root.monitorName]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.currentWallpapers = JSON.parse(text).map(String);
                } catch (e) {
                    root.notifyError("fetching current wallpapers", e);
                }
            }
        }
    }
    function fetchCurrentWallpapers() { fetchCurrentProc.running = true; }

    // ----------------------------------------------------------- set/apply

    Process {
        id: setProc
        onExited: (code) => {
            if (code === 0) {
                root.fetchCurrentWallpapers();
                // Share the global theme: regenerate pywal/cwal colors from
                // the new wallpaper (wal-theme.sh honors autocolor=false
                // itself; _pendingThemeRegen is only set when workspace
                // target + Settings.dynamicThemeColors).
                if (root._pendingThemeRegen !== "") root.regenTheme(root._pendingThemeRegen);
                else root.setProgress("success");
            } else {
                root._pendingThemeRegen = "";
                root.setProgress("error");
            }
        }
    }

    function commandFor(target, path) {
        switch (target) {
        case "sddm":
            return ["pkexec", "bash", "-c",
                `sed -i "s|^background=.*|background=${path}|" /usr/share/sddm/themes/where_is_my_sddm_theme/theme.conf`];
        case "lockscreen":
            return ["bash", "-c",
                `mkdir -p ${JSON.stringify(root.home + "/.config/wallpapers/lockscreen")} && ` +
                `cp ${JSON.stringify(path)} ${JSON.stringify(root.home + "/.config/wallpapers/lockscreen/wallpaper")}`];
        default: // workspace
            return [root.setScript, String(root.selectedWorkspaceId), root.monitorName, path];
        }
    }

    function applyWallpaper(path) {
        setProgress("loading");
        root._pendingThemeRegen = (root.targetType === "workspace" && Settings.dynamicThemeColors) ? path : "";
        setProc.command = commandFor(root.targetType, path);
        setProc.running = true;
    }

    // ---- global theme sharing (wal-theme.sh -> cwal colors.scss -> Theme) ----
    property string _pendingThemeRegen: ""
    readonly property string walThemeScript: home + "/.config/hypr/theme/scripts/wal-theme.sh"
    Process {
        id: themeProc
        onExited: (code) => {
            // Variant may have auto-switched (autovariant) — re-read it so
            // the ControlPanel toggle and GlobalTheme state stay correct.
            GlobalTheme.refresh();
            if (code === 0) root.setProgress("success");
            else root.notifyError("updating theme colors", "wal-theme.sh failed");
        }
    }
    function regenTheme(path) {
        root._pendingThemeRegen = "";
        themeProc.command = ["bash", root.walThemeScript, path];
        themeProc.running = true;
    }

    function setRandomWallpaper() {
        const list = root.selectedWallpapers;
        if (list.length === 0) return;
        applyWallpaper(list[Math.floor(Math.random() * list.length)]);
    }

    // -------------------------------------------------------------- delete

    Process {
        id: deleteProc
        onExited: (code) => {
            root.fetchWallpapers();
            if (code === 0) {
                Notifications.notify({ summary: "Success", body: "Wallpaper deleted successfully!" });
                root.setProgress("success");
            } else {
                root.setProgress("error");
            }
        }
    }
    function deleteWallpaper(path) {
        setProgress("loading");
        deleteProc.command = ["bash", "-c",
            `rm -f ${JSON.stringify(root.toThumbnailPath(path))} && rm -f ${JSON.stringify(path)}`];
        deleteProc.running = true;
    }

    // ----------------------------------------------------------- daemon reload

    Process {
        id: reloadProc
        onExited: (code) => {
            if (code === 0) root.fetchWallpapers();
            root.setProgress(code === 0 ? "success" : "error");
        }
    }
    function reloadDaemon() {
        setProgress("loading");
        reloadProc.command = ["bash", "-c", root.reloadScript];
        reloadProc.running = true;
    }

    // --------------------------------------------------------- add wallpaper

    Process {
        id: pickProc
        command: ["zenity", "--file-selection", "--title=Select Wallpaper",
            "--file-filter=Images (png, jpg, webp, gif, mp4) | *.png *.jpg *.jpeg *.webp *.gif *.mp4"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path.length > 0) root.importWallpaper(path);
                else root.progressStatus = "idle";
            }
        }
        onExited: (code) => {
            // zenity exits 1 on Cancel — that's not a real error.
            if (code !== 0 && code !== 1) root.setProgress("error");
        }
    }
    function pickWallpaper() { pickProc.running = true; }

    Process {
        id: importProc
        onExited: (code) => {
            if (code === 0) {
                Notifications.notify({ summary: "Success", body: "Wallpaper added successfully!" });
                root.fetchWallpapers();
                root.setProgress("success");
            } else {
                root.notifyError("adding wallpaper", "copy/thumbnail step failed");
            }
        }
    }
    function importWallpaper(sourcePath) {
        setProgress("loading");
        const targetDir = root.home + "/.config/wallpapers/custom";
        const basename = sourcePath.split("/").pop();
        const targetPath = targetDir + "/" + basename;
        const thumbDir = root.home + "/.config/ags/cache/thumbnails/custom";
        const thumbPath = thumbDir + "/" + basename.replace(/\.[^/.]+$/, ".jpg");
        const isVideo = /\.(mp4|webm)$/i.test(sourcePath);
        const thumbCmd = isVideo
            ? `ffmpeg -i ${JSON.stringify(targetPath)} -vframes 1 -vf "scale=500:-1" -y ${JSON.stringify(thumbPath)}`
            : `magick ${JSON.stringify(targetPath)} -resize "500x500^" -gravity center -extent 500x500 ${JSON.stringify(thumbPath)}`;

        importProc.command = ["bash", "-c",
            `mkdir -p ${JSON.stringify(targetDir)} ${JSON.stringify(thumbDir)} && ` +
            `cp -- ${JSON.stringify(sourcePath)} ${JSON.stringify(targetPath)} && ` +
            thumbCmd];
        importProc.running = true;
    }

    // cached file sizes for tooltip (path -> bytes), one stat per path.
    // Path passed as argv (no shell quoting) so names with quotes still work.
    property var fileSizes: ({})
    function getFileSize(path) {
        if (root.fileSizes[path] !== undefined) return root.fileSizes[path]
        const p = Qt.createQmlObject('import Quickshell.Io; Process { stdout: StdioCollector {} }', root)
        p.command = ["stat", "-c", "%s", path]
        p.running = true
        p.stdout.onStreamFinished.connect(function() {
            const sz = parseInt(p.stdout.text.trim()) || 0
            const fs = root.fileSizes
            fs[path] = sz
            root.fileSizes = fs
            p.destroy()
        })
        return 0
    }
    function formatBytes(bytes) {
        if (bytes === 0) return "N/A"
        const units = ["B", "KB", "MB", "GB"]
        let i = 0
        let b = bytes
        while (b >= 1024 && i < units.length - 1) { b /= 1024; i++ }
        return b.toFixed(i === 0 ? 0 : 1) + " " + units[i]
    }

    // ------------------------------------------------------------------ UI

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        radius: Theme.radius

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // per-workspace current wallpaper strip
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                Repeater {
                    model: root.currentWallpapers
                    delegate: Rectangle {
                        id: wsTile
                        required property string modelData
                        required property int index
                        readonly property bool isFocused: Hyprland.focusedWorkspace?.id === index + 1

                        width: 140; height: 90
                        radius: 6
                        color: modelData === "" ? "black" : "transparent"
                        border.width: isFocused ? 2 : 0
                        border.color: Theme.accent ?? Theme.foreground

                        Image {
                            visible: wsTile.modelData !== ""
                            anchors.fill: parent
                            anchors.margins: 2
                            source: wsTile.modelData === "" ? "" : "file://" + root.toThumbnailPath(wsTile.modelData)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Text {
                            visible: wsTile.modelData === ""
                            anchors.centerIn: parent
                            text: "No Wallpaper"
                            color: Theme.foregroundSecondary
                            font.family: Theme.fontFamily
                        }
                        ToolTip.visible: wsMa.containsMouse
                        ToolTip.text: `Set wallpaper for Workspace ${index + 1}`
                        MouseArea {
                            id: wsMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.targetType = "workspace";
                                root.selectedWorkspaceId = index + 1;
                            }
                        }
                    }
                }
            }

            // action bar
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                Row {
                    spacing: 2
                    Repeater {
                        model: root.targetTypes
                        delegate: AppButton {
                            required property string modelData
                            text: modelData
                            toggle: true
                            checked: root.targetType === modelData
                            onClicked: root.targetType = modelData
                        }
                    }
                }

                Text {
                    text: `Wallpaper -> ${root.targetType}` +
                        (root.targetType === "workspace" ? " " + root.selectedWorkspaceId : "")
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                }

                // pywal palette swatches (AGS displayColorScheme: color1..7)
                Row {
                    spacing: 6
                    Repeater {
                        model: [Theme.color0, Theme.color1, Theme.color2, Theme.color3, Theme.color4, Theme.color8, Theme.foreground]
                        delegate: Rectangle {
                            required property string modelData
                            width: 12; height: 12; radius: 6
                            color: modelData
                        }
                    }
                }

                ComboBox {
                    model: root.categories
                    currentIndex: root.categories.indexOf(root.selectedCategory)
                    onActivated: root.selectedCategory = root.categories[currentIndex]
                }

                AppButton { text: "Random"; onClicked: root.setRandomWallpaper() }
                AppButton { text: "Reload"; onClicked: root.reloadDaemon() }
                AppButton { text: "Add…"; onClicked: root.pickWallpaper() }

                BusyIndicator {
                    running: root.progressStatus === "loading"
                    visible: running
                    implicitWidth: 20; implicitHeight: 20
                }
                Text { visible: root.progressStatus === "error"; text: "⚠"; color: "red" }
                Text { visible: root.progressStatus === "success"; text: "✓"; color: "lightgreen" }
            }

            // all wallpapers in the selected category — horizontal strip
            ScrollView {
                id: wallScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                clip: true

                Row {
                    spacing: 6
                    width: wallScroll.width
                    height: Math.max(0, wallScroll.height)
                    Repeater {
                        model: root.selectedWallpapers
                        delegate: Rectangle {
                            id: tile
                            required property string modelData
                            width: 150; height: Math.max(0, wallScroll.height - 4)
                            radius: 6
                            color: tileMa.containsMouse ? Theme.buttonHoverBg : Theme.moduleBg
                            border.width: tileMa.containsMouse ? 2 : 0
                            border.color: Theme.foregroundSecondary

                            Image {
                                anchors.fill: parent
                                anchors.margins: 3
                                source: "file://" + root.toThumbnailPath(tile.modelData)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            ToolTip.visible: tileMa.containsMouse
                            ToolTip.text: `Click to set as ${root.targetType} wallpaper.\nRight-click to delete.\n${tile.modelData.split("/").pop()}\nSize: ${root.formatBytes(root.getFileSize(tile.modelData))}`

                            MouseArea {
                                id: tileMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton)
                                        root.deleteWallpaper(tile.modelData);
                                    else
                                        root.applyWallpaper(tile.modelData);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
