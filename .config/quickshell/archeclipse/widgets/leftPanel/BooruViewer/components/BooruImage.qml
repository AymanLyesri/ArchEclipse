import QtQuick
import QtQuick.Controls
import qs.services
import qs.theme
import qs.widgets.shared

// One masonry grid card (extracted from BooruViewerWidget imgCardComp).
// viewer: entry root (gridSource, tag predicates, dialog open).
Rectangle {
    id: card

    property var viewer
    required property var image
    readonly property string _imgExt: (((image && image.extension) || "").toLowerCase())
    property bool isVideo: ["mp4", "webm", "mkv", "gif"].includes(card._imgExt) || (card._imgExt === "zip" && !!(image && image.sample))

    width: parent ? parent.width : 0
    height: image && image.width && image.height ? Math.max(80, width * image.height / image.width) : width
    color: Theme.surface
    radius: 10
    clip: true
    // Staggered pop-in: the viewer reveals one id per tick (see
    // _revealTimer); the card fades/scales in only once its file is
    // decoded (Image.Ready) AND its turn arrived. Videos skip the
    // image gate since they show a badge, not a bitmap.
    readonly property bool imgReady: previewImg.status === Image.Ready
    readonly property bool turnArrived: viewer && typeof viewer.isRevealed === "function" ? viewer.isRevealed(image) : true
    readonly property bool popped: card.isVideo ? turnArrived : (turnArrived && imgReady)
    opacity: popped ? 1 : 0
    scale: popped ? 1 : 0.97
    Behavior on opacity {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }

    // Preview image (or placeholder). Render the downloaded local preview;
    // prefer the local file once cached instead of re-downloading the
    // remote URL.
    AppImage {
        id: previewImg
        anchors.fill: parent

        source: viewer.gridSource(image)
        badges: {
            if (!viewer || !image)
                return [];
            const b = [];
            if (card.isVideo)
                b.push("\uf03d");
            if (viewer.isDownloaded && viewer.isDownloaded(image))
                b.push("\uf019");
            if (viewer.isBookmarked && viewer.isBookmarked(image))
                b.push("\uf02e");
            if (viewer.isPinned && viewer.isPinned(image))
                b.push("\uf08d");
            if (viewer.isCurrentWaifu && viewer.isCurrentWaifu(image))
                b.push("\uf004");
            return b;
        }
    }

    MouseArea {
        id: imgMa

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                // Right-click: set as waifu (shared service, same as dialog).
                BooruActions.setAsWaifu(image);
            } else {
                // Left-click: float the detail card at this card's Y
                // (viewer captures the anchor + opens the island).
                viewer.openDialog(image, card);
            }
        }
    }

    AppTooltip {
        visible: imgMa.containsMouse
        text: image ? ("Click to Open\nID: " + image.id + "  " + image.width + "x" + image.height + "\nRight-click: Set as waifu") : ""
    }
}
