import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.widgets.shared
import qs.services
import qs.widgets.leftPanel
import qs.widgets.leftPanel.BooruViewer.components as Booru

// Waifu widget: the current waifu rendered as an embedded BooruDialog —
// the full detail card (media, meta, tags, actions, drag-to-float),
// bound to a private pinned viewer. Placeholder + custom upload when
// nothing is set.
Item {
    id: root

    readonly property string booruPath: `${Quickshell.env("HOME")}/.cache/quickshell/booru`

    // Current waifu data from Settings — mirrors globalSettings.waifuWidget.current
    readonly property var waifuDataObj: Settings.waifu || null
    readonly property var wd: root.waifuDataObj

    // The widget shows for any truthy id (custom uploads use id -1) —
    // only a missing/empty id means "no image selected".
    readonly property bool hasWaifu: !!(root.wd && root.wd.id)
    implicitHeight: root.hasWaifu ? waifuDialog.implicitHeight : 190

    // Embedded dialog host: dialogOnly (no grid boot fetch) + dialogPinned
    // (every close path is a no-op — dialogImage is bound to
    // Settings.waifu below and must never be cleared). Full/preview
    // downloads run through the viewer's fetchOriginal/downloadPreviews,
    // exactly like any other dialog.
    BooruViewer {
        id: waifuViewer
        dialogOnly: true
        dialogPinned: true
        dialogImage: root.wd
    }

    onWdChanged: {
        if (!root.hasWaifu)
            return;
        waifuViewer.downloadPreviews([root.wd]);
    }

    Booru.BooruDialog {
        id: waifuDialog
        viewer: waifuViewer
        videoActive: BarState.rightOpen
        width: parent.width
    }

    // Floating upload button (the dialog sheet has no upload action):
    // bottom-right corner, above the card.
    AppButton {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        width: 32
        height: 32
        text: "\uf093"
        tooltipText: "Upload custom image"
        visible: root.hasWaifu
        onClicked: root.uploadCustomImage()
    }

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

    // ---- placeholder: no image selected ----
    Item {
        anchors.fill: parent
        visible: !root.hasWaifu

        Column {
            // Padded: the card is bare (no surface behind it), so the text
            // needs its own inset from the panel edges. Height stays implicit
            // (content) and anchors on the vertical mid-point, so the block
            // centers in the card.
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 16
            spacing: 12

            Text {
                width: parent.width
                text: "No image selected"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
            }
            Text {
                width: parent.width
                text: "Open Booru Viewer to select an image"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.fgDim
                font.pixelSize: Theme.fontSize
            }
            // Centered button row (Column has no alignment of its own —
            // that's Layouts-only).
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                AppButton {
                    text: "Open Booru Viewer"
                    onClicked: {
                        // Show the left island + set its widget
                        // to BooruViewer. Registry.selectLeftTab does both
                        // (never toggles it off when already visible).
                        Registry.selectLeftTab("BooruViewer");
                    }
                }
                AppButton {
                    text: "Upload"
                    tooltipText: "Upload custom image"
                    onClicked: root.uploadCustomImage()
                }
            }
        }
    }
}
