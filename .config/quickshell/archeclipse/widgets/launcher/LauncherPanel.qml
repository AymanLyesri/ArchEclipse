import QtQuick
import qs.theme
import qs.services
import qs.widgets.shared

// Results panel for the search island: input lives in SearchIsland,
// this body is results only. Empty query shows recent apps (quick-apps
// fallback) via Launcher.defaultResults; helper tips live under bare
// ">" (Launcher.paletteHelp) — no side panes.
Rectangle {
    id: root

    implicitWidth: 500
    implicitHeight: 448
    radius: Theme.radius
    color: Theme.surface

    SmoothListView {
        id: resultsList
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
            height: modelData.isHeader === true ? 28 : ((modelData.actions !== undefined && modelData.actions.length > 0) ? 56 : 52)
            radius: Theme.radius - 2
            color: (modelData.isHeader === true || resultsList.currentIndex !== index) ? "transparent" : Theme.surfaceActive

            // Header row (app_type === "header").
            // NOTE: strict `=== true` — a bare `modelData.isHeader`
            // is undefined for normal rows, and assigning undefined
            // to bool keeps the default (true), painting the header
            // name over every row's icon.
            Row {
                visible: modelData.isHeader === true
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                spacing: 5
                Rectangle {
                    width: 4
                    height: 16
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
                    color: Theme.muted
                }
            }

            // Normal result row — unified AppEntry (real app icons
            // via IconImage, glyphs via Text, letter fallback).
            AppEntry {
                visible: modelData.isHeader !== true

                anchors.left: parent.left
                anchors.right: parent.right

                entry: modelData
                selected: resultsList.currentIndex === index
                rightReserve: (modelData.actions !== undefined && modelData.actions.length > 0) ? 102 : 10
            }

            // Inline action buttons (app_actions)
            Row {
                visible: modelData.isHeader !== true && modelData.actions !== undefined && modelData.actions.length > 0
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: modelData.actions
                    delegate: AppButton {
                        text: modelData.label
                        height: 26
                        pixelSize: Theme.fontSize - 1
                        cornerRadius: 4
                        idleBg: Theme.surface
                        outlined: true
                        tooltipText: modelData.tooltip || modelData.label
                        onClicked: modelData.onClick()
                    }
                }
            }

            // Hover selection + click launch.
            // NOTE: no attached ToolTip here — name/description/args
            // are already fully visible inline via AppEntry, and a
            // second rendering of the name is exactly the
            // "duplicated name" artifact (tooltips can stick on
            // layer-shell surfaces).
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: {
                    if (!modelData.isHeader)
                        Launcher.selectedIndex = index;
                }
                onClicked: {
                    if (!modelData.isHeader && modelData.launch) {
                        const keep = modelData.keepOpen === true;
                        modelData.launch();
                        if (!keep)
                            BarState.deactivate("search");
                    }
                }
            }
        }
    }

    // Prime the default state (recent apps) on creation. The island is
    // instantiated by the bar Loader AFTER BarState.state is already
    // "search", so onStateChanged below never fires for a fresh instance —
    // without this the first open shows an empty list.
    Component.onCompleted: Launcher.runQuery("")

    // keyboard nav comes from SearchIsland signals; reset state on close
    Connections {
        target: BarState
        function onStateChanged() {
            if (BarState.state === "search") {
                Launcher.lastQuery = "";
                Launcher.runQuery("");
            }
        }
    }
}
