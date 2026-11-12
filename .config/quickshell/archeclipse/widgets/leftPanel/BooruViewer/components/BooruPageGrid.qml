import QtQuick
import qs.theme
import qs.widgets.shared

// N×M page-grid block that slides with the current page. Layout-neutral: the host sizes it
// and implicitHeight carries the real content height.
Item {
    id: ctrl

    property var viewer
    property int cols: 3
    property int rows: 3
    readonly property int cellCount: Math.max(1, ctrl.cols * ctrl.rows)

    // Current page sits mid-grid, so the block advances one cell at a time and the
    // pages past the right edge become selectable (a fixed block stalled at 1..9).
    readonly property int centerOffset: Math.floor((ctrl.cellCount - 1) / 2)
    readonly property int windowStart: ctrl.viewer ? Math.max(1, ctrl.viewer.page - ctrl.centerOffset) : 1
    readonly property int windowEnd: ctrl.windowStart + ctrl.cellCount - 1

    // Jump box: the block reaches neighbouring pages; this reaches any page number.
    function jump() {
        const n = Math.round(Number(jumpField.text));
        if (!ctrl.viewer || !(n >= 1))
            return;
        jumpField.text = "";
        ctrl.viewer.gotoPage(n);
    }

    // Deterministic cell size: derived from width, never from Grid's implicit sizing
    // (which resolves a frame late and collapsed the block to one row).
    readonly property real cellSize: Math.max(22, Math.floor((ctrl.width - (ctrl.cols - 1) * Theme.spacing) / ctrl.cols))
    readonly property real gridHeight: ctrl.rows * ctrl.cellSize + (ctrl.rows - 1) * Theme.spacing

    implicitWidth: grid.implicitWidth
    implicitHeight: body.implicitHeight

    // The page block plus its jump box: both are one section of the panel body,
    // which supplies the single gap to Display/Tags.
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

        // Enter jumps; the field clears so the next number starts empty.
        AppTextField {
            id: jumpField

            width: parent.width
            height: Math.max(24, Math.round(ctrl.cellSize * 0.72))
            font.pixelSize: Math.min(Theme.fontSize - 2, Math.max(9, Math.round(ctrl.cellSize * 0.36)))
            placeholderText: "Jump to page"
            inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator { bottom: 1; top: 99999 }
            Keys.onReturnPressed: ctrl.jump()
        }
    }
}
