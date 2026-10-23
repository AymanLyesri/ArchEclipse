//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.widgets.bar
import qs.widgets.launcher
import qs.widgets.lock
import qs.widgets.media
import qs.widgets.selection
import qs.widgets.welcome

// ArchEclipse shell — multi-monitor via Variants over Quickshell.screens.
// Each window is instantiated once per monitor.
ShellRoot {
    // FileView won't create missing parent dirs, so ensure every cache
    // dir it writes to exists at startup (else writes silently fail).
    property Process _cacheDirsProc: Process {
        command: ["bash", "-c", "mkdir -p \"$HOME/.cache/quickshell/settings\" \"$HOME/.cache/quickshell/booru\" \"$HOME/.cache/coloreclipse\" \"$HOME/.cache/quickshell/launcher\" \"$HOME/.cache/quickshell/launcher/clipboard-images\" \"$HOME/.cache/quickshell/script-timer\" \"$HOME/.cache/quickshell/crypto\" \"$HOME/.cache/quickshell/chatbot\" \"$HOME/.cache/quickshell/auth\" \"$HOME/.cache/quickshell/manga\" \"$HOME/.cache/quickshell/wallpaper-thumbs\" \"$HOME/.cache/quickshell/activity\" \"$HOME/.config/wallpapers/custom\" \"$HOME/.config/wallpapers/wallhaven\" \"$HOME/.config/wallpapers/defaults\" \"$HOME/.config/fastfetch/cache\""]
    }
    Component.onCompleted: {
        _cacheDirsProc.running = true
        // Instantiate the lazy singleton at boot so it runs its initial sync
        // (self-healing pins whose files are missing) and attaches its pins
        // watcher — otherwise it only wakes on the first manual pin toggle.
        FastfetchPins.start()
        // Probe power-profiles-daemon once at startup so ControlPanelBody
        // can bind PpdState.available instead of spawning `powerprofilesctl`
        // on every island open.
        PpdState.start()
        // Prime the wallpaper store once at boot (category map + video
        // thumbs + aspect cache) so the first SUPER+W open binds warm
        // data instead of spawning get-wallpapers.sh on open.
        WallpaperService.start()
        // Own the clipboard watcher (wl-paste --watch -> qs ipc) so the
        // first copy after boot is recorded, not just post-island ones.
        ClipboardService.start()
    }

    Ipc {
    }
    CaptureIpc {
    }

    // The welcome tour is a single overlay window. It follows the focused
    // monitor by default and can target a specific output through its IPC.
    WelcomeScreen {
    }

    // Selection rectangle used by SUPER + left-drag. Hyprland sends the
    // monitor-relative pointer coordinates through the dragOverlay IPC.
    Variants {
        model: Quickshell.screens

        SelectionOverlay {
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

    // Standalone media controls (SUPER+M), independently toggleable per screen.
    Variants {
        model: Quickshell.screens

        MediaWindow {
            required property ShellScreen modelData

            screen: modelData
        }
    }

    // Wallpaper switcher lives in the main bar pill as WallpaperIsland
    // (BarState "wallpaper", body in widgets/wallpaperPanel).
    // SUPER+W routes to the island via Ipc.togglePanel.

    // Secure lockscreen: single scope; the compositor instantiates one
    // WlSessionLockSurface per screen. The UserProfile panel is a left-island tab.
    LockScreen {
    }

    // Left/right content lives in side pills flanking the main bar pill
    // (leftPanelPill/rightPanelPill in Bar.qml, bodies in widgets/bar/islands;
    // leftSidePill/rightSidePill are the chained weather + media/recording
    // status pills).
    // Notification toasts live in a centered pill below the main pill
    // (NotificationPopups in Bar.qml). SUPER+L/R and the bar HotZones
    // route to the pills — no separate side-panel windows, no exclusive zones.

}
