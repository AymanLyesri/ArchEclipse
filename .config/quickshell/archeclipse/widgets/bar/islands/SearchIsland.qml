import QtQuick
import qs.theme
import qs.services
import qs.widgets.shared
import qs.widgets.bar.islands
import qs.widgets.launcher

// Search island: input + launcher results inline in the bar pill - the pill grows (width via
// the pill transition, height snapped) while the results body unfolds.
Column {
    id: root
    width: 528
    spacing: Theme.spaceSm
    property string monitorName: ""

    signal queryChanged(string query)
    signal activateRequested
    signal navigateRequested(int direction)

    // Expand driver: 0 -> 1 on creation unfolds the results body.
    property real expand: 0
    property int bodyFullHeight: 448
    Component.onCompleted: expand = 1

    // Keyboard nav (input's Up/Down) scrolls the results list with the selection.
    Connections {
        target: root
        function onNavigateRequested(direction) {
            resultsPanel.ensureVisible(direction);
        }
    }

    // Search input well: same translucent recess as the results panel, so input and
    // body read as one sunken field over the pill plate.
    Rectangle {
        id: searchInput
        width: parent.width
        height: 36
        radius: Theme.radius
        color: Theme.rgba(Theme.surfaceRaised, 0.35)

        // Magnifier glyph: fgDim at rest, accent once a query is live.
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.search
            color: input.text !== "" ? Theme.accent : Theme.fgDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge
            Behavior on color {
                CAnim {}
            }
        }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 34
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            clip: true
            focus: true

            onTextEdited: {
                root.queryChanged(text);
                Launcher.runQueryDebounced(text);
            }
            onAccepted: {
                root.activateRequested();
                // Navigation rows (">" tips) and info rows keep the
                // launcher open; real launches close it.
                if (!Launcher.activateSelected())
                    BarState.deactivate("search", root.monitorName);
            }

            Keys.onEscapePressed: BarState.deactivate("search", root.monitorName)
            Keys.onDownPressed: {
                root.navigateRequested(1);
                Launcher.selectNext(1);
            }
            Keys.onUpPressed: {
                root.navigateRequested(-1);
                Launcher.selectNext(-1);
            }

            // focus grab must wait one event-loop turn - the loader creates this
            // page before the layer surface gets keyboard interactivity
            Timer {
                interval: 50
                running: true
                onTriggered: input.forceActiveFocus()
            }
        }

        // Keep the caret alive while the search island is open: a widget click elsewhere in the
        // bar no longer closes the launcher, so focus has to be restored instead. The query is
        // never cleared here: every island pulse (a media/screenshot pill reacting to that same
        // click) fires this signal too, and clearing wiped a live query.
        Connections {
            target: BarState
            function onPanelStatesByMonitorChanged() {
                if (BarState.isOpenFor("search", root.monitorName))
                    input.forceActiveFocus();
            }
        }

        // Navigation rows adopt their query into the box so typing continues from that format;
        // setting it programmatically avoids textEdited, so the row's runQuery isn't doubled.
        Connections {
            target: Launcher
            function onFillInputRequested(query) {
                input.text = query;
                input.cursorPosition = input.text.length;
                input.forceActiveFocus();
            }
        }

        // Placeholder rides beside the caret while the box is empty -
        // every launcher shows it focused-empty, so the !focus gate is gone.
        Text {
            visible: input.text === ""
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 34
            text: "Search\u2026"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    IslandExpandClip {
        expand: root.expand
        contentHeight: root.bodyFullHeight

        LauncherPanel {
            id: resultsPanel
            anchors.top: parent.top
            width: parent.width
            height: root.bodyFullHeight
            monitorName: root.monitorName
        }
    }
}
