import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.theme
import qs.services
import qs.widgets.shared

// WallpaperPanelBody — pick a wallpaper per workspace, or set the sddm
// background, browse a category, add a new wallpaper, or delete one.
//
// Lives in its own widgets/wallpaperPanel folder (same pattern as
// widgets/controlPanel/ControlPanelBody) and is hosted by WallpaperIsland
// in the main bar pill. Hosts size this Item (implicit 960x360) and call
// refresh() when it becomes visible.
//
// Previews render the original files directly via AppImage (Qt Quick
// Image, asynchronous + sourceSize-constrained) — no thumbnail files.
Item {
    id: root

    // Island owner passes the bar's monitor; falls back to focused.
    property string monitorName: ""
    readonly property string effectiveMonitor: root.monitorName || Registry.monitorName

    implicitWidth: 960
    implicitHeight: 360

    readonly property string home: Quickshell.env("HOME")
    readonly property string wallpaperScript: home + "/.config/quickshell/archeclipse/scripts/get-wallpapers.sh"
    readonly property string setScript: home + "/.config/hypr/wallpaper-daemon/set-wallpaper.sh"
    readonly property string reloadScript: home + "/.config/hypr/wallpaper-daemon/reload.sh"

    function isVideoFile(file) {
        return /\.(mp4|webm|mkv|mov)$/i.test(file);
    }

    // ---------------------------------------------------------------- state

    readonly property var targetTypes: ["workspace", "sddm"]
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
    // Single source of truth: Settings.wallpaperCategory. This binding is NEVER
    // assigned locally, so it can't desync like a mirrored var: every
    // writer goes through Settings.updateSetting (immediate persist) and
    // every reader — grid, combobox — follows the binding.
    readonly property string selectedCategory: Settings.wallpaperCategory
    // Self-heal a saved category that no longer exists (dir deleted).
    // Gated on ready + non-empty categories so a fast fetch can't clobber
    // the saved value before Settings.reload() has adopted the file.
    function validateCategory() {
        if (!Settings.ready || root.categories.length === 0)
            return;
        if (!root.categories.includes(Settings.wallpaperCategory))
            Settings.updateSetting("wallpaperSwitcher.category", root.categories[0]);
    }
    // ComboBox sets currentIndex internally on user pick and resets it
    // to 0 on model replacement, which breaks/clobbers any currentIndex
    // binding — re-sync imperatively, deferred past the ComboBox's own
    // model-reset handling (it runs after our change handlers).
    function syncCategoryCombo() {
        Qt.callLater(() => {
            const i = root.categories.indexOf(root.selectedCategory);
            if (categoryCombo.currentIndex !== i)
                categoryCombo.currentIndex = i;
        });
    }
    Connections {
        target: Settings
        function onWallpaperCategoryChanged() {
            root.validateCategory();
            root.syncCategoryCombo();
        }
    }
    onCategoriesChanged: {
        root.validateCategory();
        root.syncCategoryCombo();
    }
    readonly property var selectedWallpapers: wallpapers[selectedCategory] ?? []
    // Exposed for Ipc wallpaperDiag ("strip" query) and tests.
    readonly property alias wallStrip: wallScroll

    property var currentWallpapers: []           // path per workspace index, this monitor

    Component.onCompleted: {
        fetchWallpapers();
        fetchCurrentWallpapers();
        const ws = Hyprland.focusedWorkspace;
        if (ws)
            root.selectedWorkspaceId = ws.id;
    }

    // Hosts call this when the body becomes visible.
    function refresh() {
        fetchWallpapers();
        fetchCurrentWallpapers();
    }

    // Re-fetch when the bar delivers the real monitor name (onLoaded
    // fires after our Component.onCompleted, so the first fetch may have
    // used the Registry fallback which can resolve to the wrong monitor).
    onMonitorNameChanged: {
        if (root.monitorName !== "")
            fetchCurrentWallpapers();
    }

    // Keep the selected workspace synced to whatever's focused when the
    // switcher opens.
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            const ws = Hyprland.focusedWorkspace;
            if (ws)
                root.selectedWorkspaceId = ws.id;
        }
    }

    function notifyError(context, err) {
        setProgress("error");
        console.warn("[WallpaperSwitcher]", context, err);
        Notifications.notify({
            summary: "Error",
            body: String(err)
        }); // adjust to your notify service
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
    function fetchWallpapers() {
        fetchProc.running = true;
    }

    Process {
        id: fetchCurrentProc
        command: ["bash", root.wallpaperScript, "--current", root.effectiveMonitor]
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
    function fetchCurrentWallpapers() {
        fetchCurrentProc.running = true;
    }

    // ----------------------------------------------------------- set/apply

    Process {
        id: setProc
        onExited: code => {
            if (code === 0) {
                root.fetchCurrentWallpapers();
                // Share the global theme: regenerate pywal/cwal colors from
                // the new wallpaper (wal-theme.sh honors autocolor=false
                // itself; _pendingThemeRegen is only set when workspace
                // target + Settings.dynamicThemeColors).
                if (root._pendingThemeRegen !== "")
                    root.regenTheme(root._pendingThemeRegen);
                else
                    root.setProgress("success");
            } else {
                root._pendingThemeRegen = "";
                root.setProgress("error");
            }
        }
    }

    function commandFor(target, path) {
        switch (target) {
        case "sddm":
            return ["pkexec", "bash", "-c", `sed -i "s|^background=.*|background=${path}|" /usr/share/sddm/themes/where_is_my_sddm_theme/theme.conf`];
        default:
            // workspace
            return [root.setScript, String(root.selectedWorkspaceId), root.effectiveMonitor, path];
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
        onExited: code => {
            // Variant may have auto-switched (autovariant) — re-read it so
            // the ControlPanel toggle and GlobalTheme state stay correct.
            GlobalTheme.refresh();
            if (code === 0)
                root.setProgress("success");
            else
                root.notifyError("updating theme colors", "wal-theme.sh failed");
        }
    }
    function regenTheme(path) {
        root._pendingThemeRegen = "";
        themeProc.command = ["bash", root.walThemeScript, path];
        themeProc.running = true;
    }

    function setRandomWallpaper() {
        const list = root.selectedWallpapers;
        if (list.length === 0)
            return;
        applyWallpaper(list[Math.floor(Math.random() * list.length)]);
    }

    // -------------------------------------------------------------- delete

    Process {
        id: deleteProc
        onExited: code => {
            root.fetchWallpapers();
            if (code === 0) {
                Notifications.notify({
                    summary: "Success",
                    body: "Wallpaper deleted successfully!"
                });
                root.setProgress("success");
            } else {
                root.setProgress("error");
            }
        }
    }
    function deleteWallpaper(path) {
        setProgress("loading");
        deleteProc.command = ["bash", "-c", `rm -f ${JSON.stringify(path)}`];
        deleteProc.running = true;
    }

    // ----------------------------------------------------------- daemon reload

    Process {
        id: reloadProc
        onExited: code => {
            if (code === 0)
                root.fetchWallpapers();
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
        command: ["zenity", "--file-selection", "--title=Select Wallpaper", "--file-filter=Images (png, jpg, webp, gif, mp4) | *.png *.jpg *.jpeg *.webp *.gif *.mp4"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path.length > 0)
                    root.importWallpaper(path);
                else
                    root.progressStatus = "idle";
            }
        }
        onExited: code => {
            // zenity exits 1 on Cancel — that's not a real error.
            if (code !== 0 && code !== 1)
                root.setProgress("error");
        }
    }
    function pickWallpaper() {
        pickProc.running = true;
    }

    Process {
        id: importProc
        onExited: code => {
            if (code === 0) {
                Notifications.notify({
                    summary: "Success",
                    body: "Wallpaper added successfully!"
                });
                root.fetchWallpapers();
                root.setProgress("success");
            } else {
                root.notifyError("adding wallpaper", "copy step failed");
            }
        }
    }
    function importWallpaper(sourcePath) {
        setProgress("loading");
        const targetDir = root.home + "/.config/wallpapers/custom";
        const basename = sourcePath.split("/").pop();
        const targetPath = targetDir + "/" + basename;

        importProc.command = ["bash", "-c", `mkdir -p ${JSON.stringify(targetDir)} && ` + `cp -- ${JSON.stringify(sourcePath)} ${JSON.stringify(targetPath)}`];
        importProc.running = true;
    }

    // cached file sizes for tooltip (path -> bytes), one stat per path.
    // Path passed as argv (no shell quoting) so names with quotes still work.
    property var fileSizes: ({})
    function getFileSize(path) {
        if (root.fileSizes[path] !== undefined)
            return root.fileSizes[path];
        const p = Qt.createQmlObject('import Quickshell.Io; Process { stdout: StdioCollector {} }', root);
        p.command = ["stat", "-c", "%s", path];
        p.running = true;
        p.stdout.onStreamFinished.connect(function () {
            const sz = parseInt(p.stdout.text.trim()) || 0;
            const fs = root.fileSizes;
            fs[path] = sz;
            root.fileSizes = fs;
            p.destroy();
        });
        return 0;
    }
    function formatBytes(bytes) {
        if (bytes === 0)
            return "N/A";
        const units = ["B", "KB", "MB", "GB"];
        let i = 0;
        let b = bytes;
        while (b >= 1024 && i < units.length - 1) {
            b /= 1024;
            i++;
        }
        return b.toFixed(i === 0 ? 0 : 1) + " " + units[i];
    }

    // ------------------------------------------------------------------ UI

    Rectangle {
        id: wallpaperSwitcher
        anchors.fill: parent
        color: "transparent"
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

                        width: 100
                        height: 66
                        radius: 6
                        color: modelData === "" ? "black" : "transparent"
                        border.width: isFocused ? 1 : 0
                        border.color: Theme.muted

                        AppImage {
                            visible: wsTile.modelData !== ""
                            anchors.fill: parent
                            anchors.margins: 2
                            // Native preview: original file, decoded near
                            // tile size (async + cached inside AppImage).
                            // Videos play live below (wsVideo) — empty
                            // source here keeps just the badges.
                            source: (wsTile.modelData === "" || root.isVideoFile(wsTile.modelData)) ? "" : "file://" + wsTile.modelData
                            sourceWidth: wsTile.width
                            badges: [(wsTile.index + 1).toString()]
                        }
                        // Live animated preview for workspace videos
                        // (main-strip parity): the icon below stays until
                        // the first frame lands, or permanently on decode
                        // failure.
                        AppVideo {
                            id: wsVideo
                            anchors.fill: parent
                            anchors.margins: 2
                            visible: wsTile.modelData !== "" && root.isVideoFile(wsTile.modelData)
                            source: visible ? wsTile.modelData : ""
                            active: visible
                            muted: true
                            fillMode: VideoOutput.PreserveAspectCrop
                            badges: [(wsTile.index + 1).toString()]
                            onErrorOccurred: message => {
                                console.warn("[WallpaperSwitcher] video preview failed for " + wsTile.modelData + ": " + message);
                            }
                        }
                        Text {
                            visible: wsTile.modelData !== "" && root.isVideoFile(wsTile.modelData) && (!wsVideo.ready || wsVideo._failed)
                            anchors.centerIn: parent
                            text: ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 20
                            color: Theme.fgDim
                        }
                        Text {
                            visible: wsTile.modelData === ""
                            anchors.centerIn: parent
                            text: "No Wallpaper"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                        }
                        AppTooltip {
                            visible: wsMa.containsMouse
                            text: `Set wallpaper for Workspace ${index + 1}`
                        }
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

            // action bar — wrapped so radius / bg / border apply as one pill
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: actionBar.implicitWidth + 24
                implicitHeight: actionBar.implicitHeight + 16
                radius: Theme.radius
                color: Theme.surface

                clip: true

                RowLayout {
                    id: actionBar
                    anchors.centerIn: parent
                    spacing: 10

                    AppSegmentedControl {
                        model: root.targetTypes
                        currentIndex: root.targetTypes.indexOf(root.targetType)
                        onActivated: (i, v) => root.targetType = v
                    }

                    Text {
                        text: `Wallpaper -> ${root.targetType}` + (root.targetType === "workspace" ? " " + root.selectedWorkspaceId : "")
                        color: Theme.fg
                        font.family: Theme.fontFamily
                    }

                    // pywal palette swatches (color1..7)
                    Row {
                        spacing: 6
                        Repeater {
                            model: [Theme.color0, Theme.color1, Theme.color2, Theme.color3, Theme.color4, Theme.color8, Theme.fg]
                            delegate: Rectangle {
                                required property string modelData
                                width: 12
                                height: 12
                                radius: 6
                                color: modelData
                            }
                        }
                    }

                    AppComboBox {
                        id: categoryCombo
                        objectName: "categoryCombo"
                        model: root.categories
                        currentIndex: root.categories.indexOf(root.selectedCategory)
                        onActivated: i => Settings.updateSetting("wallpaperSwitcher.category", root.categories[i])
                    }

                    AppButton {
                        text: "Random"
                        onClicked: root.setRandomWallpaper()
                    }
                    AppButton {
                        text: "Reload"
                        onClicked: root.reloadDaemon()
                    }
                    AppButton {
                        text: "Add…"
                        onClicked: root.pickWallpaper()
                    }

                    AppProgress {
                        // Plain Row ignores implicitHeight — fix the size.
                        width: 20
                        height: 20
                        status: root.progressStatus
                        variant: "spinner"
                        showSuccess: true
                    }
                }
            }

            // all wallpapers in the selected category — horizontal strip
            SmoothFlickable {
                id: wallScroll
                objectName: "wallStrip"
                Layout.fillWidth: true
                Layout.fillHeight: true
                flickableDirection: Flickable.HorizontalFlick
                contentWidth: wallRow.width
                contentHeight: height
                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                Row {
                    id: wallRow
                    spacing: 6
                    height: wallScroll.height
                    Repeater {
                        model: root.selectedWallpapers
                        delegate: Rectangle {
                            id: tile
                            required property string modelData
                            required property int index
                            // Staggered fade pop-in: each tile's turn
                            // arrives with its position, and it only fades
                            // in once the preview settled — image decoded
                            // (Error counts as settled so a missing file
                            // can't hide a tile forever) or video ready
                            // (first frame or decode failure, which falls
                            // back to the icon below).
                            property bool revealed: false
                            readonly property bool thumbSettled: root.isVideoFile(tile.modelData) ? tileVideo.ready : (tileImg.status === Image.Ready || tileImg.status === Image.Error)
                            // Viewport gate for live video previews: the
                            // strip is a Repeater (no virtualization), so
                            // only tiles near the visible window may hold
                            // a decoder. Buffer preloads just off-screen.
                            readonly property bool inView: tile.x + tile.width > wallScroll.contentX - 320 && tile.x < wallScroll.contentX + wallScroll.width + 320
                            // Workspace number badges: which workspace(s)
                            // currently use this wallpaper (top-right).
                            // Shared by the still preview and the live
                            // video below (only one is visible at a time).
                            readonly property var badgeIds: {
                                const ids = [];
                                const cur = root.currentWallpapers;
                                for (let i = 0; i < cur.length; i++) {
                                    if (cur[i] !== "" && cur[i] === tile.modelData)
                                        ids.push(String(i + 1));
                                }
                                return ids;
                            }
                            opacity: (revealed && thumbSettled) ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Timer {
                                interval: Math.min(index, 24) * 35
                                repeat: false
                                running: true
                                onTriggered: tile.revealed = true
                            }
                            // Hovered tile widens to its preview aspect ratio
                            // relative to the current height (never shrinks
                            // below base, capped so panoramas stay sane).
                            // Images use the decoded size; videos use the
                            // native resolution from metadata.
                            readonly property real imgRatio: (tileImg.implicitImageWidth > 0 && tileImg.implicitImageHeight > 0) ? tileImg.implicitImageWidth / tileImg.implicitImageHeight : 0
                            readonly property real hoverRatio: tile.imgRatio > 0 ? tile.imgRatio : tileVideo.videoRatio
                            width: tileMa.containsMouse && tile.hoverRatio > 0 ? Math.min(Math.max(tile.height * tile.hoverRatio, 150), 480) : 150
                            Behavior on width {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }
                            }
                            height: Math.max(0, wallScroll.height - 4)
                            radius: 6
                            z: tileMa.containsMouse ? 1 : 0
                            color: tileMa.containsMouse ? Theme.surfaceHover : Theme.surface
                            border.width: tileMa.containsMouse ? 2 : 0
                            border.color: Theme.muted

                            AppImage {
                                id: tileImg
                                anchors.fill: parent
                                anchors.margins: 3
                                // Native preview: original file decoded near
                                // tile size (asynchronous + cached; the
                                // strip's virtualized Repeater keeps the
                                // instance count bounded while scrolling).
                                // Videos can't render in an Image — empty
                                // source keeps the badges, the icon below
                                // marks the tile as video.
                                source: root.isVideoFile(tile.modelData) ? "" : "file://" + tile.modelData
                                // Two-step decode size (base vs hover-wide):
                                // tracks the displayed width without
                                // re-decoding on every animation frame.
                                sourceWidth: tileMa.containsMouse ? 480 : 150
                                badges: tile.badgeIds
                            }
                            // Live video preview (MP4/WebM): shared AppVideo,
                            // muted + looping, cropped like the static tiles.
                            // `active` unloads the decoder off-screen (see
                            // tile.inView); AppImage above stays empty for
                            // videos while this carries the same badges.
                            AppVideo {
                                id: tileVideo
                                anchors.fill: parent
                                anchors.margins: 3
                                visible: root.isVideoFile(tile.modelData)
                                source: tile.modelData
                                active: tileVideo.visible && tile.inView
                                muted: true
                                fillMode: VideoOutput.PreserveAspectCrop
                                badges: tile.badgeIds
                                onErrorOccurred: message => {
                                    console.warn("[WallpaperSwitcher] video preview failed for " + tile.modelData + ": " + message);
                                }
                            }
                            Column {
                                // Loading/error fallback for videos: shown
                                // until the first frame lands (tile fades in
                                // on ready) or permanently on decode failure
                                // (ready includes failed, so test it too —
                                // otherwise a bad file hides the icon and
                                // the tile goes blank).
                                visible: root.isVideoFile(tile.modelData) && (!tileVideo.ready || tileVideo._failed)
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 24
                                    color: Theme.fgDim
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: tile.modelData.split("/").pop()
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 2
                                    color: Theme.fgDim
                                    elide: Text.ElideMiddle
                                    width: Math.max(0, tile.width - 16)
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            // Hidden while the strip moves: a visible tooltip
                            // window sits under the cursor and swallows wheel
                            // events, which kills the momentum glide.
                            AppTooltip {
                                visible: tileMa.containsMouse && !wallScroll.moving
                                delay: 400
                                text: `Click to set as ${root.targetType} wallpaper.\nRight-click to delete.\n${tile.modelData.split("/").pop()}\nSize: ${root.formatBytes(root.getFileSize(tile.modelData))}`
                            }

                            MouseArea {
                                id: tileMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                // Tiles cover the strip: let wheel fall through
                                // to the strip's SmoothWheelHandler so the
                                // horizontal momentum glide actually receives it.
                                onWheel: wheel => wheel.accepted = false
                                onClicked: mouse => {
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
