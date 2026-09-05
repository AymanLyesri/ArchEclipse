import QtQuick
import Quickshell
import qs.theme
import qs.services

// Port of barStates/SearchBar.tsx — the search "dynamic island" state.
//
// The full AGS search pairs this input with the AppLauncher results popover;
// the results panel lands with the applauncher migration. This component
// provides the input pill: typing, Enter (activate hook), Up/Down (navigate
// hook), Esc (close) — the same key contract, exposed via signals so the
// launcher can consume them when it migrates.
Rectangle {
    id: root

    signal queryChanged(string query)
    signal activateRequested()
    signal navigateRequested(int direction)

    width: 460
    height: 30
    radius: Theme.radius
    color: Theme.moduleBg

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        clip: true
        focus: true

        onTextEdited: { root.queryChanged(text); Launcher.runQueryDebounced(text) }
        onAccepted: { root.activateRequested(); Launcher.activateSelected(); BarState.deactivate("search") }

        Keys.onEscapePressed: BarState.deactivate("search")
        Keys.onDownPressed: { root.navigateRequested(1); Launcher.selectNext(1) }
        Keys.onUpPressed: { root.navigateRequested(-1); Launcher.selectNext(-1) }

        // focus grab must wait one event-loop turn — the loader creates this
        // page before the layer surface gets keyboard interactivity
        Timer { interval: 50; running: true; onTriggered: input.forceActiveFocus() }
    }

    // keep focus while the search island is open (clicks elsewhere shouldn't
    // strand the caret — AGS grabs the keyboard exclusively in legacy mode)
    Connections {
        target: BarState
        function onStateChanged() {
            if (BarState.state === "search") {
                input.text = "";
                input.forceActiveFocus();
            }
        }
    }

    // blinking caret placeholder hint when empty
    Text {
        visible: input.text === "" && !input.focus
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 12
        text: "Search…"
        color: Theme.secondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }
}
