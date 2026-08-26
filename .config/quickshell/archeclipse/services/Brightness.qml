pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Port of services/brightness.ts — manages screen brightness via brightnessctl
// across all available backlight devices.
QtObject {
    id: root

    property real screen: 0
    property bool hasBacklight: false
    property var _devices: []
    property int _primaryMax: 1
    property string _primaryDevice: ""

    // Process for reading current brightness
    property Process _readCurrentProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const val = Number(text.trim()) || 0;
                root.screen = val / root._primaryMax;
                root.hasBacklight = root._devices.length > 0;
            }
        }
    }

    function _updateReadCurrentCommand() {
        if (root._primaryDevice) {
            root._readCurrentProc.command = ["brightnessctl", "--device=" + root._primaryDevice, "get"];
        }
    }

    // Process for initial device detection
    property Process _detectProc: Process {
        command: ["/bin/ls", "-1", "/sys/class/backlight"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._devices = text.trim().split("\n").filter(d => d.length > 0);
                if (root._devices.length > 0) {
                    root._primaryDevice = root._devices[0];
                    _updateReadCurrentCommand();
                    root._maxProc.command = ["brightnessctl", "--device=" + root._primaryDevice, "max"];
                    root._maxProc.running = true;
                }
            }
        }
    }

    // Process for reading max brightness
    property Process _maxProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root._primaryMax = Number(text.trim()) || 1;
                root._readCurrentProc.running = true;
            }
        }
    }

    // Process for setting brightness (reusable)
    property Process _setBrightnessProc: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    console.warn("[Brightness] Failed to set brightness: " + text);
                }
            }
        }
    }

    // Poll brightness every 2 seconds (like AGS)
    property Timer _pollTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root._devices.length > 0) {
                root._readCurrentProc.running = true;
            }
        }
    }

    // Initialize - run detection on startup
    Component.onCompleted: {
        root._detectProc.running = true;
    }

    // Setter for screen property (0-1)
    function setScreen(percent) {
        if (percent < 0) percent = 0;
        if (percent > 1) percent = 1;
        if (Math.abs(root.screen - percent) < 0.001) return;
        if (root._devices.length === 0) return;

        root.screen = percent;
        const targetPercent = Math.floor(percent * 100);

        // Set on all devices sequentially
        for (const dev of root._devices) {
            root._setBrightnessProc.command = ["brightnessctl", "--device=" + dev, "set", targetPercent + "%", "-q"];
            root._setBrightnessProc.running = true;
        }
    }
}