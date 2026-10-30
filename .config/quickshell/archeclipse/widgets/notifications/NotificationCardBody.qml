import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets.shared

// Shared notification card body for the popup toast and the history card: display state arrives
// as plain props so both hosts feed it identically, and side effects bubble out as signals.
Column {
    id: root
    spacing: Theme.spacing

    property string iconFile: ""
    property string iconName: ""
    property string previewFile: ""
    property string videoFile: ""
    property string openFile: ""
    property bool isRecorder: false
    property bool critical: false
    property string title: ""
    property string bodyText: ""
    property bool hideBody: true
    property bool longBody: false
    property double stamp: 0
    property var actionItems: []
    property bool controlsVisible: false
    property bool videoActive: true
    property string copyTip: "Copy"
    property string dismissTip: "Dismiss"
    // History expands the body on tap; the popup only via its button
    // (its background owns drag/right-click instead).
    property bool tapToExpand: false
    property bool bodyExpanded: false

    signal openRequested(string path)
    signal copyRequested()
    signal dismissRequested()
    signal actionClicked(var action)

    Row {
        id: contentRow
        width: parent.width
        spacing: Theme.spacing

        // ---- app icon / image: the image takes the icon's
        // place, spanning the text height (72-120px) ----
        Item {
            id: iconSlot
            readonly property bool showPreview: root.previewFile !== "" && previewImg.status !== Image.Error
            readonly property bool showVideo: root.videoFile !== ""
            readonly property bool showMedia: showPreview || showVideo
            readonly property real previewSize: Math.min(Math.max(textCol.height, 72), 120)
            width: showMedia ? previewSize : 28
            height: showMedia ? previewSize : 28
            Behavior on width {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }
            IconImage {
                id: iconImg
                visible: !parent.showMedia && status === Image.Ready && (root.iconFile !== "" || root.iconName !== "")
                anchors.fill: parent
                source: root.iconFile !== "" ? root.iconFile : root.iconName
            }
            Text {
                visible: !iconImg.visible && !parent.showMedia
                width: parent.width
                height: parent.height
                text: root.isRecorder ? "\uf111" : (root.critical ? "\u{F0266}" : "\u{F059A}")
                color: root.isRecorder ? Theme.danger : (root.critical ? Theme.criticalFg : Theme.fg)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(1.83)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            Rectangle {
                visible: parent.showPreview
                opacity: previewImg.status === Image.Ready ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                    }
                }
                anchors.fill: parent
                radius: Theme.radius
                clip: true
                color: Qt.alpha(Theme.fg, 0.06)
                Image {
                    id: previewImg
                    anchors.fill: parent
                    source: root.previewFile !== "" ? "file://" + root.previewFile : ""
                    asynchronous: true
                    cache: false
                    fillMode: Image.PreserveAspectCrop
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openRequested(root.previewFile)
                }
            }
            Rectangle {
                visible: parent.showVideo && !parent.showPreview
                anchors.fill: parent
                radius: Theme.radius
                clip: true
                color: Qt.alpha(Theme.fg, 0.06)
                AppVideo {
                    anchors.fill: parent
                    source: root.videoFile
                    active: visible && root.videoActive
                    muted: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openRequested(root.videoFile)
                }
            }
        }

        Column {
            id: textCol
            width: (root.previewFile !== "" || root.videoFile !== "") ? parent.width - 128 : parent.width - 36
            Behavior on width {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }
            spacing: 3

            // ---- top bar: title + time (24h %H:%M) ----
            RowLayout {
                spacing: Theme.spacing
                width: parent.width
                Text {
                    text: root.title
                    textFormat: Text.StyledText
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    color: root.critical ? Theme.criticalFg : Theme.fg
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fontSize
                }
                Text {
                    text: root.stamp > 0 ? new Date(root.stamp * 1000).toLocaleTimeString([], {
                        hour: "2-digit",
                        minute: "2-digit",
                        hour12: false
                    }) : ""
                    color: root.critical ? Qt.alpha(Theme.criticalFg, Theme.opacity.hoverDim) : Theme.fgDim
                    font.pixelSize: Theme.fontSize - 2
                    visible: text !== ""
                }
            }

            // ---- body (expandable, markup handling) ----
            // Hidden when it is just the image path — the image beside it already shows it.
            Text {
                width: parent.width
                visible: !root.hideBody
                text: root.bodyText
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
                maximumLineCount: root.bodyExpanded ? undefined : 4
                elide: root.bodyExpanded ? Text.ElideNone : Text.ElideRight
                color: root.critical ? Qt.alpha(Theme.criticalFg, Theme.opacity.soft) : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1

                // Tap expand only where the background doesn't own
                // press-drag (history); a disabled TapHandler is inert.
                TapHandler {
                    enabled: root.tapToExpand
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.bodyExpanded = !root.bodyExpanded
                }
                HoverHandler {
                    enabled: root.tapToExpand
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }

    // ---- action buttons (all actions, invoke, NO dismiss) ----
    Row {
        id: actionsRow
        visible: root.actionItems.length > 0
        spacing: 4
        Repeater {
            model: root.actionItems
            delegate: AppButton {
                required property var modelData
                text: Notifications.actionLabel(modelData)
                tooltipText: "Run this action"
                height: 24
                pixelSize: Theme.fontSize - 2
                cornerRadius: 4
                idleBg: Theme.surface
                outlined: true
                onClicked: root.actionClicked(modelData)
            }
        }
    }

    // ---- control buttons: open, copy, expand, dismiss ----
    Row {
        id: buttonsRow
        visible: root.controlsVisible
        opacity: root.controlsVisible ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }
        spacing: Theme.spacing
        AppButton {
            icon: ""
            pixelSize: Theme.fontSizeSmall
            cornerRadius: Theme.radius
            idleBg: Theme.surface
            outlined: true
            tooltipText: root.openFile
            visible: root.openFile !== ""
            onClicked: root.openRequested(root.openFile)
        }
        AppButton {
            icon: "󰃅"
            pixelSize: Theme.fontSizeSmall
            cornerRadius: Theme.radius
            idleBg: Theme.surface
            outlined: true
            tooltipText: root.copyTip
            onClicked: root.copyRequested()
        }
        AppButton {
            icon: root.bodyExpanded ? "󰁾" : "󰁼"
            pixelSize: Theme.fontSizeSmall
            cornerRadius: Theme.radius
            idleBg: Theme.surface
            outlined: true
            tooltipText: root.bodyExpanded ? "Collapse" : "Expand"
            visible: root.longBody
            onClicked: root.bodyExpanded = !root.bodyExpanded
        }
        AppButton {
            icon: "󰀍"
            pixelSize: Theme.fontSizeSmall
            cornerRadius: Theme.radius
            idleBg: Theme.surface
            outlined: true
            tooltipText: root.dismissTip
            onClicked: root.dismissRequested()
        }
    }
}
