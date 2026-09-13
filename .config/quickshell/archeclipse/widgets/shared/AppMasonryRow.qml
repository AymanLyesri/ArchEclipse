// Shared horizontal masonry layout: transpose of AppMasonry — distributes a
// flat model into N rows (shortest-row by cumulative width, aspect-aware
// when available, round-robin otherwise) for horizontal-scroll strips.
// Used by the wallpaper panel: the local and wallhaven strips share this
// one layout (and one rows/tile-size settings pair).
//
// Usage:
//   AppMasonryRow {
//     width: stripViewport.width  // explicit Flickable width (see contract)
//     rows: 2
//     spacing: 6
//     rowHeight: 120              // exact tile height (not viewport-derived)
//     model: myArray
//     aspectRatio: item => (item.w && item.h) ? item.w / item.h : 16/9
//     // View-windowed lazy loading: only cells intersecting the viewport
//     // (+ buffer) instantiate their delegate; the rest hold a lightweight
//     // placeholder at the correct size, so open/scroll stay cheap on
//     // 100+ item models. viewRight < 0 disables windowing (load all).
//     viewLeft: flick.contentX - 700
//     viewRight: flick.contentX + flick.width + 700
//     buffer: 700
//     placeholder: Rectangle { color: Theme.surface; radius: 6 }
//     delegate: Item {
//       property var modelData  // plain, NOT required (see contract)
//       width: masonry.widthFor(modelData)
//       height: masonry.rowHeight
//       ...
//     }
//   }
//
// Contract (mirrors AppMasonry):
// - `model` is a flat JS array. `aspectRatio(item)` is optional (w/h ratio;
//   null = round-robin dealing). Aspect inputs must be REPLACED, not mutated
//   (reassign the array/cache object) so the layout recomputes.
// - `delegate` must declare `property var modelData` (plain, NOT required —
//   Loader cannot supply required props at creation) and an explicit `width`
//   (Item.width defaults to the wrapper's 0 — the wrapper sizes off
//   item.width, same as AppMasonry sizes off item.height).
// - This item is layout-only (no Flickable). Wrap it in a horizontal
//   SmoothFlickable, bind contentWidth here, and give the Flickable an
//   explicit height (rows*rowHeight + spacing + scrollbar room). Heights and
//   widths both come from settings inputs — never from the viewport — so no
//   content<->viewport negotiation loop.
// - `width` must be the Flickable's explicit width, never `parent.width` of
//   the viewport (same 0-width wedge rule as AppMasonry).

import QtQuick

Item {
    id: root

    property var model: []
    property int rows: 2
    property real spacing: 6
    property real rowHeight: 120
    // function(item) -> width/height ratio, or null for round-robin
    property var aspectRatio: null
    property Component delegate
    // Lazy window in content coordinates (bind to the host Flickable).
    // viewRight < 0 loads everything (safe default for small models).
    property real viewLeft: 0
    property real viewRight: -1
    property real buffer: 600
    // Optional placeholder for not-yet-loaded cells (sized by the wrapper;
    // keep it theme-free here — callers pass themed visuals). Null renders
    // an empty gap of the correct size.
    property Component placeholder: null

    // Widths are DERIVED from the aspectRatio function (never looked up by
    // item identity): tiles call aspectFor/widthFor with the same function
    // and inputs the distribution uses, so laid-out widths always agree with
    // contentWidth by construction. (A JS Map stored in a QML var loses
    // object-key identity across the boundary and misses on every lookup,
    // which left all tiles at the fallback width while contentWidth was
    // computed from real aspects — the strip end clipped.)
    function aspectFor(item) {
        const fallback = 16 / 9;
        const ratioFn = root.aspectRatio;
        if (typeof ratioFn === "function") {
            try {
                const r = Number(ratioFn(item));
                if (isFinite(r) && r > 0)
                    return r;
            } catch (e) {}
        }
        return fallback;
    }

    // Single-pass layout: row assignment + strip width. Rows hold CELLS
    // ({item, x, w}) with precomputed content-x offsets, so wrappers know
    // their view-window membership immediately — no laid-out positions
    // needed (all x would read 0 pre-layout and defeat lazy loading).
    readonly property var _layout: {
        const list = root.model || [];
        const n = Math.max(1, root.rows);
        const rh = Math.max(1, root.rowHeight);
        const gap = root.spacing;
        const useMasonry = typeof root.aspectRatio === "function";
        const buckets = [];
        for (let i = 0; i < n; i++)
            buckets.push({
                w: 0,
                cells: []
            });
        for (let idx = 0; idx < list.length; idx++) {
            const item = list[idx];
            const w = rh * root.aspectFor(item);
            let t;
            if (useMasonry) {
                t = buckets[0];
                for (const c of buckets)
                    if (c.w < t.w)
                        t = c;
            } else {
                // Round-robin preserves order for fixed-aspect models.
                t = buckets[idx % n];
            }
            t.cells.push({
                item: item,
                x: t.w,
                w: w
            });
            t.w += w + gap;
        }
        let content = 0;
        for (const c of buckets)
            content = Math.max(content, c.w);
        if (content > 0)
            content -= gap;
        return {
            rows: buckets.map(c => c.cells),
            contentWidth: content
        };
    }
    readonly property var masonryRows: root._layout.rows
    readonly property real contentWidth: root._layout.contentWidth

    // Tile width for an item: rowHeight * aspectFor(item). Same function and
    // inputs the distribution uses, so tiles always match contentWidth
    // (including the 16:9 fallback before modelData arrives or aspects decode).
    function widthFor(item) {
        return Math.max(1, root.rowHeight) * root.aspectFor(item);
    }

    implicitHeight: Math.max(1, root.rows) * Math.max(1, root.rowHeight) + (Math.max(1, root.rows) - 1) * root.spacing

    Column {
        id: masonryCol
        spacing: root.spacing

        Repeater {
            model: root.masonryRows
            delegate: Row {
                required property var modelData
                property var rowItems: modelData
                spacing: root.spacing

                Repeater {
                    model: parent.rowItems
                    delegate: Item {
                        required property var modelData
                        // modelData is a CELL ({item, x, w}); the delegate
                        // receives only .item (contract unchanged).
                        property var cellData: modelData
                        readonly property bool inWindow: root.viewRight < 0 || (cellData.x + cellData.w >= root.viewLeft - root.buffer && cellData.x <= root.viewRight + root.buffer)
                        width: (cellLoader.active && cellLoader.item) ? cellLoader.item.width : cellData.w
                        height: root.rowHeight

                        // Placeholder at the correct size while out of view.
                        Loader {
                            id: holderLoader
                            anchors.fill: parent
                            active: !cellLoader.active
                            sourceComponent: root.placeholder
                        }

                        Loader {
                            id: cellLoader
                            height: parent.height
                            active: parent.inWindow
                            sourceComponent: root.delegate
                            property var modelData: parent.cellData.item
                            onLoaded: {
                                if (item && Object.prototype.hasOwnProperty.call(item, "modelData"))
                                    item.modelData = modelData;
                            }
                            onModelDataChanged: {
                                if (item && Object.prototype.hasOwnProperty.call(item, "modelData"))
                                    item.modelData = modelData;
                            }
                        }
                    }
                }
            }
        }
    }
}
