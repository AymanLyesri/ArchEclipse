import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.widgets.launcher

// Search island: input + launcher results inline in the bar pill.
// Replaces the old PopupWindow launcher — the pill grows (width via the
// existing pill spring, height snapped on the window) while the results
// body unfolds with a spring.
Column {
    id: root
    width: 516
    spacing: 8

    signal queryChanged(string query)
    signal activateRequested
    signal navigateRequested(int direction)

    // Spring driver: 0 -> 1 on creation unfolds the results body.
    property real expand: 0
    property int bodyFullHeight: 448
    Component.onCompleted: expand = 1
    Behavior on expand {
        SpringAnimation {
            spring: 3.5
            damping: 0.32
            mass: 1.0
        }
    }

    // Search input pill (was SearchBar — merged here, its only consumer).
    // Typing, Enter (activate hook), Up/Down (navigate hook), Esc (close).
    Rectangle {
        id: searchInput
        width: parent.width
        height: 30
        radius: Theme.radius
        color: Theme.surface

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 12
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
                    BarState.deactivate("search");
            }

            Keys.onEscapePressed: BarState.deactivate("search")
            Keys.onDownPressed: {
                root.navigateRequested(1);
                Launcher.selectNext(1);
            }
            Keys.onUpPressed: {
                root.navigateRequested(-1);
                Launcher.selectNext(-1);
            }

            // focus grab must wait one event-loop turn — the loader creates this
            // page before the layer surface gets keyboard interactivity
            Timer {
                interval: 50
                running: true
                onTriggered: input.forceActiveFocus()
            }
        }

        // keep focus while the search island is open (clicks elsewhere shouldn't
        // strand the caret)
        Connections {
            target: BarState
            function onStateChanged() {
                if (BarState.state === "search") {
                    input.text = "";
                    input.forceActiveFocus();
                }
            }
        }

        // Navigation rows (">" tips like "cb ...") adopt their query into the
        // box so typing continues from that format. Programmatic set doesn't
        // emit textEdited, so the runQuery from the row's launch isn't doubled.
        Connections {
            target: Launcher
            function onFillInputRequested(query) {
                input.text = query;
                input.cursorPosition = input.text.length;
                input.forceActiveFocus();
            }
        }

        // blinking caret placeholder hint when empty
        Text {
            visible: input.text === "" && !input.focus
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 12
            text: "Search…"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    Item {
        id: bodyClip
        width: parent.width
        height: Math.max(0, root.expand * root.bodyFullHeight)
        clip: true
        opacity: Math.max(0, Math.min(1, root.expand * 1.2))
        scale: 0.96 + 0.04 * root.expand
        transformOrigin: Item.Top

        LauncherPanel {
            anchors.top: parent.top
            width: parent.width
            height: root.bodyFullHeight
        }
    }
}
