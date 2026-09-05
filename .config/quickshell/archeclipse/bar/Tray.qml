import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.theme

// Port of Utilities.tsx Tray() — first 3 items inline, overflow behind a
// "more" icon with popup showing hidden items (MAX_VISIBLE=3).
Row {
    id: root
    spacing: 2

    readonly property int maxVisible: 3

    // Visible items
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

    // Overflow button (AGS tray-overflow) — shows when items > maxVisible
    Item {
        id: overflow
        visible: SystemTray.items.values.length > root.maxVisible
        width: 20; height: 20

        IconImage {
            anchors.centerIn: parent
            width: 12; height: 12
            source: "view-more-symbolic"
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: overflowPopup.open()
            cursorShape: Qt.PointingHandCursor

            ToolTip.visible: hovered
            ToolTip.text: "More icons"
        }

        // Popup with hidden items (AGS tray-popover)
        Popup {
            id: overflowPopup
            parent: root
            y: overflow.height + 6
            x: overflow.x - overflowPopup.implicitWidth / 2 + overflow.width / 2
            padding: 6
            closePolicy: Popup.CloseOnPressOutside
            background: Rectangle { color: Theme.moduleBg; radius: 8; border.color: Theme.border }

            Column {
                spacing: 4
                Repeater {
                    model: SystemTray.items.values.slice(root.maxVisible)
                    delegate: Item {
                        id: hiddenEntry
                        required property var modelData
                        width: 160; height: 28

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton)
                                    modelData.activate();
                                else if (modelData.hasMenu)
                                    hiddenMenu.open();
                            }
                        }

                        Row {
                            anchors.fill: parent
                            spacing: 8
                            anchors.margins: 6

                            IconImage {
                                width: 16; height: 16
                                source: modelData.icon
                            }
                            Text {
                                text: modelData.tooltip_text
                                font.pixelSize: Theme.fontSize
                                color: Theme.foreground
                                elide: Text.ElideRight
                            }
                        }

                        QsMenuAnchor {
                            id: hiddenMenu
                            menu: modelData.menu
                            anchor.item: hiddenEntry
                            anchor.edges: Edges.Right
                        }
                    }
                }
            }
        }
    }
}
