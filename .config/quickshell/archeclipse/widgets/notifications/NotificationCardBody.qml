import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets.shared

// Shared card body: plain props in, signals out, so toast and history feed it identically.
// Media hero, then badge + text, then actions; hover swaps controls in for the timestamp.
Column {
    id: root
    spacing: Theme.spaceSm

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

    readonly property bool hasVideo: root.videoFile !== ""
    readonly property bool hasImage: root.previewFile !== ""
    // Media pulls the eye first: a wide preview reads better than a square thumbnail squeezed
    // against the text, and it gives screenshots their real proportion.
    readonly property bool hasMedia: root.hasVideo || root.hasImage
    readonly property string timeText: root.stamp > 0 ? new Date(root.stamp * 1000).toLocaleTimeString([], {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false
    }) : ""

    // ---- media hero ----
    Rectangle {
        id: hero
        width: parent.width
        height: root.hasMedia ? Math.min(200, Math.round(width * 0.5)) : 0
        visible: root.hasMedia
        radius: Theme.radius
        clip: true
        color: Qt.alpha(Theme.fg, 0.05)

        Image {
            id: previewImg
            anchors.fill: parent
            visible: root.hasImage && status !== Image.Error
            source: root.hasImage ? "file://" + root.previewFile : ""
            asynchronous: true
            cache: false
            fillMode: Image.PreserveAspectCrop
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }
        AppVideo {
            anchors.fill: parent
            visible: root.hasVideo && !previewImg.visible
            source: root.videoFile
            active: visible && root.videoActive
            muted: true
        }
        // A single wash folds the image into the card instead of outlining it.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0.55
                    color: "transparent"
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(0, 0, 0, 0.35)
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openRequested(root.hasImage ? root.previewFile : root.videoFile)
        }
    }

    // ---- identity + text ----
    Row {
        width: parent.width
        spacing: Theme.spaceMd

        // App badge: the icon sits in its own plate so a dark glyph still reads on the card.
        Surface {
            id: badge
            width: 32
            height: 32
            level: 2
            radius: Theme.radius

            IconImage {
                id: badgeIcon
                anchors.fill: parent
                anchors.margins: 6
                visible: (root.iconFile !== "" || root.iconName !== "") && status === Image.Ready
                source: root.iconFile !== "" ? root.iconFile : root.iconName
            }
            Text {
                visible: !badgeIcon.visible
                anchors.centerIn: parent
                text: root.isRecorder ? Icons.record : (root.critical ? Icons.alert : Icons.notification)
                color: root.isRecorder ? Theme.danger : (root.critical ? Theme.criticalFg : Theme.muted)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeSubtitle
            }
        }

        Column {
            width: parent.width - badge.width - Theme.spaceMd
            spacing: Theme.spaceXs

            // Title keeps the full width; time and controls swap places on hover at the same
            // height, so the card body never reflows vertically.
            RowLayout {
                width: parent.width
                spacing: Theme.spaceSm

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    textFormat: Text.StyledText
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    color: root.critical ? Theme.criticalFg : Theme.fg
                    font.family: Theme.fontFamily
                    font.weight: Font.DemiBold
                    font.pixelSize: Theme.typeBody
                }

                Text {
                    text: root.timeText
                    visible: !root.controlsVisible && text !== ""
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeCaption
                }

                Row {
                    spacing: 2
                    visible: root.controlsVisible

                    AppButton {
                        icon: Icons.eye
                        pixelSize: Theme.typeCaption
                        cornerRadius: Theme.radius
                        idleBg: Theme.surfaceHover
                        hoverBg: Theme.surfaceActive
                        hPadding: 6
                        height: 22
                        tooltipText: root.openFile
                        visible: root.openFile !== ""
                        onClicked: root.openRequested(root.openFile)
                    }
                    AppButton {
                        icon: Icons.copy
                        pixelSize: Theme.typeCaption
                        cornerRadius: Theme.radius
                        idleBg: Theme.surfaceHover
                        hoverBg: Theme.surfaceActive
                        hPadding: 6
                        height: 22
                        tooltipText: root.copyTip
                        onClicked: root.copyRequested()
                    }
                    AppButton {
                        icon: root.bodyExpanded ? Icons.chevronUp : Icons.chevronDown
                        pixelSize: Theme.typeCaption
                        cornerRadius: Theme.radius
                        idleBg: Theme.surfaceHover
                        hoverBg: Theme.surfaceActive
                        hPadding: 6
                        height: 22
                        tooltipText: root.bodyExpanded ? "Collapse" : "Expand"
                        visible: root.longBody
                        onClicked: root.bodyExpanded = !root.bodyExpanded
                    }
                    AppButton {
                        icon: Icons.close
                        pixelSize: Theme.typeCaption
                        cornerRadius: Theme.radius
                        idleBg: Theme.surfaceHover
                        hoverBg: Theme.surfaceActive
                        hPadding: 6
                        height: 22
                        tooltipText: root.dismissTip
                        onClicked: root.dismissRequested()
                    }
                }
            }

            // Body sits under the title, indented to the text column, not the badge.
            Text {
                width: parent.width
                visible: !root.hideBody && root.bodyText !== ""
                text: root.bodyText
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
                maximumLineCount: root.bodyExpanded ? undefined : (root.hasMedia ? 2 : 4)
                elide: root.bodyExpanded ? Text.ElideNone : Text.ElideRight
                color: root.critical ? Qt.alpha(Theme.criticalFg, Theme.opacity.soft) : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeLabel
                lineHeight: 1.15

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

            // Actions are the card's second tier: chips on their own row, never mixed with
            // icon controls.
            Row {
                width: parent.width
                spacing: Theme.spaceXs
                visible: root.actionItems.length > 0
                Repeater {
                    model: root.actionItems
                    delegate: AppButton {
                        required property var modelData
                        text: Notifications.actionLabel(modelData)
                        tooltipText: "Run this action"
                        height: 26
                        pixelSize: Theme.typeCaption
                        cornerRadius: Theme.radius
                        idleBg: Theme.surfaceHover
                        hoverBg: Theme.surfaceActive
                        onClicked: root.actionClicked(modelData)
                    }
                }
            }
        }
    }
}
