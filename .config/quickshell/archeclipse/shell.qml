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
        command: ["bash", "-c", "mkdir -p \"$HOME/.cache/quickshell/settings\" \"$HOME/.cache/quickshell/booru\" \"$HOME/.cache/coloreclipse\" \"$HOME/.cache/quickshell/launcher\" \"$HOME/.cache/quickshell/launcher/clipboard-images\" \"$HOME/.cache/quickshell/chatbot\" \"$HOME/.cache/quickshell/auth\" \"$HOME/.cache/quickshell/manga\" \"$HOME/.cache/quickshell/wallpaper-thumbs\" \"$HOME/.cache/quickshell/activity\" \"$HOME/.config/wallpapers/custom\" \"$HOME/.config/wallpapers/wallhaven\" \"$HOME/.config/wallpapers/defaults\" \"$HOME/.config/fastfetch/cache\""]
    }
    Component.onCompleted: {
        _cacheDirsProc.running = true
        // Prime at boot: the singleton only syncs and attaches its pins watcher
        // here — otherwise it sleeps until the first manual pin toggle.
        FastfetchPins.start()
        // One boot probe lets ControlPanelBody bind PpdState.available instead of
        // spawning `powerprofilesctl` on every island open.
        PpdState.start()
        // Prime the wallpaper store at boot (categories + video thumbs + aspects) so
        // the first SUPER+W open binds warm data instead of refetching.
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

    // Standalone media controls (SUPER+M), independently toggleable per screen.
    Variants {
        model: Quickshell.screens

        MediaWindow {
            required property ShellScreen modelData

            screen: modelData
        }
    }

    // Wallpaper switcher is WallpaperIsland in the main pill (BarState
    // "wallpaper"); SUPER+W routes there via Ipc.togglePanel, not a window.

    // Secure lockscreen: single scope; the compositor instantiates one
    // WlSessionLockSurface per screen. The UserProfile panel is a left-island tab.
    LockScreen {
    }

    // Left/right content + toasts are pills around the main pill (Bar.qml, islands/),
    // routed by SUPER+L/R and HotZones — no side-panel windows, no exclusive zones.

}
