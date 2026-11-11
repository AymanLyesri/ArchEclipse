import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.widgets.shared

// Bottom status bar: the shared progress pill. Page navigation moved into the left nav
// panel (BooruPageGrid); nothing else lives down here.

Column {
    property var viewer

    Layout.fillWidth: true
    width: parent.width

    // ChatBot parity: full-width pill, visible on loading/error only.
    AppProgress {
        width: parent.width
        // Plain Column ignores implicitHeight — bind it explicitly.
        height: implicitHeight
        status: viewer.progressStatus
        variant: "pill"
    }
}
