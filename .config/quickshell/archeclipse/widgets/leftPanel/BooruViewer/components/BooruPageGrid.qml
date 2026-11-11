import QtQuick
import qs.theme
import qs.widgets.shared

// N×M page-grid segmented control: a block of contiguous page cells plus a
// prev/next pair that shifts the block by one window. Layout-neutral — the host
// sizes it; implicitHeight carries the real content height.
Item {
    id: ctrl

    property var viewer
    property int cols: 3
    property int rows: 3
    readonly property int cellCount: Math.max(1, ctrl.cols * ctrl.rows)

    readonly property int windowIndex: ctrl.viewer ? Math.max(0, Math.floor((ctrl.viewer.page - 1) / ctrl.cellCount)) : 0
    readonly property int windowStart: ctrl.windowIndex * ctrl.cellCount + 1
    readonly property int windowEnd: ctrl.windowStart + ctrl.cellCount - 1
    readonly property bool hasPrevWindow: ctrl.windowIndex > 0

    // Deterministic cell size: derived from width, never from Grid's implicit sizing
    // (which resolves a frame late and collapsed the block to one row).
    readonly property real cellSize: Math.max(22, Math.floor((ctrl.width - (ctrl.cols - 1) * Theme.spacing) / ctrl.cols))
    readonly property real gridHeight: ctrl.rows * ctrl.cellSize + (ctrl.rows - 1) * Theme.spacing

    implicitWidth: grid.implicitWidth
    implicitHeight: body.implicitHeight

    // Only the cell block here: it joins the panel body as a sibling section of
    // Display/Tags, so the body's own spacing is the single gap between sections.
    Column {
        id: body
        width: parent.width
        spacing: Theme.spacing

        Grid {
            id: grid

            width: parent.width
            height: ctrl.gridHeight
            columns: ctrl.cols
            spacing: Theme.spacing

            Repeater {
                model: ctrl.cellCount

                delegate: AppButton {
                    required property int index

                    readonly property int pageNo: ctrl.windowStart + index
                    readonly property bool isActive: ctrl.viewer && ctrl.viewer.page === pageNo

                    width: ctrl.cellSize
                    height: ctrl.cellSize
                    cornerRadius: Math.max(3, Theme.radius - 4)
                    pixelSize: Math.min(Theme.fontSize - 2, Math.max(9, Math.round(ctrl.cellSize * 0.36)))
                    text: isActive ? Icons.refresh : String(pageNo)
                    tooltipText: isActive ? ("Reload page " + pageNo) : ("Go to page " + pageNo)
                    outlined: isActive
                    outlineColor: Theme.accent
                    idleFg: isActive ? Theme.accent : Theme.fg
                    hoverFg: isActive ? Theme.accent : Theme.fg
                    idleBg: isActive ? Theme.rgba(Theme.accent, 0.14) : Theme.bg

                    onClicked: ctrl.viewer.gotoPage(pageNo)
                }
            }
        }
    }
}
