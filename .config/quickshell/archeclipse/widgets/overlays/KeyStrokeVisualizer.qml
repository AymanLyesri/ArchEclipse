import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.theme
import qs.services

// Keystroke Visualizer overlay — port of KeyStrokeVisualizer.tsx
// Reads from /tmp/ags-$USER/keystroke-loop-ags binary via Process+SplitParser
// Displays recent keystrokes in an animated row, auto-hides after 2s inactivity.
// Supports user-configurable anchor + visibility (Settings.keyStrokeVisualizer*)
PanelWindow {
    id: root
    required property ShellScreen screen
    screen: screen

    visible: Settings.keyStrokeVisualizerVisibility && keystrokeList.length > 0 && !root.fullscreenActive
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1

    // AGS gates the visualizer on not being in a fullscreen client.
    readonly property bool fullscreenActive: {
        var fs = false
        const tops = Quickshell.Hyprland ? Quickshell.Hyprland.toplevels : null
        if (tops) {
            const vals = tops.values || []
            for (let i = 0; i < vals.length; i++) {
                if (vals[i].fullscreen) { fs = true; break }
            }
        }
        return fs
    }

    // Anchor mapping — mirrors AGS anchor array parsing
    anchors {
        top: Settings.keyStrokeVisualizerAnchor.indexOf("top") >= 0
        bottom: Settings.keyStrokeVisualizerAnchor.indexOf("bottom") >= 0
        left: Settings.keyStrokeVisualizerAnchor.indexOf("left") >= 0
        right: Settings.keyStrokeVisualizerAnchor.indexOf("right") >= 0
    }
    color: "transparent"
    implicitWidth: Math.max(keystrokeRow.implicitWidth + 20, 100)
    implicitHeight: 28

    readonly property int maxKeystrokes: 5
    readonly property int hideDelay: 2000
    property var keystrokeList: []
    property var hideTimer: null

    function addKeystroke(key) {
        const id = "ks-" + Date.now()
        var list = root.keystrokeList.slice()
        list.push({ id: id, key: key })
        if (list.length > root.maxKeystrokes) {
            list = list.slice(list.length - root.maxKeystrokes)
        }
        root.keystrokeList = list
        resetHideTimer()
    }

    function clearKeystrokes() {
        root.keystrokeList = []
        if (root.hideTimer) {
            root.hideTimer.stop()
            root.hideTimer.destroy()
            root.hideTimer = null
        }
    }

    function resetHideTimer() {
        if (root.hideTimer) {
            root.hideTimer.stop()
            root.hideTimer.destroy()
        }
        root.hideTimer = Qt.createQmlObject(
            'import QtQuick; Timer { interval: ' + root.hideDelay + '; running: true; repeat: false; onTriggered: root.clearKeystrokes() }',
            root)
    }

    // Check if binary exists, then start reading
    Process {
        id: keyCheck
        command: ["bash", "-c", "test -x /tmp/ags-" + Quickshell.env("USER") + "/keystroke-loop-ags && echo ready || echo missing"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: function() {
                if (text.trim() === "ready") {
                    keyReader.running = true
                } else {
                    console.warn("[KeyStrokeVisualizer] Binary not found at /tmp/ags-" + Qt.getenv("USER") + "/keystroke-loop-ags — overlay disabled")
                }
            }
        }
    }

    // Stream keystrokes
    Process {
        id: keyReader
        command: ["/tmp/ags-" + Quickshell.env("USER") + "/keystroke-loop-ags"]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(data) {
                const key = data.trim()
                if (key) root.addKeystroke(key)
            }
        }
    }

    // Visual: row of keystroke badges
    Row {
        id: keystrokeRow
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: root.keystrokeList
            delegate: Rectangle {
                width: ksLabel.implicitWidth + 16
                height: 24
                color: Theme.moduleBg
                radius: 4
                border.width: 1
                border.color: Theme.border

                Text {
                    id: ksLabel
                    anchors.centerIn: parent
                    text: modelData.key
                    color: Theme.fg
                    font.pixelSize: Theme.fontSize - 2
                    font.family: "monospace"
                }

                // Slide-in animation
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }
    }
}