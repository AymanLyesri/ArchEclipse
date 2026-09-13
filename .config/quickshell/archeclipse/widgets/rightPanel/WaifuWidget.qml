import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import Quickshell.Io
import qs.theme
import qs.widgets.shared
import qs.services
import qs.widgets.leftPanel

// Waifu widget ported from widgets/rightPanel/components/Waifu.tsx
// Shows the current waifu image or a placeholder with a link to open
// the BooruViewer in the left panel.
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    readonly property string booruPath: `${Quickshell.env("HOME")}/.cache/quickshell/booru`
    readonly property string booruScript: `${Quickshell.env("HOME")}/.config/quickshell/archeclipse/scripts/booru.py`

    // Current waifu data from Settings — mirrors globalSettings.waifuWidget.current
    readonly property var waifuDataObj: Settings.waifu || null

    // Safe accessors (return null/empty when no waifu)
    readonly property var wd: root.waifuDataObj
    readonly property int wd_id: root.wd ? (root.wd.id || 0) : 0
    readonly property string wd_apiValue: root.wd && root.wd.api ? root.wd.api.value : "danbooru"
    readonly property string wd_extension: root.wd ? (root.wd.extension || "") : ""
    readonly property var wd_tags: root.wd ? (root.wd.tags || []) : []
    readonly property int wd_width: root.wd ? (root.wd.width || 0) : 0
    readonly property int wd_height: root.wd ? (root.wd.height || 0) : 0

    // The widget shows for any truthy id (custom uploads use id -1) —
    // only a missing/empty id means "no image selected".
    readonly property bool hasWaifu: !!(root.wd && root.wd.id)
    readonly property string imagePath: root.hasWaifu ? `${root.booruPath}/${root.wd_apiValue}/images/${root.wd_id}.${root.wd_extension || "jpg"}` : ""
    readonly property string previewPath: root.hasWaifu ? `${root.booruPath}/${root.wd_apiValue}/previews/${root.wd_id}.${root.wd_extension || "jpg"}` : ""
    readonly property bool isVideo: ["mp4", "webm", "mkv", "gif", "zip"].includes(root.wd_extension.toLowerCase())

    // Dynamic height from aspect ratio: metadata first, loaded image intrinsic as fallback
    readonly property real aspectRatio: {
        if (root.wd_width > 0 && root.wd_height > 0)
            return root.wd_width / root.wd_height;
        if (imageDisplay.implicitImageWidth > 0 && imageDisplay.implicitImageHeight > 0)
            return imageDisplay.implicitImageWidth / imageDisplay.implicitImageHeight;
        return 1.0;
    }
    readonly property real mediaHeight: {
        if (!root.hasWaifu)
            return 0;
        // No outside container: image fills the widget edge-to-edge.
        var w = root.widgetWidth;
        if (w <= 0)
            w = root.widgetWidth;
        var h = w / root.aspectRatio;
        return Math.min(Math.max(h, 120), 520);
    }

    // Loading state for fetch-by-ID and ensure-download below.
    property string loadingState: "idle"   // "loading" | "error" | "success" | "idle"
    property int selectedApiIndex: 0

    // ensureFilesExist("both"): a viewer-set waifu whose full
    // image / preview was never downloaded renders blank, so fetch what's
    // missing (Referer headers: Qt gets 403 without them, same as the
    // viewer's downloadPreviews/fetchOriginal). Files already on disk skip
    // the download and just re-point the sources.
    function ensureWaifuFiles() {
        refreshSources();
        if (!root.hasWaifu)
            return;
        const wd = root.wd;
        const api = (wd.api && wd.api.value) || "danbooru";
        const referer = (wd.api && wd.api.url) || "";
        const ext = wd.extension || "jpg";
        const jobs = [];
        if (wd.url && /^https?:\/\//.test(wd.url))
            jobs.push({
                path: `${root.booruPath}/${api}/images/${wd.id}.${ext}`,
                url: wd.url
            });
        if (wd.preview && /^https?:\/\//.test(wd.preview))
            jobs.push({
                path: `${root.booruPath}/${api}/previews/${wd.id}.${ext}`,
                url: wd.preview
            });
        if (jobs.length === 0)
            return;
        root.loadingState = "loading";
        let pending = jobs.length;
        let ok = false;
        function finish(success) {
            if (success)
                ok = true;
            if (--pending === 0) {
                root.loadingState = ok ? "success" : "error";
                refreshSources();
            }
        }
        for (let i = 0; i < jobs.length; i++) {
            const job = jobs[i];
            const check = Qt.createQmlObject('import Quickshell.Io; Process { stdout: StdioCollector {} }', root);
            check.command = ["bash", "-c", "test -s " + JSON.stringify(job.path) + " && echo yes || echo no"];
            check.stdout.onStreamFinished.connect(function () {
                if (check.stdout.text.trim() === "yes") {
                    finish(true);
                } else {
                    const dl = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
                    dl.command = ["bash", "-c", `mkdir -p ${JSON.stringify(job.path.substring(0, job.path.lastIndexOf("/")))} && curl -sSfL -H "User-Agent: QuickshellBooru/1.0 (ArchLinux; Hyprland)"` + (referer !== "" ? ` -H "Referer: ${referer}"` : "") + ` -o ${JSON.stringify(job.path)} ${JSON.stringify(job.url)}`];
                    dl.exited.connect(function (code) {
                        finish(code === 0);
                        dl.destroy();
                    });
                    dl.running = true;
                }
                check.destroy();
            });
            check.running = true;
        }
    }

    // Local cache paths for a waifu object. Computed from root.wd directly:
    // sibling derived bindings (imagePath/previewPath) are still settling
    // while onWdChanged/onImagePathChanged handlers run, so reading them
    // here yields stale intermediate values.
    function waifuPaths() {
        const wd = root.wd;
        if (!(wd && wd.id))
            return {
                img: "",
                prev: ""
            };
        const api = (wd.api && wd.api.value) || "danbooru";
        const ext = wd.extension || "jpg";
        return {
            img: `${root.booruPath}/${api}/images/${wd.id}.${ext}`,
            prev: `${root.booruPath}/${api}/previews/${wd.id}.${ext}`
        };
    }

    // (Re)point the media sources at the current waifu. Bounces through ""
    // so a file that landed after a failed load retries instead of staying
    // blank — QML media never reloads on its own.
    function refreshSources() {
        const p = root.waifuPaths();
        imageDisplay.fallbackSource = p.prev;
        if (imageDisplay.source !== p.img) {
            imageDisplay.source = p.img;
        } else if (p.img !== "") {
            imageDisplay.source = "";
            imageDisplay.source = p.img;
        }
        if (mediaVideo.source !== p.img) {
            mediaVideo.source = p.img;
        } else if (p.img !== "") {
            mediaVideo.source = "";
            mediaVideo.source = p.img;
        }
    }

    onWdChanged: {
        // Skip the construction-time evaluation: the media items below
        // don't exist yet (Component.onCompleted runs the first ensure).
        if (!root._ready)
            return;
        root.loadingState = "idle";
        root.ensureWaifuFiles();
    }

    // Refresh off the path notification too: bindings into the media items
    // below don't reliably propagate these updates on their own.
    onImagePathChanged: refreshSources()
    property bool _ready: false
    Component.onCompleted: {
        root._ready = true;
        root.ensureWaifuFiles();
    }

    readonly property var booruApis: [
        {
            name: "Danbooru",
            value: "danbooru",
            url: "https://danbooru.donmai.us/",
            idSearchUrl: "https://danbooru.donmai.us/posts/"
        },
        {
            name: "Gelbooru",
            value: "gelbooru",
            url: "https://gelbooru.com/",
            idSearchUrl: "https://gelbooru.com/index.php?page=post&s=view&id="
        },
        {
            name: "Safebooru",
            value: "safebooru",
            url: "https://safebooru.donmai.us/",
            idSearchUrl: "https://safebooru.donmai.us/posts/"
        },
    ]

    // Upload pipeline state (set by pickProc → identifyProc → copyProc below).
    property string _uploadSrc: ""
    property string _uploadExt: "png"
    property int _uploadW: 0
    property int _uploadH: 0

    // Declarative zenity picker (WallpaperPanelBody pickProc parity):
    // collectors are attached in the constructor, never assigned after
    // running=true, and paths travel as argv — never interpolated into a
    // QML string or shell quote (the old Qt.createQmlObject flow raced
    // stdout attachment and broke on paths with quotes/spaces).
    Process {
        id: pickProc
        command: ["zenity", "--file-selection", "--title=Select Image", "--file-filter=Images (png, jpg, webp, gif) | *.png *.jpg *.jpeg *.webp *.gif"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path === "")
                    return;
                root._uploadSrc = path;
                const ext = (path.split("/").pop().split(".").pop() || "png").toLowerCase();
                root._uploadExt = ext;
                identifyProc.command = ["identify", "-format", "%w %h", path];
                identifyProc.running = true;
            }
        }
        onExited: code => {
            // zenity exits 1 on Cancel — not an error; empty stdout means
            // nothing was picked (handled above by the empty-path return).
            if (code !== 0 && code !== 1)
                Notifications.notify({ summary: "Waifu", body: "Image picker failed" });
        }
    }

    // Image dimensions via ImageMagick (argv path — no shell quoting).
    // Parsed once on exit (single path: stdout may be empty on failure,
    // and handling both onStreamFinished + onExited would copy twice).
    Process {
        id: identifyProc
        stdout: StdioCollector {}
        onExited: code => {
            if (code === 0) {
                const dims = stdout.text.trim().split(/\s+/).map(Number);
                root._uploadW = dims[0] || 0;
                root._uploadH = dims[1] || 0;
            } else {
                // identify missing/failed: still install the file with
                // unknown dims (aspect falls back to the loaded image).
                root._uploadW = 0;
                root._uploadH = 0;
            }
            const dir = `${root.booruPath}/custom/images`;
            const dest = `${dir}/-1.${root._uploadExt}`;
            // $1=dest dir, $2=source, $3=dest: argv, so paths with
            // quotes/spaces survive; drop stale -1.* siblings from a
            // previous upload with a different extension.
            copyProc.command = ["bash", "-c", 'mkdir -p "$1" && rm -f "$1"/-1.* && cp -- "$2" "$3"', "--", dir, root._uploadSrc, dest];
            copyProc.running = true;
        }
    }

    // mkdir + copy of the picked file into the custom cache dir.
    Process {
        id: copyProc
        onExited: code => {
            if (code !== 0) {
                Notifications.notify({ summary: "Waifu", body: "Could not install custom image" });
                return;
            }
            const dest = `${root.booruPath}/custom/images/-1.${root._uploadExt}`;
            const newWaifu = {
                id: -1,
                width: root._uploadW,
                height: root._uploadH,
                api: {
                    name: "Custom",
                    value: "custom"
                },
                extension: root._uploadExt,
                tags: ["custom"],
                url: dest,
                preview: dest
            };
            Settings.waifu = newWaifu;
            Settings.persist();
            Notifications.notify({
                summary: "Waifu",
                body: "Custom image set"
            });
        }
    }

    // Upload a custom local image as the current waifu (zenity
    // zenity file-selection → identify dims → copy to custom/images/-1.<ext>).
    function uploadCustomImage() {
        pickProc.running = true;
    }

    // Open the current waifu as a floating Booru dialog window (same
    // card as the BooruViewer detail, detached). Prefers the shared
    // island viewer (warm caches); the island itself never opens. When
    // the island was never instantiated (left panel untouched), falls
    // back to our own hidden dialog host below — never the external
    // viewer.
    function openAsDialog() {
        const wd = root.wd;
        if (!wd || !wd.id)
            return;
        const isl = Registry.get(`left-island-${Registry.monitorName}`) || Registry.get("left-island");
        if (isl && typeof isl.openBooruDialog === "function" && isl.openBooruDialog(wd))
            return;
        root.openAsHostedDialog(wd);
    }

    // Cold-start dialog host: a dialogOnly BooruViewer (no grid boot
    // fetch) instantiated on first use and kept alive. Its FloatingWindow
    // is top-level and independent of the island; previews warm from the
    // disk cache so the dialog shows a still while the full file lands.
    property var _pendingHostedImage: null
    function openAsHostedDialog(wd) {
        if (!wd)
            return;
        dialogHostLoader.active = true;
        const v = dialogHostLoader.item;
        if (v && typeof v.openDialog === "function") {
            v.openDialog(wd, null);
            if (wd.preview && /^https?:\/\//.test(wd.preview))
                v.downloadPreviews([wd]);
            v.detachDialog();
        } else {
            // Loader still instantiating — park until onLoaded below.
            root._pendingHostedImage = wd;
        }
    }
    Loader {
        id: dialogHostLoader
        active: false
        sourceComponent: dialogHostComp
        onLoaded: {
            if (root._pendingHostedImage && item && typeof item.openDialog === "function") {
                const p = root._pendingHostedImage;
                root._pendingHostedImage = null;
                item.openDialog(p, null);
                if (p.preview && /^https?:\/\//.test(p.preview))
                    item.downloadPreviews([p]);
                item.detachDialog();
            }
        }
    }
    Component {
        id: dialogHostComp
        BooruViewer {
            dialogOnly: true
        }
    }

    // ---- placeholder: no image selected ----
    Item {
        anchors.fill: parent
        visible: !root.hasWaifu

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                text: "No image selected"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
            }
            Text {
                text: "Open Booru Viewer to select an image"
                color: Theme.fgDim
                font.pixelSize: Theme.fontSize
            }
            AppButton {
                text: "Open Booru Viewer"
                onClicked: {
                    // Show the left island + set its widget
                    // to BooruViewer. Registry.selectLeftTab does both
                    // (never toggles it off when already visible).
                    Registry.selectLeftTab("BooruViewer");
                }
            }
        }
    }

    // Hover state keeps the overlay open while the search field holds focus
    // (mouse may leave the image while typing an ID).
    property bool searchFocused: false

    // ---- media display with hover-reveal action overlay ----
    // The image fills the widget; the actions live in a floating sheet
    // anchored to the image bottom that slides upwards on hover.
    Item {
        id: mediaContainer
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.mediaHeight
        visible: root.hasWaifu
        clip: true

        // Revealed while hovering the image/overlay, or while typing an ID.
        readonly property bool overlayRevealed: hoverHandler.hovered || root.searchFocused

        HoverHandler {
            id: hoverHandler
        }

        AppImage {
            id: imageDisplay
            anchors.fill: parent
            // Source owned by refreshSources() (re-points after the
            // ensure-download lands). Preview fallback while missing.
            source: root.imagePath
            fallbackSource: root.previewPath
            sourceWidth: parent.width
            visible: !root.isVideo
        }

        // Video fallback — shared AppVideo (same mapping MediaVideo
        // used: visibility-gated decoder, unmuted audio, Stretch fill).
        AppVideo {
            id: mediaVideo
            anchors.fill: parent
            source: root.imagePath
            autoplay: true
            loop: true
            fillMode: VideoOutput.Stretch
            visible: root.isVideo && root.wd_extension.toLowerCase() !== "zip"
        }

        // Zip/ugoira placeholder
        Column {
            anchors.centerIn: parent
            spacing: 8
            visible: root.wd_extension.toLowerCase() === "zip"
            Text {
                text: "\u{F13C6}"
                color: Theme.fgDim
                font.pixelSize: 40
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "This type of video file cannot be played."
                color: Theme.fgDim
                font.pixelSize: Theme.fontSize
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
            Text {
                text: "Open in browser to view media."
                color: Theme.fgDim
                font.pixelSize: Theme.fontSize - 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }

        // Progress indicator (bound to _loadingState)
        AppProgress {
            id: progressBadge
            z: 3
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 6
            width: 64
            height: 20
            status: root.loadingState
            variant: "badge"
            loadingText: "Loading..."
            errorText: "Error"
        }

        // Peek handle — affordance hint shown while the overlay is hidden.
        Rectangle {
            z: 1
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: 40
            height: 5
            radius: 3
            color: Theme.fg
            opacity: mediaContainer.overlayRevealed ? 0 : 0.65
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
        }

        // ---- action overlay sheet: slides upwards from the image bottom ----
        Rectangle {
            id: actionsOverlay
            z: 2
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            // Hidden state parks the sheet below the image edge; the clip
            // on mediaContainer keeps it out of sight during the slide.
            anchors.bottomMargin: mediaContainer.overlayRevealed ? 8 : -(height + 16)
            Behavior on anchors.bottomMargin {
                NumberAnimation {
                    duration: 280
                    easing.type: Easing.OutCubic
                }
            }
            height: actionsCol.height + 20
            radius: Theme.radius
            color: Theme.surfaceHover
            border.color: Theme.border
            border.width: 1
            opacity: mediaContainer.overlayRevealed ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }
            // Ignore pointer input while hidden so image hovers/views pass through.
            enabled: mediaContainer.overlayRevealed

            Column {
                id: actionsCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 8

                // Section 1: bookmark + pin
                RowLayout {
                    width: parent.width
                    height: 28
                    spacing: 8
                    // Bookmark toggle
                    AppButton {
                        property bool bookmarked: BooruActions.isBookmarked(root.wd)
                        text: bookmarked ? "\uf02e" : "\uf097"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        toggle: true
                        checked: bookmarked
                        tooltipText: bookmarked ? "Remove bookmark" : "Bookmark"
                        onClicked: BooruActions.toggleBookmark(root.wd)
                    }

                    // Pin to terminal
                    AppButton {
                        property bool pinned: BooruActions.isPinned(root.wd)
                        text: "\uf08d"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        toggle: true
                        checked: pinned
                        tooltipText: root.isVideo ? "Cannot pin videos" : (pinned ? "Unpin from terminal" : "Pin to terminal")
                        enabled: !root.isVideo
                        onClicked: BooruActions.togglePinned(root.wd)
                    }
                }

                // Section 2: open in viewer + browser + copy
                RowLayout {
                    width: parent.width
                    height: 28
                    spacing: 8

                    // Open as floating Booru dialog window
                    AppButton {
                        text: ""
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        tooltipText: "Open as dialog"
                        onClicked: root.openAsDialog()
                    }

                    // Open in browser
                    AppButton {
                        text: "\u{f08e}"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        tooltipText: "Open post in browser"
                        onClicked: BooruActions.openInBrowser(root.wd)
                    }

                    // Copy post ID (shared service — same as the dialog's Copy ID).
                    AppButton {
                        text: "\u{f0c5}"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        tooltipText: "Copy post ID"
                        onClicked: BooruActions.copyTag(String(root.wd_id))
                    }
                }

                // Section 3: search by ID + entry + upload
                RowLayout {
                    width: parent.width
                    height: 28
                    spacing: 8
                    // Search by ID
                    AppButton {
                        text: "\u{f002}"
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 28
                        tooltipText: "Search by post ID"
                        onClicked: idSearchField.forceActiveFocus()
                    }

                    AppTextField {
                        id: idSearchField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        placeholderText: "Post ID..."
                        text: root.wd && root.wd.input_history ? root.wd.input_history : ""
                        font.family: Theme.fontFamily
                        onActiveFocusChanged: root.searchFocused = activeFocus
                        onAccepted: {
                            const query = (text || "").trim();
                            if (query === "")
                                return;
                            root.loadingState = "loading";
                            const api = root.booruApis[root.selectedApiIndex];
                            BooruActions.fetchPostById(api.value, query, function (img, err) {
                                if (!img) {
                                    root.loadingState = "error";
                                    Notifications.notify({
                                        summary: "Waifu search failed",
                                        body: err || "Post not found"
                                    });
                                    return;
                                }
                                img.input_history = query; // persist last ID
                                Settings.waifu = img;
                                Settings.schedulePersist();
                                root.loadingState = "success";
                            });
                        }
                    }

                    // Upload custom image (zenity select → identify dims
                    // → copy to custom/images/-1.<ext> → set as current waifu)
                    AppButton {
                        text: "\u{f093}"
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 28
                        tooltipText: "Upload custom image"
                        onClicked: root.uploadCustomImage()
                    }
                }

                // Section 4: API tabs
                RowLayout {
                    width: parent.width
                    height: 28
                    spacing: 8
                    Repeater {
                        model: root.booruApis
                        delegate: AppButton {
                            text: modelData.name
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            toggle: true
                            checked: root.selectedApiIndex === index
                            onClicked: root.selectedApiIndex = index
                            pixelSize: Theme.fontSize - 4
                        }
                    }
                }
            } // actionsCol
        } // actionsOverlay
    } // mediaContainer
}
