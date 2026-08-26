pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services

// Port of services/autoSwitchWorkspace.ts — auto-switch to workspace 10
// when a gaming window appears there, if the setting is enabled.
QtObject {
    id: root

    property bool active: Settings.autoWorkspaceSwitching
    readonly property int gamingWorkspace: 10
    property bool hasSwitchedToGaming: false

    // React to Hyprland client changes
    property Connections _hyprConn: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.startsWith("openwindow") || event.startsWith("closewindow") ||
                event.startsWith("movewindow") || event.startsWith("workspace")) {
                checkGamingWorkspace();
            }
        }
    }

    function checkGamingWorkspace() {
        if (!root.active) return;

        const hasGamingWindow = Hyprland.clients.some(c => c.workspace === root.gamingWorkspace);
        const currentWs = Hyprland.activeWorkspace?.id;

        if (hasGamingWindow && !root.hasSwitchedToGaming && currentWs !== root.gamingWorkspace) {
            Hyprland.messageAsync(`dispatch workspace ${root.gamingWorkspace}`);
            root.hasSwitchedToGaming = true;
        }

        if (!hasGamingWindow) {
            root.hasSwitchedToGaming = false;
        }
    }

    // Re-check when setting changes
    property Connections _settingsConn: Connections {
        target: Settings
        function onAutoWorkspaceSwitchingChanged() {
            root.active = Settings.autoWorkspaceSwitching;
            if (root.active) checkGamingWorkspace();
        }
    }

    Component.onCompleted: checkGamingWorkspace();
}