// Shared masonry layout: distributes a flat model into N shortest columns
// (aspect-ratio aware when available, round-robin otherwise) and stacks
// each column vertically. Used by the Booru image grid and the donation
// cards — one algorithm, one tuning point.
//
// Usage:
//   AppMasonry {
//     width: parent.width
//     columns: 2
//     spacing: 10
//     model: myArray
//     aspectRatio: item => (item.width && item.height) ? item.height / item.width : 1
//     delegate: Item {
//       property var modelData  // plain, NOT required (see contract)
//       width: parent.width
//       height: 120  // explicit height (aspect, fixed, or implicitHeight-based)
//       ...
//     }
//   }
//
// Contract:
// - `model` is a flat JS array.
// - `aspectRatio(item)` is optional. When provided, items go to the
//   currently-shortest column by cumulative ratio (true masonry, keeps
//   columns even with varying image heights). When null, items are dealt
//   round-robin (even order, best for fixed-height cards).
// - `delegate` must declare `property var modelData` (plain, NOT
//   required — Loader cannot supply required props at creation) and an
//   explicit `height` (Item.height defaults to 0 — implicitHeight alone
//   renders nothing, since the wrapper sizes off item.height).
// - This item is layout-only (no Flickable). Wrap it in SmoothFlickable
//   and bind contentHeight to its height/implicitHeight.
// - `columnWidth` is exposed so delegates can derive heights before
//   layout if needed.

import QtQuick
import qs.theme

Item {
    id: root

    property var model: []
    property int columns: 2
    property real spacing: Theme.spacing
    // function(item) -> height/width ratio, or null for round-robin
    property var aspectRatio: null
    property Component delegate

    readonly property real columnWidth: columns > 0 ? (width - (columns - 1) * spacing) / columns : width
    readonly property var masonryColumns: {
        const list = root.model || [];
        const n = Math.max(1, root.columns);
        const cols = [];
        for (let i = 0; i < n; i++)
            cols.push({ h: 0, items: [] });
        const ratioFn = root.aspectRatio;
        for (let idx = 0; idx < list.length; idx++) {
            const item = list[idx];
            let t;
            if (typeof ratioFn === "function") {
                let ratio = 1;
                try {
                    ratio = Number(ratioFn(item));
                } catch (e) {
                    ratio = 1;
                }
                if (!isFinite(ratio) || ratio <= 0)
                    ratio = 1;
                t = cols[0];
                for (const c of cols)
                    if (c.h < t.h)
                        t = c;
                t.items.push(item);
                t.h += ratio;
            } else {
                // Round-robin preserves order for fixed-height cards.
                t = cols[idx % n];
                t.items.push(item);
                t.h += 1;
            }
        }
        return cols.map(c => c.items);
    }

    implicitHeight: masonryRow.implicitHeight

    Row {
        id: masonryRow
        width: parent.width
        spacing: root.spacing

        Repeater {
            model: root.masonryColumns
            delegate: Column {
                required property var modelData
                property var columnItems: modelData
                width: root.columnWidth
                spacing: root.spacing

                Repeater {
                    model: parent.columnItems
                    delegate: Item {
                        required property var modelData
                        property var cellData: modelData
                        width: parent.width
                        // Explicit item.height only — implicitHeight alone
                        // leaves Item.height at 0 (see AppButton).
                        height: cellLoader.item ? cellLoader.item.height : 0

                        Loader {
                            id: cellLoader
                            width: parent.width
                            sourceComponent: root.delegate
                            property var modelData: parent.cellData
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
