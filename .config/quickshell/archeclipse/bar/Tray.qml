import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.theme

// Port of Utilities.tsx Tray() — first 3 items inline, overflow behind a
// "more" icon. Left-click activates the item (menu via onlyMenu behavior),
// scroll adjusts like the AGS menubutton default.
Row {
    id: root
    spacing: 2

    readonly property int maxVisible: 3

    Repeater {
        model: SystemTray.items.values.slice(0, root.maxVisible)

        Item {
            id: entry
            required property var modelData
            width: 20; height: 20

            IconImage {
                anchors.centerIn: parent
                width: 14; height: 14
                source: entry.modelData.icon
                asynchronous: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton)
                        entry.modelData.activate();
                    else if (mouse.button === Qt.MiddleButton)
                        entry.modelData.secondaryActivate?.();
                    else if (entry.modelData.hasMenu)
                        menu.open();
                }
                onWheel: (wheel) => entry.modelData.scroll(wheel.angleDelta.y > 0, false)
            }

            QsMenuAnchor {
                id: menu
                menu: entry.modelData.menu
                anchor.item: entry
                anchor.edges: Edges.Bottom
            }
        }
    }
}
