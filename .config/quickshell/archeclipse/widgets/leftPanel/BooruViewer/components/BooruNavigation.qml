import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.widgets.shared

// Bottom bar: progress pill + windowed page selector. Tab switching lives on the viewer's
// shared navigation now; viewer: entry root.

Column {
    property var viewer

    Layout.fillWidth: true
    width: parent.width
    spacing: Theme.spacing

    // Progress pill at the very bottom (ChatBot parity: full-width pill,
    // visible on loading/error only, default Working... / Error texts).
    AppProgress {
        width: parent.width
        // Plain Column ignores implicitHeight — bind it explicitly.
        height: implicitHeight
        status: viewer.progressStatus
        variant: "pill"
    }

    Row {
        id: pageBar

        spacing: Theme.spacing
        anchors.horizontalCenter: parent.horizontalCenter

        // Windowed page buttons as a sliding segment ("..." is a disabled cell). viewer.page and
        // widgetWidth are read directly — inside buildPageButtons() the highlight stuck.
        AppSegmentedControl {
            enabled: viewer.progressStatus !== "loading"
            pixelSize: Theme.fontSize - 2
            model: {
                if (!viewer)
                    return [];
                viewer.page;
                viewer.widgetWidth;
                return viewer.buildPageButtons().map(b => ({
                            value: b.page,
                            label: b.label,
                            enabled: b.page > 0
                        }));
            }
            currentIndex: {
                if (!viewer)
                    return -1;
                viewer.page;
                viewer.widgetWidth;
                return viewer.buildPageButtons().findIndex(b => b.active);
            }
            onActivated: (i, v) => viewer.gotoPage(v)
        }
    }
}
