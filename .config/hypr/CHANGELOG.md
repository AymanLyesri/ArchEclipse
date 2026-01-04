# Changelog

## [Unreleased]

### Added

- **Workspace State Preservation for KVM Switch** (50ceb88)
  - Sistema automático que guarda y restaura la posición de ventanas en workspaces al cambiar entre laptops usando KVM
  - **Problem Solved:** Las aplicaciones se desorganizaban al usar el switch KVM, moviendo ventanas entre workspaces no deseados
  - **Implementation:**
    - Creado `workspace-state-manager.sh`: script principal de guardado/restauración de estado
    - Detecta automáticamente cambios de monitor (conexión/desconexión)
    - Guarda el estado completo antes de cambios de monitor (address, class, title, workspace, monitor, pid)
    - Restaura automáticamente las ventanas a sus workspaces originales al reconectar
    - Sistema de auto-restore inteligente: solo restaura estados recientes (< 10 minutos)
    - Mantiene backups automáticos de los últimos 5 estados guardados
    - Integración transparente con `monitor-hotplug.sh`
  - **Features:**
    - Comandos manuales disponibles: save, restore, show, current, clear, auto-restore
    - Identificación robusta de ventanas por class, initialClass y title
    - Logging detallado en `/tmp/hyprland-workspace-state.log`
    - Estados guardados en `~/.cache/hypr/workspace-states/`
    - Keybinds opcionales disponibles en `KEYBINDS-workspace-state.conf`
  - **Flow Automático:**
    1. Detecta desconexión de monitor → Guarda estado de workspace
    2. Reconfigura monitores → Espera estabilización
    3. Reinicia AGS y hyperpaper
    4. Detecta reconexión de monitor → Restaura ventanas automáticamente
  - **Result:** Las ventanas permanecen en los workspaces donde las dejaste, independientemente de cambios de KVM
  - **Related Files:** `scripts/workspace-state-manager.sh`, `scripts/monitor-hotplug.sh`, `WORKSPACE-STATE-SUMMARY.md`, `scripts/README-workspace-state.md`, `scripts/KEYBINDS-workspace-state.conf`

- **Per-Monitor App Launcher Search Field**
  - Refactored AGS AppLauncher to create independent state for each monitor
  - **Problem Solved:** Search input field now appears on both laptop and external monitor
  - **Previous Behavior:** Entry widget was shared between monitors, only showing on one at a time
  - **Implementation:**
    - Created `monitorStates` Map to store per-monitor state (Results, debounceTimer, args)
    - Entry widget now instantiated inline in export default for each monitor
    - QuickApps, organizeResults, and launchApp functions scoped per monitor
    - Eliminated GTK warnings about widgets being added to multiple containers
  - Each monitor now has fully functional search with:
    - App search with fuzzy matching
    - Emoji search (`emoji ...`)
    - Translation (`translate ... > lang`)
    - URL opening
    - Arithmetic calculations
  - **Related Files:** `ags/widgets/AppLauncher.tsx`

- **Automatic Hyperpaper Reload on Monitor Hotplug** (monitor-hotplug.sh enhancement)
  - Extended `monitor-hotplug.sh` to automatically reload hyperpaper when monitors are connected/disconnected
  - Added `reload_hyperpaper()` function to safely restart wallpaper daemon
  - New script commands: `reload-hyperpaper`, `reload-all` for manual control
  - **Keybind Added:** `Super + Shift + B` to reload both AGS and hyperpaper together
  - **Problem Solved:** 
    - AGS bars no longer require manual reload on monitor changes
    - Wallpapers automatically reload when external monitor is connected/disconnected
    - Eliminated high resource consumption from stale AGS processes
  - **Sequence:** Monitor detection → Multi-monitor config → AGS restart → Hyperpaper reload
  - Complete documentation in `MONITOR-HOTPLUG-README.md`
  - **Related Files:** `scripts/monitor-hotplug.sh`, `hyprpaper/reload.sh`, `configs/keybinds.conf`

### Fixed

- **Monitor Hotplug Daemon Not Running Automatically** (5118758)
  - **Root Cause:** Systemd service started before Hyprland was ready, causing empty monitor state initialization
  - **Symptoms:** 
    - Script failed to detect monitor connections/disconnections automatically
    - Generated 1GB log file from infinite detection loops
    - Empty state file triggered constant "monitor changed" detection
  - **Solutions Applied:**
    - Added 5-second startup delay in systemd service (`ExecStartPre=/bin/sleep 5`)
    - Implemented `initialize_state()` with retry logic (10 attempts, 2s intervals)
    - Fixed exit code capture bug in `get_monitor_state()` function
    - Added validation to skip processing when monitor state is empty
    - Enhanced error handling with debug logging for failed hyprctl calls
    - Only process changes when both previous and current states are non-empty
  - **Result:** Daemon now initializes correctly on boot and detects monitor hotplug events reliably
  - **Related Files:** `scripts/monitor-hotplug.sh`, `~/.config/systemd/user/hyprland-monitor-hotplug.service`

- **AGS Bars Not Showing After Update to v3.0.0** (265ab55, bffec05)
  - **Root Cause:** AGS 3.0.0 now requires explicit GTK version specification and removed `App.reset_css()` from API
  - **Issue:** After running `update --fork`, AGS failed to start with "Failed to infer Gtk version" error
  - **Solutions Applied:**
    - Added `--gtk 3` flag to AGS startup command in `configs/exec.conf`
    - Updated `utils/scss.ts` for AGS 3.0 compatibility:
      - Added CSS file initialization to prevent "invalid selector" error on startup
      - Replaced deprecated `App.reset_css()` with `App.apply_css(tmpCss, true)`
      - Added required imports (GLib, readFile, writeFile from astal/file)
    - Applied `--gtk 3` flag to all AGS restart mechanisms:
      - Super+Shift+B keybind in `multi-monitor-keybinds.conf`
      - `scripts/monitor-hotplug.sh` (automatic restart on monitor changes)
      - `scripts/multi-monitor-manager.sh` (manual AGS restart)
      - `scripts/bar.sh` (bar restart script)
  - **Result:** AGS bars now display correctly on all monitors after system updates, and restart properly from any method
  - **Related Files:** `configs/exec.conf`, `ags/utils/scss.ts`, `configs/multi-monitor-keybinds.conf`, `scripts/bar.sh`, `scripts/monitor-hotplug.sh`, `scripts/multi-monitor-manager.sh`

- **Monitor Hotplug Detection jq Parse Errors and AGS Restart Failures**
  - **Root Cause:** `jq` was failing to parse `hyprctl monitors -j` output intermittently, causing detection to fail
  - **AGS Issue:** Stale `astal` and `gjs` processes were preventing AGS from restarting properly
  - **Solutions Applied:**
    - Enhanced `get_monitor_state()` with error handling and fallback to `awk` parsing
    - Improved `restart_ags()` to aggressively kill all related processes (`ags`, `astal`, `gjs`)
    - Added process verification before and after AGS restart
    - Increased cleanup wait times for proper process termination
    - Added detailed logging for troubleshooting
  - **Result:** Monitor detection now works reliably, AGS restarts successfully on monitor changes
  - **Related Files:** `scripts/monitor-hotplug.sh`

### Changed

- **Monitor Hotplug Manual Reload Keybind** (5118758)
  - Changed keybind from `Super + Shift + B` to `Super + Alt + B`
  - Executes `monitor-hotplug.sh reload-all` to manually restart AGS and reload hyperpaper
  - **Related Files:** `configs/keybinds.conf`

- **Default browser switched from zen-browser to Firefox**
  - Updated `configs/defaults/browser.conf` to launch Firefox on startup
  - Modified browser autostart to use workspace 2 with silent mode
  - Changed window rule to match Firefox class instead of Zen Browser title
  - Updated AGS quick launcher to execute Firefox directly instead of xdg-open

- **Clipboard Monitor Integer Comparison Error** (5f7ab1b)
  - Fixed bash integer comparison error in `start-clipboard-monitor.sh` and `check-clipboard-monitor.sh`
  - **Root Cause:** `pgrep -fc` was returning multi-line output ("0\n0") instead of single integer
  - **Solution:** Refactored process counting logic to use robust pattern:
    - Get PIDs first with `pgrep -f`
    - Check if output is empty, set count to 0
    - Otherwise use `wc -l | xargs` to get clean integer count
  - Fixed trap cleanup issue where EXIT trap was triggering prematurely during `exec`
  - Added proper trap removal before `exec wl-paste` to prevent spurious cleanup
  - All integer comparisons now work correctly without "[: X\nY: integer expected" errors

- **COMPLETE REFACTOR: Clipboard Monitor Duplicate Notifications** (1330482)
  - **Root Cause:** Multiple wl-paste processes (3+) were being launched at startup, causing triple notifications
  - **Solution:** Completely refactored clipboard monitoring system with unified architecture
  - **Changes:**
    - Rewrote `start-clipboard-monitor.sh` with multi-layer singleton protection:
      - Atomic lock acquisition using `mkdir` 
      - Aggressive cleanup of ALL existing wl-paste processes on startup
      - PID file validation with stale process detection
      - Race condition prevention with verification delays
      - Comprehensive startup logging to `/tmp/clipboard-monitor-startup.log`
    - Simplified `exec.conf` to use ONLY the launcher script (removed all inline implementations)
    - Created `check-clipboard-monitor.sh` health check script for diagnostics
    - Cleared all previous partial fixes from older commits
  - **Multimonitor Compatibility:** Works across all monitor configurations (clipboard is compositor-level, not per-monitor)
  - **Guaranteed:** System now prevents multiple instances at boot/login and during hotplug events

- **AGS Crashes After Update Fork - libcava Incompatibility**
  - **Root Cause:** System update upgraded `libcava` from 0.10.4-1 to 0.10.6-2, breaking API compatibility
  - **Issue:** AGS suffered segmentation faults in `libastal-cava-git` and `libfftw3` libraries
  - **Diagnosis:** Analyzed coredump logs revealing `astal_cava_cava_get_default` crashes
  - **Solutions Applied:**
    - **Patched libastal-cava-git:** Fixed API incompatibility in `/home/alphonse/.cache/yay/libastal-cava-git/src/astal/lib/cava/cava.c`
      - Changed `audio_raw_init` parameter from `struct cava_plan *` to `struct cava_plan **`
      - Recompiled package to `r840.71b008e-1`
    - **Fixed AGS Monitor Detection:** Updated `app.ts` to use `Gdk.Display.get_default()` instead of deprecated `App.get_monitors()`
    - **Added Null Safety:** Fixed `focusedWorkspace` null checks in `autoSwitchWorkspace.ts`, `Workspaces.tsx`, and `WallpaperSwitcher.tsx`
    - **Temporary Workaround:** Disabled CAVA visualization in `Information.tsx` due to persistent `libfftw3` segfaults
  - **Status:** AGS fully operational without CAVA audio visualization (pending upstream fix)
  - **Related Commits:** a04e334

### Added

- **Complete English Translation** (07073f9)
  - Translated all Spanish documentation to English (COMANDOS-UPDATE.md, FORK-SYNC-GUIDE.md, README-SYNC.md)
  - Translated all script comments and messages to English (sync-upstream.sh, sync-upstream-auto.sh)
  - Enhanced .gitignore with backup file exclusion patterns (*.backup.*, *.bak, *~)

- **Clipboard Monitor Diagnostics**
  - New `check-clipboard-monitor.sh` script for system health verification
  - Shows process count, PID status, lock status, and recent activity logs
  - Provides clear status verdict (HEALTHY/UNHEALTHY/NOT RUNNING)

### Added (Previous)

- **Automated Upstream Synchronization Tools** (6d9a16d)
  - `sync-upstream.sh` script with interactive options (merge/rebase/auto)
  - `sync-upstream-auto.sh` for fully automated synchronization
  - GitHub Action for daily automatic upstream sync
  - Conflict resolution and stash management
  - Support for handling non-fast-forward pushes automatically
  - Complete documentation in `FORK-SYNC-GUIDE.md`, `README-SYNC.md`, and `COMANDOS-UPDATE.md` (848fa5d)
  - Integration with existing `UPDATE.sh --dev --fork` workflow (848fa5d)
- Comprehensive multi-monitor support with automatic device detection
- `multi-monitor-manager.sh` script for intelligent monitor management
- `refresh-rate-manager.sh` script for dynamic refresh rate management (f4a6e40)
- Interactive refresh rate selection with terminal-based menus (f4a6e40)
- Direct refresh rate keybinds for 60/75/120/144Hz (f4a6e40)
- Comprehensive English documentation in `MULTI_MONITOR_KEYBINDS.md` (f4a6e40)
- Automatic device type detection (laptop/desktop)
- Intelligent lid event handling for laptops
- Automatic resolution configuration for secondary monitors
- Enhanced keybinds for moving workspaces between monitors
- `lid-handler.sh` script for automatic lid events
- `monitor-setup.sh` script for common quick configurations
- `monitor-hotplug.sh` script for automatic monitor hotplug detection
- `move-window-monitor.sh` script for dynamic window movement between monitors
- systemd service `hyprland-lid-handler.service` for automatic event handling
- systemd service `hyprland-monitor-hotplug.service` for monitor hotplug detection
- `multi-monitor-keybinds.conf` configuration file with specialized keybinds
- Complete documentation in `README-MultiMonitor.md`

### Changed

- Updated `hyprland.conf` to include multi-monitor configuration
- Modified `configs/exec.conf` for startup auto-configuration
- Enhanced `configs/monitors.conf` with automatic generation

### Fixed

- **Triple Notification Bug on Single Monitor**
  - Fixed clipboard monitor spawning 3 duplicate instances causing triple notifications
  - Added singleton protection with lock file mechanism in exec.conf
  - Implemented global flag in AGS app.ts to prevent multiple display initializations
  - Added singleton pattern in NotificationPopups.tsx to prevent duplicate notification listeners
  - Resolved issue where hyprctl reload was re-executing exec-once commands
- **Package Manager Process Cleanup** (6b2a781)
  - Fixed hanging pkill processes that could freeze UPDATE.sh script
  - Replaced problematic `pkill -f` commands with targeted PID-based cleanup
  - Added graceful termination (TERM) before force kill (KILL -9)
  - Created standalone `cleanup-pacman.sh` script for manual cleanup
  - Added preventive cleanup to sync scripts
- Fixed keybind syntax errors in multi-monitor configuration
- Corrected dispatcher commands for window and workspace movement
- Fixed AGS bar not appearing on external monitors
- Fixed pkill command to avoid killing other applications (like Windsurf)
- Added automatic AGS restart when monitor configuration changes
- Added automatic monitor hotplug detection for seamless AGS bar management
- Fixed window movement keybinds to work dynamically with any monitor configuration
- Fixed multi-monitor keybinds by adding missing variable definitions (f4a6e40)
- Removed duplicate configuration includes in hyprland.conf (f4a6e40)
- Improved monitor mode selection with numerical interface (f4a6e40)
- Fixed interactive menu terminal exit when showing current configuration (f7db23c)

### Features

- **Automatic Detection**: Identifies laptops vs desktops automatically
- **Smart Lid Management**: When lid closes with AC power and external monitor connected:
  - Disables internal monitor
  - Moves all workspaces to external monitor
  - Prevents system suspension
- **Workspace Redistribution**: Automatically distributes workspaces across monitors
- **Resolution Configuration**: Easy interface for configuring secondary monitor resolutions
- **Advanced Keybinds**: 
  - `Super + Alt + →/←`: Move current workspace between monitors
  - `Super + Shift + Alt + →/←`: Move active window between monitors
  - `Super + Ctrl + Alt + →/←`: Focus between monitors
  - `Super + Shift + M`: Open interactive multi-monitor manager
  - `Super + Shift + P`: Mirror mode for presentations
  - `Super + Shift + I`: Toggle internal monitor
  - `Super + Shift + R`: Interactive refresh rate manager (f4a6e40)
  - `Super + Alt + F1-F4`: Direct refresh rate changes (60/75/120/144Hz) (f4a6e40)
- **Refresh Rate Management**: Intelligent refresh rate switching with:
  - Automatic detection of available refresh rates
  - Position preservation during rate changes
  - Interactive terminal-based selection menu
  - Notification support for configuration changes (f4a6e40)
- **Enhanced User Experience**: Improved interactive menus with:
  - Persistent menu loops that don't exit unexpectedly
  - Clear screen transitions between operations
  - "Press Enter to continue" prompts for better flow (f7db23c)

## [2025-09-06]

### Added

- Initial implementation of multi-monitor support for ArchEclipse Rice
- Complete system for automatic monitor detection and configuration
- Intelligent laptop event handling (lid close/open)
- Management and automated configuration scripts
- Specialized keybindings for multi-monitor workflows
- Complete system documentation
