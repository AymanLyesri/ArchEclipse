//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.bar
import qs.services

ShellRoot {
    Ipc {}

    // per-monitor notification popups
    Variants {
        model: Quickshell.screens

        NotificationPopups {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    // per-monitor always-on widget + user panel
    Variants {
        model: Quickshell.screens

        AlwaysOnWidget {
            required property ShellScreen modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens

        WallpaperSwitcher {
            required property ShellScreen modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens

        UserPanel {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property ShellScreen modelData
            screen: modelData
        }
    }
}
