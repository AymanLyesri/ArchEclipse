import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.widgets.shared
import qs.services

// Bottom bar: progress + page buttons + prev/reveal/next
// (extracted verbatim from BooruViewerWidget).
// viewer: entry root (page, progressStatus, gotoPage, fetchImages...).
Column {
    property var viewer
    Layout.fillWidth: true
    width: parent.width
    spacing: 4
    Rectangle {
        width: parent.width
        height: viewer.progressStatus === "idle" ? 0 : 4
        radius: 2
        color: viewer.progressStatus === "loading" ? Theme.accent
              : viewer.progressStatus === "error" ? Theme.danger : "transparent"
        visible: viewer.progressStatus !== "idle" && viewer.progressStatus !== "success"
        Behavior on height { NumberAnimation { duration: 150 } }
    }
    Flow {
        id: pageBar
        width: parent.width
        height: 28
        spacing: 4
        anchors.horizontalCenter: parent.horizontalCenter

        // First-page button + ellipsis when page > 3 (AGS logic)
        Repeater {
            model: viewer.buildPageButtons()
            delegate: AppButton {
                readonly property var modelDataObj: modelData  // {label, active}
                text: modelData.label
                width: modelData.active ? 40 : 28
                height: 28
                enabled: viewer.progressStatus !== "loading" && modelData.page > 0
                pixelSize: Theme.fontSize - 2
                onClicked: viewer.gotoPage(modelData.page)
            }
        }
    }
    Row {
        spacing: 8
        width: parent.width
        height: 28

        AppButton {
            text: "\u{F053}"  // chevron left (AGS prev)
            width: 32; height: 28
            enabled: viewer.progressStatus !== "loading"
            onClicked: {
                if (viewer.page > 1) {
                    viewer.pageDirection = "prev"
                    viewer.page = viewer.page - 1
                    Settings.booru.page = viewer.page
                    Settings.updateSetting("booru.page", viewer.page)
                    viewer.fetchImages()
                }
            }
        }

        AppButton {
            text: viewer.bottomRevealed ? "\u{f07e}" : "\u{f07c}"  // down/up chevron
            width: 32; height: 28
            onClicked: viewer.bottomRevealed = !viewer.bottomRevealed
        }

        AppButton {
            text: "\u{F054}"  // chevron right (AGS next)
            width: 32; height: 28
            enabled: viewer.progressStatus !== "loading"
            onClicked: {
                viewer.pageDirection = "next"
                viewer.page = viewer.page + 1
                Settings.booru.page = viewer.page
                Settings.updateSetting("booru.page", viewer.page)
                viewer.fetchImages()
            }
        }

        Text {
            id: pageLabel
            text: "Page " + viewer.page
            color: Theme.fgDim
            font.pixelSize: Theme.fontSize - 1
            height: parent.height
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            id: navSpacer
            height: 1
            width: Math.max(0, parent.width - 96 - pageLabel.width - statusLabel.width - 40)
        }

        Text {
            id: statusLabel
            text: viewer.progressStatus
            color: Theme.accent
            font.pixelSize: Theme.fontSize - 2
            height: parent.height
            verticalAlignment: Text.AlignVCenter
        }
    }}
