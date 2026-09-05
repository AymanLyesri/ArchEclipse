//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.bar
import qs.services

// ArchEclipse shell — multi-monitor via Variants over Quickshell.screens.
// Each window is instantiated once per monitor (matching AGS perMonitorDisplay).
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

    // per-monitor bar (the main reference implementation)
    Variants {
        model: Quickshell.screens
        Bar {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    // per-monitor bar edge-hover strip (dwell-reveals the auto-hidden bar)
    Variants {
        model: Quickshell.screens
        BarHoverWindow {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    // per-monitor always-on widget (weather card, bottom-left)
    Variants {
        model: Quickshell.screens
        AlwaysOnWidget {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    // per-monitor wallpaper switcher (bottom overlay)
    Variants {
        model: Quickshell.screens
        WallpaperSwitcher {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    // per-monitor user panel (full-screen power grid overlay)
    Variants {
        model: Quickshell.screens
        UserPanel {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    // per-monitor control panel (quick-settings sidebar)
    Variants {
        model: Quickshell.screens
        ControlPanel {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    // Left panel (SUPER+L, hot-zone, IPC)
    Variants {
        model: Quickshell.screens
        LeftPanel {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    // Right panel (SUPER+R, hot-zone, IPC)
    Variants {
        model: Quickshell.screens
        RightPanel {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    // per-monitor keystroke visualizer overlay
    Variants {
        model: Quickshell.screens
        KeyStrokeVisualizer {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    // per-monitor media window (SUPER+m) — standalone player control
    Variants {
        model: Quickshell.screens
        MediaWindow {
            required property ShellScreen modelData
            screen: modelData
        }
    }
}
