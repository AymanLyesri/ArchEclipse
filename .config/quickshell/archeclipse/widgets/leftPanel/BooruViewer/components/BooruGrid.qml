import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.widgets.shared
import qs.theme

// Masonry image grid (shared AppMasonry + slide transition).
// viewer: entry root (images, columns).
SmoothFlickable {
    id: gridScroll

    property var viewer

    // Called by the entry on page change (was direct id access).
    function resetScroll() {
        gridScroll.contentY = 0;
    }

    function slideFrom(x) {
        slideAnim.stop();
        masonry.x = x;
        slideAnim.start();
    }

    // Always full width: the detail is a root-level overlay, so the grid
    // never surrenders space or relayouts when it opens.
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    contentWidth: width
    contentHeight: masonry.implicitHeight
    // Booru pins the fling speed lower than the shared default.
    maximumFlickVelocity: 1000

    // Follow tick: the card glides inside the static popup surface, so
    // scrolling here only retargets a local y binding (plus the cheap
    // dismiss check) — no window reposition, no layout, no stutter.
    onContentYChanged: {
        if (viewer && viewer.dialogImage !== null)
            viewer.refreshDialogTop(-1);
    }
    onHeightChanged: {
        if (viewer && viewer.dialogImage !== null)
            viewer.refreshDialogTop(-1);
    }

    // Shared masonry: shortest-column by aspect ratio.
    AppMasonry {
        id: masonry

        width: parent.width
        columns: viewer ? viewer.columns : 3
        // No spacing override: inherits the shared Theme.spacing default,
        // same as the wallpaper masonry rows.
        model: viewer ? viewer.images : []
        aspectRatio: function (img) {
            return (img && img.width && img.height) ? img.height / img.width : 1;
        }

        // NOTE: plain (not required) modelData — Loader cannot supply
        // required props at creation; AppMasonry pushes it onLoaded.
        // BooruImage has required image/viewer, so guard undefined on
        // first creation and only bind once modelData arrives.
        delegate: Item {
            property var modelData
            width: parent.width
            height: cardLoader.item ? cardLoader.item.height : 0

            Loader {
                id: cardLoader
                width: parent.width
                active: parent.modelData !== undefined
                sourceComponent: cardComp
                property var image: parent.modelData
                property var viewer: gridScroll.viewer
            }

            Component {
                id: cardComp
                BooruImage {
                    width: parent.width
                    viewer: parent.viewer
                    image: parent.image
                }
            }
        }
    }

    // Slide transition on page change (slide left/right
    // SLIDE_LEFT/RIGHT + scroll-to-top after transition)
    NumberAnimation {
        id: slideAnim

        target: masonry
        property: "x"
        duration: Theme.anim.small
        to: 0
    }

    ScrollBar.vertical: ScrollBar {
    }
}
