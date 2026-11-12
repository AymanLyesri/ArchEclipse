import QtQuick
import qs.theme
import qs.services
import qs.widgets.shared

// Results panel for the search island (the input lives in SearchIsland): an empty query shows
// recent apps, and helper tips live under bare ">" (Launcher.paletteHelp) — no side panes.
Rectangle {
    id: root

    implicitWidth: 500
    implicitHeight: 448
    property string monitorName: ""
    // Recessed results well: the pill around it is the surface, so the list sinks into it
    // instead of stacking a second identical plate.
    radius: Theme.radius
    color: Theme.surfaceSunken

    SmoothListView {
        id: resultsList
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        // No outer margin: the bar's Theme.islandPad is the only inset
        // between the pill edge and content (the list used to add 8).
        clip: true
        model: Launcher.results
        // `resultsList.model` in the expression re-evaluates this binding on every results swap
        // (the view overwrites currentIndex itself). See Launcher.setResults for the order.
        currentIndex: resultsList.model, Launcher.selectedIndex
        spacing: 2
        // Keyboard nav: bring the selection into view (mouse hover must not scroll).
        function ensureVisible(dir) {
            if (currentIndex < 0)
                return;
            positionViewAtIndex(currentIndex, dir > 0 ? ListView.End : ListView.Beginning);
        }
        // Sliding selection pill (Caelestia AppList pattern): geometry tracks the current item
        // with expressive easing instead of repainting each delegate's background.
        highlightFollowsCurrentItem: false
        highlight: Rectangle {
            y: resultsList.currentItem ? resultsList.currentItem.y : 0
            width: resultsList.width
            height: resultsList.currentItem ? resultsList.currentItem.height : 0
            radius: Theme.radius
            color: Theme.surfaceOverlay
            Behavior on y {
                Anim {}
            }
            Behavior on height {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }
        delegate: Rectangle {
            required property var modelData
            required property int index
            width: resultsList.width
            height: modelData.isHeader === true ? 30 : ((modelData.actions !== undefined && modelData.actions.length > 0) ? 56 : 52)
            radius: Theme.radius
            color: "transparent"

            // Header row. NOTE: strict `=== true` — a bare isHeader is undefined for normal rows,
            // and undefined->bool keeps the default (true), painting the header over every icon.
            Row {
                visible: modelData.isHeader === true
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                spacing: Theme.spaceSm
                Rectangle {
                    width: 3
                    height: 12
                    radius: Theme.radius
                    color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: String(modelData.name).toUpperCase()
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeCaption
                    font.bold: true
                    font.letterSpacing: 1.2
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
                spacing: Theme.spacing
                Repeater {
                    model: modelData.actions
                    delegate: AppButton {
                        text: modelData.label
                        pixelSize: Theme.typeLabel
                        cornerRadius: Theme.radius
                        idleBg: Theme.surfaceRaised
                        hoverBg: Theme.surfaceOverlay
                        tooltipText: modelData.tooltip || modelData.label
                        onClicked: modelData.onClick()
                    }
                }
            }

            // Hover selection + click launch. No ToolTip: the name is already inline, and tooltips
            // can stick on layer-shell surfaces ("duplicated name" artifact).
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
                        // Drop the search island BEFORE spawning so the bar's Exclusive grab
                        // releases first and the new app receives focus.
                        if (!keep) {
                            BarState.deactivate("search", root.monitorName);
                            Launcher.expectLaunchedWindow();
                        }
                        modelData.launch();
                    }
                }
            }
        }
    }

    // Footer band: keyboard model + result count. It sits below the list so the list owns the
    // whole panel body and the hints never push results around.
    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 30
        color: Qt.alpha(Theme.bg, 0.35)
        radius: Theme.radius

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.pad + 4
            anchors.rightMargin: Theme.pad + 4
            spacing: Theme.spaceSm

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u2191\u2193"
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeCaption
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "navigate"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeCaption
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u21B5"
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeCaption
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "open"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeCaption
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "esc"
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeCaption
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "close"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeCaption
            }

            Item {
                width: Math.max(0, parent.width - 260)
                height: 1
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    let n = 0;
                    const res = Launcher.results || [];
                    for (let i = 0; i < res.length; i++) {
                        if (res[i] && res[i].isHeader !== true)
                            n++;
                    }
                    return n + (n === 1 ? " result" : " results");
                }
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeCaption
            }
        }
    }

    // Prime recents on creation: the island is built after the state is already "search", so
    // onStateChanged never fires. Consume Launcher.pendingQuery here, or presets land on recents.
    function applyPendingOrDefault() {
        if (Launcher.pendingQuery !== "") {
            const q = Launcher.pendingQuery;
            Launcher.pendingQuery = "";
            Launcher.fillInputRequested(q);
            Launcher.runQuery(q);
        } else {
            Launcher.runQuery("");
        }
    }
    // Search-open tracker: the default push is correct only when the island OPENS. Other
    // panelStatesByMonitor mutations must not widen it — the 2s isRecording lag clobbered presets.
    property bool _searchOpen: false
    Component.onCompleted: {
        root._searchOpen = BarState.isOpenFor("search", root.monitorName);
        applyPendingOrDefault();
    }

    // keyboard nav comes from SearchIsland signals; reset state on close
    Connections {
        target: BarState
        function onPanelStatesByMonitorChanged() {
            const open = BarState.isOpenFor("search", root.monitorName);
            if (open && !root._searchOpen) {
                Launcher.lastQuery = "";
                root.applyPendingOrDefault();
            }
            root._searchOpen = open;
        }
    }
}
