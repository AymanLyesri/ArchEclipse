import QtQuick
import Quickshell
import qs.theme
import qs.services

// Results panel for the search island — port of AppLauncher.tsx results list.
// Shown inside a PopupWindow parented to the bar window while state==search.
Rectangle {
    id: root

    width: 520
    height: 360   // fixed; ListView scrolls inside (childrenRect feedback loop avoided)
    radius: Theme.radius
    color: Theme.moduleBg
    visible: true   // popup visibility driven by BarState.state; content switches help/results

    // ---- help tips (shown when query empty) — mirrors Help{} in AGS ----
    readonly property var helpItems: [
        { cmd: "cb ...", desc: "clipboard history" },
        { cmd: "note ...", desc: "add/list notes" },
        { cmd: "apps ...", desc: "list all applications" },
        { cmd: "emoji ...", desc: "search emojis" },
        { cmd: "... ...", desc: "open with argument" },
        { cmd: "translate .. > ..", desc: "translate (en,fr,es,de,pt,ru,ar…)" },
        { cmd: "... .com", desc: "open link" },
        { cmd: "..*/+-..", desc: "arithmetics" },
        { cmd: "100c to f / 10kg in lb", desc: "unit conversion" }
    ]

    Text {
        id: emptyHint
        visible: Launcher.results.length === 0 && Launcher.lastQuery === ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.margins: 14
        text: "Type to search apps, or try a command below"
        color: Theme.secondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    ListView {
        id: content
        anchors.fill: parent
        anchors.margins: 8
        clip: true
        model: Launcher.results.length > 0 ? Launcher.results : root.helpItems
        currentIndex: Launcher.selectedIndex
        spacing: 2

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index

            width: content.width
            height: 40
            radius: Theme.radius - 2
            color: content.currentIndex === index ? Theme.buttonCheckedBg : "transparent"

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                Text {
                    width: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.icon || ""
                    color: content.currentIndex === index ? Theme.buttonCheckedFg : Theme.foreground
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
                        text: row.modelData.name || row.modelData.cmd || ""
                        color: content.currentIndex === index ? Theme.buttonCheckedFg : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                        font.bold: content.currentIndex === index
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        visible: !!(row.modelData.description || row.modelData.desc)
                        text: row.modelData.description || row.modelData.desc || ""
                        color: content.currentIndex === index ? Qt.alpha(Theme.buttonCheckedFg, 0.7) : Theme.foregroundSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: Launcher.selectedIndex = row.index
                onClicked: {
                    if (row.modelData.launch) {
                        row.modelData.launch();
                        BarState.deactivate("search");
                    }
                }
            }
        }
    }

    // keyboard nav comes from SearchBar's signals via the bar stack
    Connections {
        target: BarState
        function onStateChanged() { if (BarState.state === "search") { Launcher.lastQuery = ""; Launcher.results = []; } }
    }
}
