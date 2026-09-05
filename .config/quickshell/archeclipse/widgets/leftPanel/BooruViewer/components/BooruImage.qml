import QtQuick
import QtQuick.Controls
import qs.theme
import qs.services

// One masonry grid card (extracted from BooruViewerWidget imgCardComp).
// viewer: entry root (gridSource, tag predicates, dialog open).
Rectangle {
    property var viewer
    id: card
    required property var image
    property bool isVideo: ["mp4", "webm", "mkv", "gif"]
        .includes(((image && image.extension) || "").toLowerCase())

    width: parent ? parent.width : 0
    height: image && image.width && image.height
        ? Math.max(80, width * image.height / image.width)
        : width

                color: Theme.moduleBg
                radius: 6
                border.width: 1
                border.color: Theme.border
                clip: true

                // Preview image (or placeholder). AGS renders the
                // downloaded local preview; prefer the local file once
                // cached instead of re-downloading the remote URL.
                Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    fillMode: Image.PreserveAspectFit
                    source: viewer.gridSource(image)
                    sourceSize.width: parent.width
                    asynchronous: true
                    cache: true
                    visible: !card.isVideo
                }

                // Video indicator
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: 16; height: 16
                    radius: 8
                    color: Theme.accent
                    visible: card.isVideo
                    Text {
                        text: "\u{f03d}"  // video icon
                        color: "white"
                        font.pixelSize: 10
                        anchors.centerIn: parent
                    }
                }

                // Info overlay
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: infoRow.implicitWidth + 8
                    height: 18
                    color: Theme.bg
                    radius: 4
                    border.color: Theme.border
                    border.width: 1
                    Row {
                        id: infoRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: image.id; color: Theme.fg; font.pixelSize: 10 }
                        Text { text: image.width + "x" + image.height; color: Theme.fgDim; font.pixelSize: 9 }
                    }
                }

                MouseArea {
                    id: imgMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            // Right-click: set as waifu (AGS renderAsWaifuWidget)
                            Settings.waifu = image
                            Settings.persist()
                        } else {
                            // Left-click: open full AGS-style image dialog
                            viewer.dialogImage = image
                        }
                    }
                }

                // Pinned / bookmarked / waifu badges (AGS info icons)
                Rectangle {
                    anchors.top: card.top
                    anchors.left: card.left
                    anchors.margins: 6
                    height: 16; width: infoBadges.implicitWidth + 8
                    radius: 8; color: Theme.accent
                    visible: viewer.isInfoTagged(image)
                    Row {
                        id: infoBadges
                        anchors.centerIn: parent
                        spacing: 3
                        Text { text: viewer.isPinned(image) ? "\u{f96c}" : "\u{f02e}"; color: "white"; font.pixelSize: 9 }
                        Text { text: viewer.isCurrentWaifu(image) ? "\u{f004}" : ""; color: "white"; font.pixelSize: 9 }
                    }
                }

                ToolTip.visible: imgMa.containsMouse
                ToolTip.text: `Click to Open\nID: ${image.id}  ${image.width}x${image.height}\nRight-click: Set as waifu`
            }
