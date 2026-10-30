// Shared horizontal masonry (transpose of AppMasonry): N rows, aspect-aware, view-windowed lazy
// cells. Layout-only: `width` is the Flickable's explicit width, never the viewport's.

import QtQuick
import qs.theme

Item {
    id: root

    property var model: []
    property int rows: 2
    property real spacing: Theme.spacing
    property real rowHeight: 120
    // function(item) -> width/height ratio, or null for round-robin
    property var aspectRatio: null
    // true (default): shortest-row dealing. false: round-robin preserving list order while
    // widths still come from aspectRatio — for sorted lists that must not shuffle.
    property bool balanceRows: true
    property Component delegate
    // Lazy window in content coordinates (bind to the host Flickable).
    // viewRight < 0 loads everything (safe default for small models).
    property real viewLeft: 0
    property real viewRight: -1
    property real buffer: 600
    // Optional placeholder for not-yet-loaded cells (sized by the wrapper, keep it theme-free);
    // null renders an empty gap of the correct size.
    property Component placeholder: null

    // Widths derive from the aspectRatio function, never by item identity — a JS Map in a QML
    // var loses object-key identity, leaving tiles at the fallback width and clipping the strip.
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

    // Row assignment is stable by design: round-robin never reads aspects, so live refines
    // resize in place via widthFor instead of rebuilding delegates (which replayed fades).
    readonly property var _rrRows: {
        const list = root.model || [];
        const n = Math.max(1, root.rows);
        const buckets = [];
        for (let i = 0; i < n; i++)
            buckets.push([]);
        for (let idx = 0; idx < list.length; idx++)
            buckets[idx % n].push(list[idx]);
        return buckets;
    }
    // Live strip width for round-robin rows: re-evaluates on aspect refines
    // (scrollbar range adjusts) without touching delegate instances.
    readonly property real _rrContentWidth: {
        const rows = root._rrRows;
        const gap = root.spacing;
        let content = 0;
        for (let r = 0; r < rows.length; r++) {
            const row = rows[r];
            let w = 0;
            for (let i = 0; i < row.length; i++)
                w += root.widthFor(row[i]) + gap;
            if (w > 0)
                w -= gap;
            if (w > content)
                content = w;
        }
        return content;
    }
    // Content-x of the idx-th tile in a round-robin row (live widths, so
    // view-window membership tracks aspect refines without rebuilds).
    function _rrX(rowItems, idx) {
        let x = 0;
        const gap = root.spacing;
        for (let i = 0; i < idx; i++)
            x += root.widthFor(rowItems[i]) + gap;
        return x;
    }

    // Single-pass balanced layout: rows hold CELLS ({item, x, w}) with precomputed offsets, so
    // wrappers know their window membership pre-layout. Early-out before reading any aspect.
    readonly property var _balLayout: {
        if (!root.balanceRows)
            return {
                rows: [],
                contentWidth: 0
            };
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
    // QML only subscribes to the taken branch: round-robin readers never
    // depend on live aspects, so refines can't rebuild their delegates.
    readonly property var masonryRows: root.balanceRows ? root._balLayout.rows : root._rrRows
    readonly property real contentWidth: root.balanceRows ? root._balLayout.contentWidth : root._rrContentWidth

    // Tile width = rowHeight * aspectFor(item), the same function and inputs the distribution
    // uses, so tiles always match contentWidth (16:9 until aspects decode).
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
                        // Qt6 withholds the implicit Repeater `index` in this scope (ReferenceError
                        // storm, blank strip on scroll) — declare it explicitly.
                        required property int index
                        // Balanced: modelData is a CELL ({item, x, w}); round-robin: the ITEM with
                        // live x/w bindings — ternaries subscribe only to the taken branch.
                        property var cellData: modelData
                        readonly property var _cellItem: root.balanceRows ? cellData.item : cellData
                        readonly property real cellX: root.balanceRows ? cellData.x : root._rrX(parent.rowItems, index)
                        readonly property real cellW: root.balanceRows ? cellData.w : root.widthFor(cellData)
                        readonly property bool inWindow: root.viewRight < 0 || (cellX + cellW >= root.viewLeft - root.buffer && cellX <= root.viewRight + root.buffer)
                        width: (cellLoader.active && cellLoader.item) ? cellLoader.item.width : cellW
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
                            property var modelData: parent._cellItem
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
