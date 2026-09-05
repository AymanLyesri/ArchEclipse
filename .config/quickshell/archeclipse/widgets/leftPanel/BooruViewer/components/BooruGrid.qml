import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Masonry image grid (extracted verbatim from BooruViewerWidget).
// viewer: entry root (masonryColumns, columns).
Flickable {
    property var viewer

    // Called by the entry on page change (was direct id access).
    function resetScroll() { gridScroll.contentY = 0 }
    function slideFrom(x) { slideAnim.stop(); masonryRow.x = x; slideAnim.start() }
    id: gridScroll
    // Frozen while the detail revealer is open (viewer._gridWidth captured
    // on open): grid keeps its exact width, revealer absorbs all growth.
    Layout.fillWidth: viewer ? viewer.dialogImage === null : true
    Layout.preferredWidth: viewer && viewer.dialogImage !== null ? viewer._gridWidth : 0
    Layout.fillHeight: true
    clip: true
    contentWidth: width
    contentHeight: masonryRow.height
    ScrollBar.vertical: ScrollBar {}

    // Masonry row: N shortest-column Columns (AGS algorithm above)
    Row {
        id: masonryRow
        width: parent.width
        spacing: 6

        // Slide transition on page change (AGS Gtk.Stack
        // SLIDE_LEFT/RIGHT + scroll-to-top after transition)
        NumberAnimation { id: slideAnim; target: masonryRow; property: "x"; duration: 200; to: 0 }

        Repeater {
            model: viewer.masonryColumns
            delegate: Column {
                required property var modelData
                property var columnItems: modelData
                width: (masonryRow.width - (viewer.columns - 1) * 6) / viewer.columns
                spacing: 6
                Repeater {
                    model: parent.columnItems
                    // NOTE: a cross-file delegate cannot see the inner
                    // modelData (resolves to the outer column array /
                    // undefined). Capture it in a same-file wrapper first —
                    // `property var img: modelData` here is proven correct —
                    // then hand it to the card via parent.
                    delegate: Column {
                        property var img: modelData
                        width: parent.width
                        BooruImage {
                            viewer: gridScroll.viewer
                            image: parent.img
                        }
                    }
                }
            }
        }
    }
}
