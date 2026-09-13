import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.widgets.shared
import qs.services
import qs.widgets.media

// Detail card: the image is the parent — it fills the card and every
// info + action lives in a single hover-reveal bottom sheet (WaifuWidget
// parity). The sheet header carries the drag grip, type badge, title,
// and close; below sit meta, tags, all actions, and resize cell. The
// entrance is slide/fade on the inner wrapper only — never layout geometry.
// viewer: entry root (dialogImage, download/bookmark/pin actions,
// detach + free-geometry for the float window).
//
// The viewer hosts us twice: docked in the island-edge PopupWindow, and
// detached in a normal FloatingWindow (own window, draggable /
// aspect-locked resizable; float behavior via a Hyprland rule). No
// dock-back: close is sufficient.
//
// Design refs:
// - NotificationItem: surface card + radius, top RowLayout (icon, bold
//   title fillWidth, dim meta, 24px outlined icon buttons).
// - MangaViewer cards: Theme fonts, radii, borders.
// - WaifuWidget: media-fill container, hover bottom sheet (slide + fade),
//   peek handle, pill sections on Theme.bg.
Item {
    id: dialogRoot
    property var viewer
    // "Tags" expand state (NotificationItem expand/collapse parity).
    // Reset per-image: dlg tracks viewer.dialogImage, so its change
    // signal fires exactly when a new post is opened.
    property bool showAllTags: false
    onDlgChanged: showAllTags = false
    clip: true
    visible: viewer && viewer.dialogImage !== null
    // Hover handoff: the island keeps itself open while the cursor is on
    // this separate surface (LeftIsland.requestAutoHide via hostPanel).
    HoverHandler {
        id: dialogHover
        onHoveredChanged: {
            if (viewer && typeof viewer.popupHovered !== "undefined")
                viewer.popupHovered = hovered;
        }
    }
    // Card height in the docked popup follows the image ratio, clamped so
    // panoramas/portraits stay sane. Reported back so the viewer can
    // center/clamp on the anchor card. (In the float window the viewer
    // sets an explicit aspect-locked size instead.)
    readonly property real cardH: {
        if (!dlg || !dlg.width || !dlg.height)
            return 260;
        const w = Math.max(1, dialogRoot.width || 220);
        const h = w * dlg.height / dlg.width;
        return Math.min(Math.max(h, 200), 560);
    }
    implicitHeight: dialogRoot.cardH
    onImplicitHeightChanged: {
        if (viewer && implicitHeight > 0)
            viewer.adoptDialogHeight(implicitHeight);
    }

    // Derived display helpers (null-safe; dialogImage may be null).
    readonly property var dlg: viewer ? viewer.dialogImage : null
    readonly property string dlgApiName: dlg && dlg.api ? (dlg.api.name || "") : ""
    readonly property string dlgExt: dlg ? ((dlg.extension || "").toUpperCase()) : ""
    readonly property string dlgDims: dlg ? `${dlg.width || 0}×${dlg.height || 0}` : ""
    readonly property var dlgTags: dlg && dlg.tags ? dlg.tags : []
    readonly property bool dlgIsVideo: dlg ? (viewer ? viewer.isVideo(dlg) : false) : false
    readonly property bool dlgIsGif: dlg ? ((dlg.extension || "").toLowerCase() === "gif") : false
    readonly property bool dlgIsZip: dlg ? ((dlg.extension || "").toLowerCase() === "zip") : false
    readonly property bool dlgDownloaded: dlg ? (viewer ? viewer.isDownloaded(dlg) : false) : false
    readonly property bool dlgBookmarked: dlg ? (viewer ? viewer.isBookmarked(dlg) : false) : false
    readonly property bool dlgPinned: dlg ? (viewer ? viewer.isPinned(dlg) : false) : false
    readonly property bool dlgIsWaifu: dlg ? (viewer ? viewer.isCurrentWaifu(dlg) : false) : false
    readonly property bool dlgLoading: viewer ? (viewer.progressStatus === "loading" || (dlg && !dlgIsVideo && viewer.dialogSource(dlg) === "")) : false
    readonly property bool dlgVideoPlayable: dlg ? (dlgIsVideo && dlgDownloaded && !dlgIsZip && !dlgIsGif) : false
    readonly property bool dlgVideoPlaceholder: dlg ? (dlgIsVideo && !dlgDownloaded) : false
    readonly property string dlgTypeIcon: dlgIsZip ? "" : (dlgIsVideo ? "" : "")
    readonly property int dlgVisibleTagCount: showAllTags ? dlgTags.length : Math.min(dlgTags.length, 12)
    // Bottom sheet reveal (WaifuWidget parity): hovering anywhere on the
    // card (media or the sheet itself — all children of slider) slides
    // the sheet up. The handler must live on the container, not on
    // the media: a handler inside dialogMedia goes false the moment the
    // cursor moves onto the sibling sheet, hiding it under the cursor.
    readonly property bool sheetRevealed: sliderHover.hovered

    Item {
        id: slider
        anchors.fill: parent
        // Glide in from the right edge + fade; layout-agnostic.
        x: (1 - (viewer ? viewer.detailSlide : 1)) * -24
        opacity: viewer ? viewer.detailSlide : 1

        // Card surface: floats over grid content (or the desktop, once
        // floated), so it carries its own backdrop with a subtle outline
        // (NotificationItem parity: Theme.surface + Theme.radius +
        // Theme.border).
        Rectangle {
            anchors.fill: parent
            color: Theme.surface
            radius: Theme.radius
            border.color: Theme.border
            border.width: 1
        }

        // Card-wide hover (sheet reveal + island keep-alive input); the
        // sheet is a sibling of the media, so this lives on the container.
        HoverHandler {
            id: sliderHover
        }

        // ---- media fills the card (AppImage crops to fill) ----
        Rectangle {
            id: dialogMedia
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.bg
            border.color: Theme.border
            border.width: 1
            clip: true

            // video downloaded → playable via QtMultimedia
            MediaVideo {
                anchors.fill: parent
                anchors.margins: 4
                source: dlg ? viewer.imageFileUrl(dlg).replace(/^file:\/\//, "") : ""
                autoplay: true
                loop: true
                fill: true
                visible: dialogRoot.dlgVideoPlayable
            }
            // video not downloaded → placeholder
            Column {
                anchors.centerIn: parent
                spacing: 6
                visible: dialogRoot.dlgVideoPlaceholder || dialogRoot.dlgIsZip
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: dialogRoot.dlgIsZip ? "" : ""
                    font.pixelSize: 32
                    font.family: Theme.fontFamily
                    color: Theme.fgDim
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: dialogRoot.dlgIsZip ? "Cannot be played." : (dialogRoot.dlgIsGif ? "GIF — downloading…" : "Video — downloading…")
                    color: Theme.fgDim
                    font.pixelSize: Theme.fontSize - 1
                    font.family: Theme.fontFamily
                }
            }
            AppImage {
                anchors.fill: parent
                source: dlg ? viewer.dialogSource(dlg) : ""
                sourceWidth: parent.width
                animated: true
                visible: !!dlg && !dialogRoot.dlgVideoPlayable
                badges: {
                    const b = [];
                    if (dialogRoot.dlgDownloaded)
                        b.push("\uf019");
                    if (dialogRoot.dlgBookmarked)
                        b.push("\uf02e");
                    if (dialogRoot.dlgPinned)
                        b.push("\uf08d");
                    if (dialogRoot.dlgIsWaifu)
                        b.push("\uf004");
                    return b;
                }
            }
            AppProgress {
                anchors.centerIn: parent
                width: 20
                height: 20
                status: dialogRoot.dlgLoading ? "loading" : "idle"
                variant: "spinner"
            }
        } // dialogMedia

        // Peek handle — affordance hint shown while the sheet is hidden.
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: 40
            height: 5
            radius: 3
            color: Theme.fg
            opacity: dialogRoot.sheetRevealed ? 0 : 0.65
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
        }

        // ---- bottom sheet: header + meta + tags + all actions ----
        Rectangle {
            id: bottomSheet
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            // Hidden state parks the sheet below the card edge; the clip
            // on dialogRoot keeps it out of sight during the slide.
            anchors.bottomMargin: dialogRoot.sheetRevealed ? 8 : -(height + 16)
            Behavior on anchors.bottomMargin {
                NumberAnimation {
                    duration: 280
                    easing.type: Easing.OutCubic
                }
            }
            // Cap at the card height; overflow scrolls.
            height: Math.min(sheetContent.height + 16, Math.max(120, dialogRoot.height - 16))
            radius: Theme.radius
            color: Theme.surfaceHover
            border.color: Theme.border
            border.width: 1
            opacity: dialogRoot.sheetRevealed ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }
            // Ignore pointer input while hidden so media hovers pass through.
            enabled: dialogRoot.sheetRevealed

            SmoothFlickable {
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: width
                contentHeight: sheetContent.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: sheetContent
                    width: parent.width
                    spacing: 6

                    // Header (merged top bar — NotificationItem parity:
                    // icon, bold title fillWidth, dim meta, 24px outlined
                    // icon button). Single Close lives here; dims live
                    // only in the meta pill below.
                    RowLayout {
                        width: parent.width
                        spacing: 6

                        // Drag grip: floats the card into its own window
                        // on first move, then moves it anywhere on screen
                        // (local deltas — no compositor handshake, no
                        // gesture race). Pure-QML dots (no font dep).
                        Item {
                            id: dragGrip
                            width: 14
                            height: 26
                            Layout.alignment: Qt.AlignVCenter
                            Row {
                                anchors.centerIn: parent
                                spacing: 2
                                Repeater {
                                    model: 2
                                    Column {
                                        spacing: 2
                                        Repeater {
                                            model: 3
                                            Rectangle {
                                                width: 3
                                                height: 3
                                                radius: 1.5
                                                color: Theme.fgDim
                                            }
                                        }
                                    }
                                }
                            }
                            MouseArea {
                                id: dragMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.SizeAllCursor
                                property bool moveStarted: false
                                AppTooltip {
                                    visible: parent.containsMouse
                                    text: "Drag to float as window"
                                }
                                // Detach on press so the window exists,
                                // then start the system move on first
                                // motion: a press-time request can predate
                                // the new window's mapping and be ignored.
                                onPressed: {
                                    if (viewer)
                                        viewer.detachDialog();
                                    dragMouse.moveStarted = false;
                                }
                                onPositionChanged: {
                                    if (!dragMouse.pressed || dragMouse.moveStarted)
                                        return;
                                    dragMouse.moveStarted = true;
                                    if (viewer)
                                        viewer.moveFloat();
                                }
                                onReleased: dragMouse.moveStarted = false
                                onCanceled: dragMouse.moveStarted = false
                            }
                        }

                        Rectangle {
                            width: 26
                            height: 26
                            radius: 6
                            color: Theme.surfaceActive
                            Layout.alignment: Qt.AlignVCenter
                            Text {
                                anchors.centerIn: parent
                                text: dialogRoot.dlgTypeIcon
                                font.pixelSize: 12
                                font.family: Theme.fontFamily
                                color: Theme.accent
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0
                            Text {
                                text: dlg ? `#${dlg.id}` : ""
                                color: Theme.fg
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                                font.family: Theme.fontFamily
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: dlg ? dialogRoot.dlgApiName : ""
                                color: Theme.fgDim
                                font.pixelSize: Theme.fontSize - 2
                                font.family: Theme.fontFamily
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        AppButton {
                            icon: ""
                            width: 26
                            height: 26
                            pixelSize: 11
                            cornerRadius: 6
                            outlined: true
                            hoverFg: Theme.danger
                            tooltipText: "Close (Esc)"
                            Layout.alignment: Qt.AlignVCenter
                            onClicked: {
                                if (viewer)
                                    viewer.requestClose();
                            }
                        }
                    }

                    // Meta strip: dims • ext • status (WallpaperPanel pill parity).
                    Rectangle {
                        width: parent.width
                        implicitHeight: metaRow.implicitHeight + 12
                        radius: 6
                        color: Theme.bg
                        RowLayout {
                            id: metaRow
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6
                            Text {
                                text: dialogRoot.dlgDims
                                color: Theme.fg
                                font.pixelSize: Theme.fontSize - 2
                                font.family: Theme.fontFamily
                            }
                            Text {
                                text: "•"
                                color: Theme.fgDim
                                font.pixelSize: Theme.fontSize - 2
                            }
                            Text {
                                text: dialogRoot.dlgExt
                                color: Theme.accent
                                font.pixelSize: Theme.fontSize - 2
                                font.bold: true
                                font.family: Theme.fontFamily
                            }
                            Item {
                                Layout.fillWidth: true
                                height: 1
                            }
                            Text {
                                text: dialogRoot.dlgDownloaded ? "● Saved" : (dialogRoot.dlgLoading ? "○ Downloading…" : "○ Preview")
                                color: dialogRoot.dlgDownloaded ? "lightgreen" : Theme.fgDim
                                font.pixelSize: Theme.fontSize - 2
                                font.family: Theme.fontFamily
                            }
                        }
                    }

                    // Tags section (BooruSettingsPanel chip parity + expand).
                    Column {
                        width: parent.width
                        spacing: 4
                        RowLayout {
                            width: parent.width
                            spacing: 6
                            Text {
                                text: `TAGS (${dialogRoot.dlgTags.length})`
                                color: Theme.fgDim
                                font.pixelSize: Theme.fontSize - 2
                                font.bold: true
                                font.family: Theme.fontFamily
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            AppButton {
                                icon: dialogRoot.showAllTags ? "" : ""
                                width: 24
                                height: 22
                                pixelSize: 10
                                cornerRadius: 4
                                outlined: true
                                tooltipText: dialogRoot.showAllTags ? "Show fewer" : "Show all tags"
                                visible: dialogRoot.dlgTags.length > 12
                                onClicked: dialogRoot.showAllTags = !dialogRoot.showAllTags
                            }
                        }
                        Rectangle {
                            width: parent.width
                            implicitHeight: tagFlow.implicitHeight + 12
                            radius: 6
                            color: Theme.bg
                            Flow {
                                id: tagFlow
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4
                                Repeater {
                                    model: dlg ? dialogRoot.dlgTags.slice(0, dialogRoot.dlgVisibleTagCount) : []
                                    delegate: Rectangle {
                                        width: tagDetail.implicitWidth + 14
                                        height: 22
                                        radius: 11
                                        color: tagDetailMa.containsMouse ? Theme.surfaceActive : Theme.surface
                                        border.color: Theme.border
                                        border.width: 1
                                        Text {
                                            id: tagDetail
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: Theme.fgDim
                                            font.pixelSize: Theme.fontSize - 2
                                            font.family: Theme.fontFamily
                                            elide: Text.ElideRight
                                        }
                                        AppTooltip {
                                            visible: tagDetailMa.containsMouse
                                            text: "Click: copy • Hold: add to search"
                                        }
                                        MouseArea {
                                            id: tagDetailMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (viewer)
                                                    viewer.copyTag(modelData);
                                            }
                                            onPressAndHold: {
                                                if (viewer)
                                                    viewer.openTags(modelData);
                                            }
                                        }
                                    }
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "No tags"
                                color: Theme.fgDim
                                font.pixelSize: Theme.fontSize - 2
                                font.family: Theme.fontFamily
                                font.italic: true
                                visible: dialogRoot.dlgTags.length === 0
                            }
                        }
                        Text {
                            width: parent.width
                            text: `+${dialogRoot.dlgTags.length - dialogRoot.dlgVisibleTagCount} more — click the expand icon`
                            color: Theme.fgDim
                            font.pixelSize: Theme.fontSize - 3
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            visible: !dialogRoot.showAllTags && dialogRoot.dlgTags.length > dialogRoot.dlgVisibleTagCount
                        }
                    }

                    // Actions (WaifuWidget section parity: 2-col grids of
                    // fillWidth buttons).
                    RowLayout {
                        width: parent.width
                        spacing: 6
                        AppButton {
                            Layout.fillWidth: true
                            height: 30
                            icon: dialogRoot.dlgBookmarked ? "" : ""
                            text: dialogRoot.dlgBookmarked ? "Saved" : "Save"
                            toggle: true
                            checked: dialogRoot.dlgBookmarked
                            outlined: true
                            pixelSize: Theme.fontSize - 2
                            tooltipText: dialogRoot.dlgBookmarked ? "Remove bookmark" : "Bookmark this post"
                            onClicked: {
                                if (viewer && dlg)
                                    viewer.toggleBookmark(dlg);
                            }
                        }
                        AppButton {
                            Layout.fillWidth: true
                            height: 30
                            icon: "\uf08d"
                            text: dialogRoot.dlgPinned ? "Pinned" : "Pin"
                            toggle: true
                            checked: dialogRoot.dlgPinned
                            outlined: true
                            pixelSize: Theme.fontSize - 2
                            // Pin auto-enables once fetchOriginal() lands the full file
                            // in <api>/images/ (no manual download step).
                            enabled: dialogRoot.dlgDownloaded && !dialogRoot.dlgIsVideo && !dialogRoot.dlgIsZip
                            tooltipText: dialogRoot.dlgIsVideo || dialogRoot.dlgIsZip ? "Cannot pin videos" : !dialogRoot.dlgDownloaded ? "Downloading full image…" : dialogRoot.dlgPinned ? "Unpin from terminal" : "Pin to terminal"
                            onClicked: {
                                if (viewer && dlg)
                                    viewer.togglePinned(dlg);
                            }
                        }
                    }
                    // Full file auto-downloads on open; Waifu takes the full row.
                    AppButton {
                        width: parent.width
                        height: 30
                        icon: ""
                        text: dialogRoot.dlgIsWaifu ? "Waifu ✓" : "Waifu"
                        toggle: true
                        checked: dialogRoot.dlgIsWaifu
                        outlined: true
                        pixelSize: Theme.fontSize - 2
                        tooltipText: dialogRoot.dlgIsWaifu ? "Current waifu" : "Set as waifu"
                        onClicked: {
                            if (viewer && dlg)
                                viewer.setAsWaifu(dlg);
                        }
                    }
                    // Save the full file into ~/.config/wallpapers/custom
                    // (thumbnail included) for the Wallpaper switcher.
                    // Needs the auto-downloaded full file, like Pin —
                    // videos play as animated wallpapers, only zips excluded.
                    AppButton {
                        width: parent.width
                        height: 30
                        icon: ""
                        text: "Wallpaper"
                        outlined: true
                        pixelSize: Theme.fontSize - 2
                        enabled: dialogRoot.dlgDownloaded && !dialogRoot.dlgIsZip
                        tooltipText: dialogRoot.dlgIsZip ? "Cannot use this file type as wallpaper" : !dialogRoot.dlgDownloaded ? "Downloading full image…" : "Save to wallpapers folder"
                        onClicked: {
                            if (viewer && dlg)
                                viewer.saveAsWallpaper(dlg);
                        }
                    }
                    RowLayout {
                        width: parent.width
                        spacing: 6
                        AppButton {
                            Layout.fillWidth: true
                            height: 28
                            icon: ""
                            text: "Open"
                            outlined: true
                            pixelSize: Theme.fontSize - 2
                            tooltipText: "Open post in browser"
                            onClicked: {
                                if (viewer && dlg)
                                    viewer.openInBrowser(dlg);
                            }
                        }
                        AppButton {
                            Layout.fillWidth: true
                            height: 28
                            icon: ""
                            text: "Copy ID"
                            outlined: true
                            pixelSize: Theme.fontSize - 2
                            tooltipText: "Copy post ID"
                            onClicked: {
                                if (viewer && dlg)
                                    viewer.copyTag(String(dlg.id));
                            }
                        }
                    }
                } // sheetContent
            } // sheet flickable

            // Resize cell overlay at the sheet's bottom-right corner
            // (aspect-locked via the viewer). Absolute — not a layout
            // row — so no space is reserved and no Close is duplicated.
            Item {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 4
                width: 16
                height: 16
                Repeater {
                    model: 3
                    Rectangle {
                        width: 3
                        height: 3
                        radius: 1.5
                        color: Theme.fgDim
                        x: 12 - index * 4
                        y: 12 - index * 4
                    }
                }
                MouseArea {
                    id: resizeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SizeFDiagCursor
                    property point last
                    AppTooltip {
                        visible: parent.containsMouse
                        text: "Drag to resize (keeps ratio)"
                    }
                    onPressed: mouse => {
                        resizeMouse.last = Qt.point(mouse.x, mouse.y);
                    }
                    onPositionChanged: mouse => {
                        if (!resizeMouse.pressed)
                            return;
                        const dx = mouse.x - resizeMouse.last.x;
                        const dy = mouse.y - resizeMouse.last.y;
                        resizeMouse.last = Qt.point(mouse.x, mouse.y);
                        if (viewer)
                            viewer.resizeFloat(dx, dy);
                    }
                }
            }
        } // bottomSheet
    } // slider

    Keys.onEscapePressed: {
        if (viewer)
            viewer.requestClose();
    }
    focus: visible
}
