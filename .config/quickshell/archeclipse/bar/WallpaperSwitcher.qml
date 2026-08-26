import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import qs.theme
import qs.services

// Port of WallpaperSwitcher.tsx — floating overlay: pick a wallpaper for the
// current workspace (or all), reusing the same hypr wallpaper-daemon scripts.
PanelWindow {
    id: root

    required property ShellScreen screen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: Qt.rgba(0, 0, 0, 0.5)
    aboveWindows: true
    visible: false

    property string monitorName: (Hyprland.monitorFor(screen)?.name) ?? ""
    Component.onCompleted: Registry.register(`wallpaper-switcher-${monitorName}`, root)

    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // focus trap for Esc
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.visible = false
        MouseArea { anchors.fill: parent; onClicked: root.visible = false }
    }

    property var wallpapers: ({})          // category -> [paths]
    property var currentWallpapers: []     // per-workspace paths
    readonly property var categories: Object.keys(wallpapers)
    property string selectedCategory: categories[0] ?? ""

    Process {
        id: fetchProc
        command: ["bash", `${Quickshell.env("HOME")}/.config/ags/scripts/get-wallpapers.sh`]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.wallpapers = JSON.parse(text); } catch (e) { console.warn("[Wallpaper]", e); }
            }
        }
    }
    Process {
        id: fetchCurrent
        command: ["bash", `${Quickshell.env("HOME")}/.config/ags/scripts/get-wallpapers.sh`, "--current", root.monitorName]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.currentWallpapers = JSON.parse(text).map(String); } catch (e) {}
            }
        }
    }

    onVisibleChanged: if (visible) { fetchProc.running = true; fetchCurrent.running = true; }

    function setWallpaper(path) {
        Quickshell.execDetached(["bash",
            `${Quickshell.env("HOME")}/.config/hypr/wallpaper-daemon/set-wallpaper.sh`,
            path, monitorName]);
    }
    function reloadDaemon() {
        Quickshell.execDetached(["bash", "-c", `${Quickshell.env("HOME")}/.config/hypr/wallpaper-daemon/reload.sh`]);
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1100)
        height: Math.min(parent.height - 80, 700)
        radius: Theme.radius
        color: Theme.backgroundSecondary
        border.color: Qt.alpha(Theme.foreground, 0.15)

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Row {
                spacing: 8
                Text {
                    text: "Wallpaper Switcher"
                    color: Theme.foreground
                    font.family: Theme.fontFamily; font.bold: true; font.pixelSize: Theme.fontSize + 4
                    anchors.verticalCenter: parent.verticalCenter
                }
                ComboBox {
                    id: catBox
                    model: root.categories
                    editable: false
                    onActivated: root.selectedCategory = root.categories[currentIndex]
                }
                Item { width: 20; height: 1 }
                Button {
                    text: "Reload daemon"
                    onClicked: root.reloadDaemon()
                }
                Button {
                    text: "Close (Esc)"
                    onClicked: root.visible = false
                }
            }

            GridView {
                id: grid
                width: parent.width
                height: parent.height - 50
                clip: true
                cellWidth: 180; cellHeight: 120
                model: root.wallpapers[root.selectedCategory] ?? []

                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    width: grid.cellWidth - 8
                    height: grid.cellHeight - 8
                    radius: 6
                    color: ma.containsMouse ? Theme.buttonHoverBg : Theme.moduleBg
                    border.width: 2
                    border.color: ma.containsMouse ? Theme.foregroundSecondary : "transparent"

                    Image {
                        anchors.fill: parent
                        anchors.margins: 3
                        source: "file://" + root.modelData.replace("/.config/wallpapers/", "/.config/ags/cache/thumbnails/").replace(/\.[^/.]+$/, ".jpg")
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 4
                        text: String(index + 1)
                        color: Theme.foreground
                        font.pixelSize: Theme.fontSize
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setWallpaper(root.modelData)
                    }
                }
            }
        }
    }
}
