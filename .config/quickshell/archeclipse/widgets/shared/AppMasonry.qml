// Shared masonry layout: distributes a flat model into N shortest columns, aspect-aware when
// available. Delegates declare plain `modelData` + explicit height; layout-only, no Flickable.

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
