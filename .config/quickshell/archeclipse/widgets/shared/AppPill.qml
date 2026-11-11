import QtQuick
import qs.theme

// Minimalist togglable pill/chip.
//
// Three render states:
//   active=true   — accent-washed fill, accent bold text
//   strike=true   — dim text with strikethrough decoration (previously removed)
//   neither       — raised fill, dim text (idle/removable) — fill instead of a hairline
Item {
    id: root

    property string text: ""
    property bool active: false
    // When true the tag was previously active/removed and should show a
    // strikethrough line so the user can distinguish it from a fresh idle pill.
    property bool strike: false
    property bool removable: false
    property bool enabled: true
    property string tooltipText: ""
    property int pixelSize: Theme.fontSizeSmall
    property real cornerRadius: Theme.radius

    signal clicked()
    signal removed()

    readonly property real pHeight: Theme.fontSize + 16
    readonly property real hPad: 10

    // Size to content so each pill matches its own text width.
    implicitWidth: label.implicitWidth + hPad * 2
    implicitHeight: pHeight

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.active ? Theme.surfaceActive : (hoverArea.containsMouse ? Theme.surfaceRaised : Theme.rgba(Theme.fg, 0.04))
        opacity: root.enabled ? 1 : Theme.opacity.disabled
        Behavior on color { CAnim {} }

        Row {
            anchors.centerIn: parent
            spacing: Theme.spaceXs

            Text {
                id: label
                // Rich-text strikethrough: any non-empty `text` gets a
                // `<s>` wrapper when `strike` is true so the decoration
                // only applies here and nowhere else.
                font.family: Theme.fontFamily
                font.pixelSize: root.pixelSize
                font.bold: root.active
                textFormat: root.strike ? Text.RichText : Text.PlainText
                text: root.strike ? "<s>" + root.text + "</s>" : root.text
                color: root.active ? Theme.accent : (root.strike ? Theme.fgDim : Theme.muted)
                Behavior on color { CAnim {} }
            }

            AppTooltip {
                visible: hoverArea.containsMouse && root.tooltipText !== ""
                text: root.tooltipText
            }

            Rectangle {
                visible: root.removable && !root.active && root.enabled
                width: Theme.fontSize - 2
                height: Theme.fontSize - 2
                radius: width / 2
                color: Theme.fgDim
                Behavior on color { CAnim {} }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.removed()
                }
                Text {
                    anchors.centerIn: parent
                    text: "\u{f55b}"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeCaption
                    color: Theme.bg
                }
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            enabled: root.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
