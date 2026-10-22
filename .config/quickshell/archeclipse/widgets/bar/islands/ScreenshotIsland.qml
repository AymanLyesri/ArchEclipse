import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services
import qs.widgets.bar.islands

// Screenshot island — idle-only stadium mirroring the record pill (width
// hugs its content): screenshot indicator on the left, fullscreen / area
// buttons after it.
// Every click spawns ~/.config/hypr/scripts/screenshot.sh detached
// (CustomScriptsWidget precedent). Deliberately: no hover-driven width
// animation, no hover machinery, no hover-toggled visuals — hover-coupled
// resizes churn hover re-evaluation and flap the reveal (probe-proven on
// the record pill; see RecordingIsland).
Item {
    id: root
    // Expand driver: 0 -> 1 on creation unfolds the body; the Bar
    // exit driver plays 1 -> 0 on close before swapping content.
    property real expand: 0
    Component.onCompleted: expand = 1

    property string monitorName: ""

    // pill hugs its content: camera cell + two 20px buttons + 16px gutters
    readonly property real idleW: idleRow.implicitWidth + 16
    property real pillW: idleW
    implicitWidth: pillW
    implicitHeight: clip.height
    width: implicitWidth
    height: implicitHeight

    // spawn via a plain Process — execDetached silently never launched the
    // script here (probe-proven: shoot() fired, no PNG); the ScreenRecorder
    // Process pattern reports failure through onExited instead
    property Process _shotProc: Process {
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: code => {
            const detail = ((_shotProc.stderr.text ?? "") + " " + (_shotProc.stdout.text ?? "")).trim();
            console.warn("[ScreenshotIsland] shot exited (" + code + "): " + detail);
            if (code !== 0 && detail !== "")
                Notifications.send("Screenshot Error", detail);
        }
    }

    function shoot(mode) {
        const arg = mode === "area" ? "--area" : "--now";
        _shotProc.command = [Quickshell.env("HOME") + "/.config/hypr/scripts/screenshot.sh", arg, "--monitor", root.monitorName];
        _shotProc.running = true;
    }

    // padding click (outside the mode buttons) takes a fullscreen shot
    MouseArea {
        anchors.fill: parent
        onClicked: root.shoot("now")
    }

    IslandExpandClip {
        id: clip
        expand: root.expand
        contentHeight: Theme.sidePillHeight

        Rectangle {
            width: root.pillW
            height: Theme.sidePillHeight
            radius: height / 2
            color: Theme.surface

            // camera + buttons content — the camera is a fixed 20px cell
            // (same grid as the buttons), Row centered in the hugging pill
            Row {
                id: idleRow
                anchors.centerIn: parent
                spacing: 4

                Text {
                    width: 20
                    height: 20
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "\u{F030}"   // nf-fa-camera — screenshot indicator
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }

                ModeButton {
                    glyph: "\u{F03E}"  // nf-fa-image — fullscreen shot
                    onClicked: root.shoot("now")
                }
                ModeButton {
                    glyph: "\u{F125}"  // nf-fa-crop — area shot
                    onClicked: root.shoot("area")
                }
            }
        }
    }
}
