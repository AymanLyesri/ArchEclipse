//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.widgets.bar
import qs.widgets.launcher
import qs.widgets.lock
import qs.widgets.media
import qs.widgets.notifications

// ArchEclipse shell — multi-monitor via Variants over Quickshell.screens.
// Each window is instantiated once per monitor.
ShellRoot {
    // FileView won't create missing parent dirs, so ensure every cache
    // dir it writes to exists at startup (else writes silently fail).
    property Process _cacheDirsProc: Process {
        command: ["bash", "-c", "mkdir -p \"$HOME/.cache/quickshell/settings\" \"$HOME/.cache/quickshell/booru\" \"$HOME/.cache/cwal\" \"$HOME/.cache/quickshell/launcher\" \"$HOME/.cache/quickshell/script-timer\" \"$HOME/.cache/quickshell/crypto\" \"$HOME/.cache/quickshell/chatbot\" \"$HOME/.cache/quickshell/auth\" \"$HOME/.cache/quickshell/manga\" \"$HOME/.cache/quickshell/wallpaper-thumbs\" \"$HOME/.config/wallpapers/custom\" \"$HOME/.config/wallpapers/wallhaven\" \"$HOME/.config/wallpapers/defaults\" \"$HOME/.config/fastfetch/cache\""]
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
    }

    Ipc {
    }
    CaptureIpc {
    }

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

    // Wallpaper switcher lives in the main bar pill as WallpaperIsland
    // (BarState "wallpaper", body in widgets/wallpaperPanel).
    // SUPER+W routes to the island via Ipc.togglePanel.

    // Secure lockscreen (replaces the UserPanel overlay): single scope,
    // the compositor instantiates one WlSessionLockSurface per screen.
    LockScreen {
    }

    // Left/right content lives in side pills flanking the main bar pill
    // (leftPill/rightPill in Bar.qml, bodies in widgets/bar/islands).
    // SUPER+L/R and the bar HotZones route to the pills — no separate
    // side-panel windows, no exclusive zones.

}
