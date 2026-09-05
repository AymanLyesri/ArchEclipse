import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.widgets.shared
import qs.services
import qs.widgets.media

// Detail revealer docked to the right of the grid (was a centered popup).
// viewer: entry root (dialogImage, download/bookmark/pin actions...).
Item {
    property var viewer
    clip: true
    visible: viewer.dialogImage !== null

    Column {
        width: parent.width
        spacing: 8
        visible: viewer.dialogImage !== null

        // header: close
        Row {
            width: parent.width
            spacing: 6
            Text {
                text: viewer.dialogImage ? `#${viewer.dialogImage.id}` : ""
                color: Theme.fg
                font.pixelSize: 12
                font.bold: true
            }
            Item { Layout.fillWidth: true; width: 1; height: 1 }
            AppButton {
                text: "X"
                onClicked: viewer.requestClose()
            }
        }

        // media (image / video-placeholder / zip-placeholder)
        Rectangle {
            id: dialogMedia
            width: parent.width
            height: 260
            radius: 6
            color: Theme.bg
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 4
                source: viewer.dialogImage ? viewer.imageFileUrl(viewer.dialogImage) : ""
                fillMode: Image.PreserveAspectFit
                sourceSize.width: parent.width
                asynchronous: true
                visible: viewer.dialogImage ? !viewer.isVideo(viewer.dialogImage) : false
            }
            // video downloaded → playable via QtMultimedia (AGS Video.tsx)
            MediaVideo {
                anchors.fill: parent
                anchors.margins: 4
                source: viewer.dialogImage ? viewer.imageFileUrl(viewer.dialogImage).replace(/^file:\/\//, "") : ""
                autoplay: true
                loop: true
                fill: true
                visible: viewer.dialogImage ? viewer.isVideo(viewer.dialogImage) && viewer.isDownloaded(viewer.dialogImage) && (viewer.dialogImage.extension||"").toLowerCase() !== "zip" : false
            }
            // video not downloaded → placeholder
            Rectangle {
                anchors.fill: parent
                visible: viewer.dialogImage ? viewer.isVideo(viewer.dialogImage) && !viewer.isDownloaded(viewer.dialogImage) : false
                color: "black"
                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "\u{f03d}"; font.pixelSize: 40; color: Theme.fgDim }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: viewer.dialogImage && (viewer.dialogImage.extension||"").toLowerCase()==="zip" ? "Cannot be played." : "Video — download to play"; color: Theme.fgDim; font.pixelSize: 11 }
                }
            }
            // download progress overlay
            BusyIndicator {
                anchors.centerIn: parent
                running: viewer.progressStatus === "loading"
                visible: running
            }
            // zoom-to-full on click
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: viewer.openInBrowser(viewer.dialogImage)
            }
        }

        // caption: dimensions + downloaded flag
        Row {
            width: parent.width
            spacing: 6
            Text { text: viewer.dialogImage ? `${viewer.dialogImage.width}x${viewer.dialogImage.height}` : ""; color: Theme.fgDim; font.pixelSize: 11 }
            Text { text: viewer.dialogImage && viewer.isDownloaded(viewer.dialogImage) ? "  \u{f019} Downloaded" : ""; color: "lightgreen"; font.pixelSize: 11 }
        }

        // tags flow (AGS maxTags=10; height follows content, capped)
        Flow {
            id: tagFlow
            width: parent.width
            height: Math.max(24, Math.min(120, tagFlow.implicitHeight || 68))
            spacing: 4
            clip: true
            Repeater {
                model: viewer.dialogImage && viewer.dialogImage.tags ? viewer.dialogImage.tags.slice(0, 10) : []
                delegate: Rectangle {
                    width: tagDetail.implicitWidth + 12
                    height: 20
                    radius: 10
                    color: tagDetailMa.containsMouse ? Theme.accentBg : Theme.moduleBg
                    Text {
                        id: tagDetail
                        anchors.centerIn: parent
                        text: modelData
                        color: Theme.fgDim
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: tagDetailMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: viewer.copyTag(modelData)
                        onPressAndHold: viewer.openTags(modelData)
                    }
                }
            }
        }

        // actions, stacked for narrow panel
        Column {
            id: dialogBottom
            width: parent.width
            spacing: 4
            AppButton {
                width: parent.width
                text: (viewer.isBookmarked(viewer.dialogImage) ? "󰀮 Unbookmark" : "󰀮 Bookmark")
                onClicked: viewer.toggleBookmark(viewer.dialogImage)
            }
            AppButton {
                width: parent.width
                text: (viewer.isPinned(viewer.dialogImage) ? "󰥬 Unpin" : "󰥬 Pin")
                onClicked: viewer.togglePinned(viewer.dialogImage)
            }
            AppButton {
                width: parent.width
                text: "\u{f019} Download"
                enabled: !viewer.isDownloaded(viewer.dialogImage)
                onClicked: viewer.downloadImage(viewer.dialogImage)
            }
            AppButton {
                width: parent.width
                text: (viewer.isCurrentWaifu(viewer.dialogImage) ? "\u{f004} Current waifu" : "\u{f004} Set waifu")
                onClicked: viewer.setAsWaifu(viewer.dialogImage)
            }
            AppButton {
                width: parent.width
                text: "\u{f05e} Close"
                onClicked: viewer.requestClose()
            }
        }
    }

    Keys.onEscapePressed: viewer.requestClose()
    focus: visible
}
