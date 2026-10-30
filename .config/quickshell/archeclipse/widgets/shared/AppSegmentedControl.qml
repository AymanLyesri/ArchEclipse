// Shared animated segmented control: single-select pills with one sliding highlight Rectangle
// (model [string] or [{value,label,icon,tooltip,enabled}], currentIndex caller-driven).
import QtQuick
import QtQuick.Controls
import qs.theme
import "ModelEntry.js" as ModelEntry

Item {
    id: root

    property var model: []
    property int currentIndex: 0
    readonly property int count: root.model?.length ?? 0
    readonly property var currentValue: ModelEntry.valueAt(root.model, root.currentIndex)

    property int pixelSize: Theme.fontSize
    property string fontFamily: Theme.fontFamily
    property int cornerRadius: 8
    property int cellHPadding: 14
    property int cellVPadding: 8
    property int highlightMargin: 2
    property int animationDuration: Theme.anim.defaultEffects
    // Opt-in equal-fill: cells stretch to share root.width, off by default so implicit-sized
    // usages stay untouched.
    property bool stretchCells: false

    signal activated(int index, var value)

    // The cell the highlight tracks: set imperatively (Repeater children exist after creation)
    // but bound by the highlight, so Row repositioning after a model swap is followed.
    property Item highlightCell: null
    property int _syncRetries: 0


    // Arrow-key navigation between segments.
    Keys.onLeftPressed: e => moveSelection(-1, e)
    Keys.onRightPressed: e => moveSelection(1, e)
    function moveSelection(delta, e) {
        if (!root.enabled || root.count === 0)
            return;
        // Skip disabled cells; stop at the ends.
        let next = root.currentIndex + delta;
        while (next >= 0 && next < root.count && !ModelEntry.enabledAt(root.model, next))
            next += delta;
        if (next < 0 || next >= root.count || next === root.currentIndex)
            return;
        root.activated(next, ModelEntry.valueAt(root.model, next));
        if (e)
            e.accepted = true;
    }

    implicitWidth: bg.implicitWidth
    implicitHeight: bg.implicitHeight
    activeFocusOnTab: true

    Rectangle {
        id: bg
        anchors.fill: parent
        implicitWidth: row.implicitWidth + root.highlightMargin * 2
        implicitHeight: row.implicitHeight + root.highlightMargin * 2
        radius: root.cornerRadius + 2
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        opacity: root.enabled ? 1 : Theme.opacity.disabled

        // Sliding selection pill — the only animated chrome; geometry follows highlightCell so
        // it never sticks after a model/currentIndex swap.
        Rectangle {
            id: highlight
            visible: root.highlightCell !== null
            x: root.highlightCell ? row.x + root.highlightCell.x : 0
            width: root.highlightCell ? root.highlightCell.width : 0
            y: root.highlightMargin
            height: parent.height - root.highlightMargin * 2
            radius: root.cornerRadius
            color: Theme.surfaceActive
            border.width: 1
            border.color: Theme.border
            Behavior on x {
                Anim {
                    duration: root.animationDuration
                }
            }
            Behavior on width {
                Anim {
                    duration: root.animationDuration
                }
            }
        }

        Row {
            id: row
            x: root.highlightMargin
            y: root.highlightMargin
            height: parent.height - root.highlightMargin * 2
            width: root.stretchCells ? root.width - root.highlightMargin * 2 : implicitWidth
            spacing: 2

            Repeater {
                id: repeater
                model: root.model
                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool selected: root.currentIndex === index
                    readonly property string label: ModelEntry.labelAt(root.model, index)
                    readonly property string icon: ModelEntry.iconAt(root.model, index)
                    // NOTE: named cellEnabled — Item.enabled already exists.
                    readonly property bool cellEnabled: ModelEntry.enabledAt(root.model, index)
                    readonly property bool dimmed: !cell.cellEnabled || !root.enabled

                    implicitWidth: cellRow.implicitWidth + root.cellHPadding * 2
                    implicitHeight: cellRow.implicitHeight + root.cellVPadding * 2
                    // Stretched mode shares root.width equally (floor at implicit size). Reads
                    // root.width, not row.width, so the Row's implicit sizing cannot loop back.
                    width: root.stretchCells && root.count > 0 ? Math.max(implicitWidth, (root.width - root.highlightMargin * 2 - (root.count - 1) * row.spacing) / root.count) : implicitWidth
                    // Full-row click area. Must NOT bind to row.height — a child feeding the
                    // positioner's geometry makes the Row report 0 implicit size.
                    height: implicitHeight

                    AppTooltip {
                        visible: cellMa.containsMouse && ModelEntry.tooltipAt(root.model, index) !== ""
                        text: ModelEntry.tooltipAt(root.model, index)
                    }

                    Row {
                        id: cellRow
                        anchors.centerIn: parent
                        spacing: Theme.spacing
                        Text {
                            visible: cell.icon !== ""
                            text: cell.icon
                            font.pixelSize: root.pixelSize
                            font.family: root.fontFamily
                            verticalAlignment: Text.AlignVCenter
                            color: cell.dimmed ? Theme.muted : (cell.selected ? Theme.accent : (cellMa.containsMouse ? Theme.fg : Theme.muted))
                            opacity: cell.dimmed ? Theme.opacity.disabled : 1
                            Behavior on color {
                                CAnim {}
                            }
                        }
                        Text {
                            text: cell.label
                            font.pixelSize: root.pixelSize
                            font.family: root.fontFamily
                            verticalAlignment: Text.AlignVCenter
                            color: cell.dimmed ? Theme.muted : (cell.selected ? Theme.accent : (cellMa.containsMouse ? Theme.fg : Theme.muted))
                            opacity: cell.dimmed ? Theme.opacity.disabled : 1
                            Behavior on color {
                                CAnim {}
                            }
                        }
                    }

                    MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: cell.cellEnabled
                        cursorShape: cell.cellEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            root.forceActiveFocus();
                            root.activated(cell.index, ModelEntry.valueAt(root.model, cell.index));
                        }
                    }
                }
            }
        }
    }

    function syncHighlight() {
        const cell = repeater.itemAt(root.currentIndex);
        if (!cell) {
            // Delegates rebuild a frame after a model swap — retry briefly instead of parking
            // the highlight at stale coords; keep the old cell meanwhile (no clearing flash).
            if (root.currentIndex >= 0 && root.currentIndex < repeater.count && root._syncRetries < 20) {
                root._syncRetries++;
                Qt.callLater(syncHighlight);
            }
            return;
        }
        root._syncRetries = 0;
        root.highlightCell = cell;
    }

    onCurrentIndexChanged: Qt.callLater(syncHighlight)
    onModelChanged: Qt.callLater(syncHighlight)
    Component.onCompleted: Qt.callLater(syncHighlight)
    // Re-sync after layout settles (delegate widths resolve a frame after
    // model/currentIndex changes, so defer past the Row's own layout).
    Connections {
        target: row
        function onImplicitWidthChanged() {
            Qt.callLater(root.syncHighlight);
        }
    }
}
