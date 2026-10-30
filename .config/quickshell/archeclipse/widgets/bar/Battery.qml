import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.theme

// Battery icon + % (hidden with no battery); click opens the power-profiles popover
// (`powerprofilesctl list` + set). Tooltip shows "Battery: % \nProfile: X".
Rectangle {
    id: root
    width: visible ? content.width + 8 : 0
    height: Theme.barContentHeight
    radius: Theme.radius
    color: hover.hovered || batteryPop.visible ? Theme.surfaceHover : "transparent"

    readonly property real pct: UPower.displayDevice?.percentage ?? 1
    readonly property bool present: UPower.displayDevice?.isLaptopBattery ?? false
    visible: present

    // ---- power profiles (port of AstalPowerProfiles: profiles list + active) ----
    property var profiles: []                 // ["performance", "balanced", ...]
    property string activeProfile: ""
    property bool profilesLoaded: false

    function refreshProfiles() {
        profilesProc.startedOnce = true;
        activeProc.running = true;
    }

    function setProfile(profile) {
        setProc.command = ["powerprofilesctl", "set", profile];
        setProc.running = true;
        batteryPop.close();
    }

    // parse "powerprofilesctl list" output: "* balanced:" (active) / "  performance:"
    Process {
        id: profilesProc
        property bool startedOnce: false
        command: ["bash", "-c", "powerprofilesctl list 2>/dev/null || true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = profilesProc.stdout.text.split("\n");
                const profs = [];
                for (const line of raw) {
                    const m = line.match(/^\*?\s*(.+):\s*$/);
                    if (m)
                        profs.push(m[1].trim());
                }
                root.profiles = profs;
                root.profilesLoaded = true;
            }
        }
        onExited: {
            if (!profilesProc.startedOnce)
                profilesProc.running = false;
        }
    }
    Process {
        id: activeProc
        command: ["bash", "-c", "powerprofilesctl get 2>/dev/null || true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.activeProfile = activeProc.stdout.text.trim()
        }
    }
    Process {
        id: setProc
        command: []
        stdout: StdioCollector {}
        onExited: refreshProfiles()
    }

    HoverHandler {
        id: hover
    }

    // ---- popover with profiles ----
    Popup {
        id: batteryPop
        x: 0
        y: parent.height + 6
        width: 160
        padding: 6
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            color: Theme.surface
            radius: Theme.radius
            border.color: Theme.border
        }

        Column {
            spacing: Theme.spacing
            width: parent.width
            Repeater {
                model: root.profiles
                delegate: Rectangle {
                    width: parent.width
                    height: 28
                    radius: Theme.radius
                    color: ma.containsMouse ? Theme.surfaceActive : "transparent"
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData + (modelData === root.activeProfile ? "  •" : "")
                        color: modelData === root.activeProfile ? Theme.accent : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: modelData === root.activeProfile
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setProfile(modelData)
                    }
                }
            }
        }
    }

    MouseArea {
        id: toggle
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!root.profilesLoaded)
                root.refreshProfiles();
            batteryPop.open();
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spacing
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                const p = root.pct;
                const charging = UPower.displayDevice?.state === UPowerDeviceState.Charging;
                if (charging)
                    return Icons.batteryCharging;
                return p > 0.9 ? Icons.batteryFull : p > 0.7 ? Icons.batteryHigh : p > 0.5 ? Icons.batteryMedium : p > 0.25 ? Icons.batteryLow : Icons.batteryEmpty;
            }
            color: root.pct < 0.15 ? Theme.danger : Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.floor(root.pct * 100) + "%"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.preferShaping: false
        }
    }
}
