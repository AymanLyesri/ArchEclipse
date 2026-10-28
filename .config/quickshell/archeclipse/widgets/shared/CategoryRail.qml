import QtQuick
import qs.theme

// Shared persistent category rail (Settings, Key Binds, …).
//
// Data-driven on purpose: `model` is the same array the section cards
// index into, so a label can never drift from the section title. Entries
// may be strings or { title } objects. `currentIndex` is caller-driven — the
// rail only reports taps through `selected(index)`, exactly like
// IslandSideRail.
//
// Active state = one sliding pill (accent-tinted surface) + a 2px accent
// indicator, the same recipe AppSegmentedControl uses for its selection
// highlight. The pill glides between rows instead of every cell animating
// its own background.
Rectangle {
    id: root

    property var model: []
    property int currentIndex: 0
    signal selected(int index)

    readonly property int inset: Theme.pad
    readonly property int entryHeight: Math.max(28, Theme.fontSize + 16)
    readonly property int entrySpacing: 2
    readonly property int rowWidth: Math.max(0, width - inset * 2)

    color: Theme.surface
    radius: Theme.radius
    border.color: Theme.border
    border.width: 1
    clip: true
    // Hug the entries: a full-height rail would be mostly empty borders on
    // a tall monitor and read as a second content pane.
    implicitHeight: entries.implicitHeight + inset * 2

    function labelAt(index) {
        const entry = root.model[index];
        if (entry === undefined || entry === null)
            return "";
        return typeof entry === "string" ? entry : (entry.title || "");
    }

    Rectangle {
        id: highlight

        visible: root.model.length > 0
        x: root.inset
        // Clamp the index: a stale/out-of-range selection must never park
        // the pill outside the rail (e.g. after a model reload).
        y: root.inset + Math.max(0, Math.min(root.currentIndex, root.model.length - 1)) * (root.entryHeight + root.entrySpacing)
        width: root.rowWidth
        height: root.entryHeight
        radius: Math.max(4, Theme.radius - 4)
        color: Theme.surfaceActive
        Behavior on y {
            Anim {
                type: Anim.FastSpatial
            }
        }
        Behavior on height {
            Anim {
                type: Anim.FastSpatial
            }
        }
        Behavior on color {
            CAnim {}
        }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: Math.min(parent.height - 10, 16)
            radius: 1
            color: Theme.accent
        }
    }

    Column {
        id: entries

        x: root.inset
        y: root.inset
        width: root.rowWidth
        spacing: root.entrySpacing

        Repeater {
            model: root.model

            delegate: Item {
                id: cell

                required property var modelData
                required property int index
                readonly property bool active: index === root.currentIndex

                width: entries.width
                height: root.entryHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Math.max(4, Theme.radius - 4)
                    // Hover wash, not surfaceHover: surfaceHover resolves to
                    // the panel background and would be invisible over the
                    // translucent card surface.
                    color: cell.active ? "transparent" : (hover.hovered ? Theme.rgba(Theme.fg, 0.06) : "transparent")
                    Behavior on color {
                        CAnim {}
                    }
                }

                Text {
                    id: label

                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.labelAt(cell.index)
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: cell.active
                    color: cell.active ? Theme.accent : (hover.hovered ? Theme.fg : Theme.fgDim)
                    Behavior on color {
                        CAnim {}
                    }
                }

                // Only when the column is too narrow for the label (long
                // category names or large uiFontSize), so the full name
                // stays discoverable.
                AppTooltip {
                    visible: hover.containsMouse && label.truncated
                    text: label.text
                }

                MouseArea {
                    id: hover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(cell.index)
                }
            }
        }
    }
}
