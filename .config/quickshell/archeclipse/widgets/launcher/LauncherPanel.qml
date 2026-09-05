import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.theme
import qs.services
import qs.widgets.bar
import qs.widgets.media

// Results panel for the search island — port of AppLauncher.tsx.
// AGS renders a 3-column launcher: left = media Player card (300),
// center = Help / results (500), right = QuickApps (favorites) + AppHistory.
Rectangle {
    id: root

    implicitWidth: 300 + 500 + 300           // left + center + right
    implicitHeight: Math.max(400, contentColumn.height)
    radius: Theme.radius
    color: Theme.moduleBg

    property int selectedIndex: 0

    // The 3-pane body
    Row {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // ---------- LEFT: media player card ----------
        Rectangle {
            width: 300
            height: parent.height
            radius: Theme.radius - 2
            color: Theme.bg
            clip: true
            MediaWidget {
                anchors.fill: parent
                anchors.margins: 6
            }
        }

        // ---------- CENTER: Help / results ----------
        Rectangle {
            width: 500
            height: parent.height
            radius: Theme.radius - 2
            color: Theme.bg
            clip: true

            // Help tips (mirrors AGS Help{}) — visible when query empty OR no results
            Column {
                id: helpCol
                visible: Launcher.results.length === 0
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 10 }
                spacing: 6
                Text {
                    width: parent.width
                    text: "Commands"
                    font.bold: true
                    font.pixelSize: Theme.fontSize + 2
                    color: Theme.fg
                    visible: helpCol.visible
                }
                Repeater {
                    model: [
                        { cmd: "cb ...", desc: "clipboard history (text/html/image)", keys: ["SUPER","SHIFT","v"] },
                        { cmd: "note ...", desc: "add/list/edit/remove notes", keys: ["SUPER","SHIFT","n"] },
                        { cmd: "apps ...", desc: "list all installed applications", keys: ["SUPER","A"] },
                        { cmd: "emoji ...", desc: "search emojis", keys: ["SUPER","."] },
                        { cmd: "... ...", desc: "open with argument" },
                        { cmd: "translate .. > ..", desc: "translate into (en,fr,es,de,pt,ru,ar…)" },
                        { cmd: "... .com OR https://...", desc: "open link" },
                        { cmd: "..*/+-..", desc: "arithmetics" },
                        { cmd: "100c to f / 10kg in lb", desc: "unit conversion (temp/weight/length/volume/speed/digital)" },
                    ]
                    delegate: Row {
                        width: parent ? parent.width : 0
                        spacing: 8
                        Text {
                            width: parent.width * 0.38
                            text: modelData.cmd
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            color: Theme.accent
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            width: parent.width * 0.46
                            text: modelData.desc
                            font.pixelSize: Theme.fontSize - 1
                            color: Theme.foregroundSecondary
                            wrapMode: Text.WordWrap
                        }
                        Row {
                            visible: !!modelData.keys && modelData.keys.length > 0
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Repeater {
                                model: modelData.keys || []
                                delegate: Rectangle {
                                    width: 18; height: 16
                                    radius: 3
                                    color: Theme.accentBg
                                    border.color: Theme.accent
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 3
                                        color: Theme.accent
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ListView {
                id: resultsList
                visible: Launcher.results.length > 0
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                model: Launcher.results
                currentIndex: Launcher.selectedIndex
                spacing: 2
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: resultsList.width
                    height: modelData.isHeader ? 28 : (modelData.actions && modelData.actions.length > 0 ? 52 : 46)
                    radius: Theme.radius - 2
                    color: (modelData.isHeader || resultsList.currentIndex !== index) ? "transparent" : Theme.buttonCheckedBg

                    // Header row (AGS AppButton app_type === "header")
                    Row {
                        visible: modelData.isHeader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.leftMargin: 12
                        spacing: 5
                        Rectangle {
                            width: 4; height: 16
                            radius: 2
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: modelData.name
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            font.bold: true
                            color: Theme.foregroundSecondary
                        }
                    }

                    // Normal result row
                    Row {
                        visible: !modelData.isHeader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.leftMargin: 10; anchors.rightMargin: modelData.actions && modelData.actions.length > 0 ? 92 : 10
                        spacing: 10
                        Text {
                            width: 24
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.icon || ""
                            color: resultsList.currentIndex === index ? Theme.buttonCheckedFg : Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 4
                            visible: text !== ""
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            width: parent.width - 34
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: modelData.name || ""
                                color: resultsList.currentIndex === index ? Theme.buttonCheckedFg : Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize + 1
                                font.bold: resultsList.currentIndex === index
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                visible: !!(modelData.description)
                                text: modelData.description || ""
                                color: resultsList.currentIndex === index ? Qt.alpha(Theme.buttonCheckedFg, 0.7) : Theme.foregroundSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                visible: !!(modelData.argText)
                                text: modelData.argText || ""
                                color: resultsList.currentIndex === index ? Qt.alpha(Theme.buttonCheckedFg, 0.5) : Theme.foregroundSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }
                    }

                    // Inline action buttons (AGS AppButton app_actions)
                    Row {
                        visible: !modelData.isHeader && modelData.actions && modelData.actions.length > 0
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Repeater {
                            model: modelData.actions
                            delegate: Button {
                                text: modelData.label
                                height: 26
                                padding: 6
                                ToolTip.text: modelData.tooltip || modelData.label
                                onClicked: modelData.onClick()
                                background: Rectangle { color: Theme.moduleBg; radius: 4; border.width: 1; border.color: Theme.border }
                                contentItem: Text { color: Theme.fg; font.pixelSize: Theme.fontSize - 1; anchors.centerIn: parent }
                            }
                        }
                    }

                    // Hover selection + click launch + tooltip
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: {
                            if (!modelData.isHeader) Launcher.selectedIndex = index
                        }
                        onClicked: {
                            if (!modelData.isHeader && modelData.launch) {
                                modelData.launch();
                                BarState.deactivate("search");
                            }
                        }
                        ToolTip.visible: hovered && !modelData.isHeader && modelData.description
                        ToolTip.text: (modelData.name || "") + "\n<b>" + (modelData.description || "") + "</b>"
                    }
                }
            }
        }

        // ---------- RIGHT: QuickApps + AppHistory ----------
        Rectangle {
            width: 300
            height: parent.height
            radius: Theme.radius - 2
            color: Theme.bg
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                // QuickApps (favorites)
                Text {
                    text: "Quick Apps"
                    font.bold: true
                    font.pixelSize: Theme.fontSize + 2
                    color: Theme.fg
                }
                Column {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: Launcher.quickAppOrder.length > 0 ? Launcher.quickAppOrder : []
                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 38
                            radius: Theme.radius - 2
                            color: mouse.hovered ? Theme.buttonHoverBg : "transparent"
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 8
                                spacing: 8
                                Text {
                                    width: 22
                                    text: modelData.icon || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize + 4
                                    color: Theme.fg
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1
                                    width: parent.width - 30
                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: modelData.name || ""
                                        font.pixelSize: Theme.fontSize
                                        color: Theme.fg
                                        font.bold: true
                                    }
                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: modelData.description || ""
                                        font.pixelSize: Theme.fontSize - 2
                                        color: Theme.foregroundSecondary
                                    }
                                }
                            }
                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.launch) {
                                        Launcher.touchQuickApp(modelData.name);
                                        modelData.launch();
                                        BarState.deactivate("search");
                                    }
                                }
                            }
                        }
                    }
                }

                // AppHistory (recent apps)
                Text {
                    text: "Recent Apps"
                    font.bold: true
                    font.pixelSize: Theme.fontSize + 2
                    color: Theme.fg
                    topPadding: 6
                }
                Column {
                    width: parent.width
                    spacing: 4
                    // Empty state (AGS AppHistory "Empty History" label)
                    Text {
                        visible: Launcher.recentApps().length === 0
                        text: "Empty History"
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.foregroundSecondary
                        leftPadding: 8
                    }
                    Repeater {
                        model: Launcher.recentApps()
                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 34
                            radius: Theme.radius - 2
                            color: rmouse.hovered ? Theme.buttonHoverBg : "transparent"
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 8
                                spacing: 8
                                Text {
                                    width: 22
                                    text: modelData.icon || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize + 4
                                    color: Theme.fg
                                }
                                Text {
                                    width: parent.width - 30
                                    elide: Text.ElideRight
                                    text: modelData.name || ""
                                    font.pixelSize: Theme.fontSize
                                    color: Theme.fg
                                }
                            }
                            MouseArea {
                                id: rmouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.launch) {
                                        modelData.launch();
                                        BarState.deactivate("search");
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // keyboard nav comes from SearchBar signals; reset state on close
    Connections {
        target: BarState
        function onStateChanged() {
            if (BarState.state === "search") {
                Launcher.lastQuery = "";
                Launcher.results = [];
            }
        }
    }
}
