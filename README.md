<div align="center">

<img src=".github/assets/overview.png" alt="ArchEclipse Overview" width="100%"/>

<br/>

# ArchEclipse

**A production-grade Hyprland desktop environment — built from scratch, engineered for daily use.**

[![Discord](https://img.shields.io/badge/Discord-Join%20Server-5865F2?logo=discord&logoColor=white)](https://discord.gg/fMGt4vH6s5)

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=arch-linux&logoColor=white)](https://archlinux.org/)
[![Hyprland](https://img.shields.io/badge/Hyprland-blue?style=flat-square)](https://hyprland.org/)
[![Quickshell](https://img.shields.io/badge/Quickshell-4A86CF?style=flat-square)](https://quickshell.org/)
[![QtQuick](https://img.shields.io/badge/QtQuick_QML-41CD52?style=flat-square&logo=qt&logoColor=white)](https://doc.qt.io/qt-6/qtquick-index.html)
[![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org/)
[![Stars](https://img.shields.io/github/stars/AymanLyesri/archeclipse?style=social)](https://github.com/AymanLyesri/ArchEclipse/stargazers)
[![Issues](https://img.shields.io/github/issues/AymanLyesri/ArchEclipse?style=flat-square)](https://github.com/AymanLyesri/ArchEclipse/issues)

</div>

---

## What Is This?

ArchEclipse is my personal, battle-tested desktop configuration for Arch Linux + Hyprland. It's a **fully integrated system** that I use daily for coding, trading, gaming, and general productivity.

Every component was written, tuned, and iterated on over real-world use. The result is a cohesive environment where the UI, system utilities, automation scripts, and visual theming all work as a single product — not a patchwork of borrowed configs.

The project spans multiple languages and layers of the stack:

| Layer                              | Technologies                          |
| ---------------------------------- | ------------------------------------- |
| **UI / Widgets**                   | QtQuick, QML, JavaScript (Quickshell framework) |
| **Automation & Tooling**           | Python 3, Bash                        |
| **Performance-Critical Utilities** | C                                     |
| **Compositor**                     | Hyprland (Wayland)                    |

---

## Architecture & Technical Highlights

### Architecture

```mermaid
graph TB
    subgraph Install["Setup & maintenance"]
        Installer["install.py / update.py<br/>Python installer"]
        Pacman["components/packages.py<br/>embedded package list"]
        Archeclipse["archeclipse() zsh fn<br/>update wrapper"]
    end

    subgraph Hypr["Hyprland — window manager (Lua)"]
        HyprMain["hyprland.lua<br/>entry point"]
        HyprConfig["config/*.lua<br/>bind, animations, monitor,<br/>windowrule, gesture, input"]
        HyprScripts["scripts / scripts-c<br/>screenshot, screenrecord,<br/>brightness, clipboard, wallpaper-loop"]
        WallpaperDaemon["wallpaper-daemon<br/>hyprpaper / mpvpaper"]
        Evremap["evremap<br/>key remapping service"]
    end

    subgraph QS["Quickshell shell (QtQuick + QML)"]
        Shell["shell.qml<br/>ShellRoot bootstrap"]

        subgraph BarSys["Bar system"]
            Bar["Bar.qml<br/>state machine:<br/>default/search/control/<br/>volume/brightness/recording"]
            BarIslands["islands/<br/>SearchIsland, ControlIsland,<br/>PlayerIsland, WallpaperIsland,<br/>WeatherIsland, RightIsland"]
            BarSub["bar widgets<br/>Battery, Volume, Bandwidth,<br/>Brightness, Player, Recording"]
        end

        AppLauncher["LauncherPanel.qml<br/>quickshell launcher +<br/>clipboard + emoji + notes"]

        subgraph Panels["Side panels"]
            LeftPanel["leftPanel/<br/>Settings, ChatBot,<br/>BooruViewer, MangaViewer,<br/>KeyBinds, UserProfile"]
            RightPanel["rightPanel/<br/>Calendar, Notifications,<br/>SystemResources, Crypto, Waifu"]
        end

        subgraph Core["Core layers"]
            Widgets["widgets/shared/<br/>reusable QML components"]
            Services["services/<br/>BarState, Brightness,<br/>ScreenRecorder, Ipc,<br/>Supabase, Weather"]
            Utils["utils/<br/>SettingsUtils, MonitorUtils,<br/>TimeUtils, WindowManager"]
            Theme["theme/<br/>Theme.qml + GlobalTheme<br/>typed config & styling"]
        end

        subgraph NativeScripts["Native/companion scripts"]
            CLoops["*.c loops<br/>system-resources, bandwidth,<br/>keystroke visualizer"]
            PyScripts["*.py<br/>chatbot, booru, manga,<br/>crypto, auth-callback"]
            ShScripts["*.sh<br/>get-wallpapers, translate,<br/>get-keybinds, image-color"]
        end
    end

    subgraph Backend["External services"]
        Supabase[("Supabase<br/>auth + RLS + settings sync")]
        APIs[("Booru / manga / crypto /<br/>weather / chatbot APIs")]
    end

    Installer --> Pacman
    Installer --> HyprMain
    Archeclipse --> Installer

    HyprMain --> HyprConfig
    HyprConfig --> HyprScripts
    HyprConfig --> WallpaperDaemon
    HyprConfig --> Evremap
    HyprMain -- "spawns/execs" --> Shell

    Shell --> BarSys
    Shell --> AppLauncher
    Shell --> Panels
    Shell --> Core

    Bar --> BarIslands
    Bar --> BarSub
    BarIslands -.->|opens| AppLauncher

    Widgets --> Core
    LeftPanel --> Widgets
    RightPanel --> Widgets
    BarSys --> Widgets

    Core --> NativeScripts
    Utils --> Services
    Services -->|"auth, settings sync"| Supabase
    NativeScripts -->|"HTTP calls"| APIs

    Theme -.->|styles| Shell

    classDef install fill:#EEEDFE,stroke:#534AB7,color:#26215C
    classDef hypr fill:#E1F5EE,stroke:#0F6E56,color:#04342C
    classDef qs fill:#FAECE7,stroke:#993C1D,color:#4A1B0C
    classDef core fill:#E6F1FB,stroke:#185FA5,color:#042C53
    classDef ext fill:#FAEEDA,stroke:#854F0B,color:#412402

    class Installer,Pacman,Archeclipse install
    class HyprMain,HyprConfig,HyprScripts,WallpaperDaemon,Evremap hypr
    class Shell,Bar,BarIslands,BarSub,AppLauncher,LeftPanel,RightPanel qs
    class Widgets,Services,Utils,Theme,CLoops,PyScripts,ShScripts core
    class Supabase,APIs ext
```

### Dynamic Theming Engine

A custom pipeline generates a full system color scheme from the active wallpaper at runtime using [Cwal](https://github.com/nitinbhat972/cwal) a custom C implementation of PyWal (10-50x faster, zero Python overhead) that generates a full color scheme at runtime. Colors propagate automatically to Quickshell / QtQuick widgets, terminal, and all UI components. No manual color editing required — ever.

- Per-workspace wallpaper assignment with both static and animated (video) support
- Global light/dark mode toggle with instant application across the entire environment
- Color changes hot-reload without restarting any component

### Quickshell Widget System (QML / QtQuick)

All shell UI is built with the **Quickshell** framework — which replaced the prior Eww and AGS (GTK) implementations (migration completed 2026-09-12; the legacy tree was removed from the repo — if `~/ArchEclipse-AGS` or `~/agsv1` still exist on your machine they are ignored leftovers and safe to delete). Widgets are written in QML with JavaScript, enabling declarative, reactive UI development with per-monitor windows driven by `shell.qml` and singleton services (`BarState`, `GlobalTheme`, `Supabase`, `Weather`).

The bar is fully modular — widgets are swappable at runtime. Current slots include:

- Workspace overview with live thumbnails
- Network bandwidth monitor
- Weather integration
- Media player (MPRIS)
- System tray
- Notification popups
- Live crypto price display

### Application Launcher (Rofi Replacement)

A custom-built launcher written in QML/QtQuick replacing Rofi entirely, with built-in support for:

- App launching with fuzzy search
- Clipboard history browser
- Emoji picker
- Inline arithmetic evaluation
- URL forwarding to default browser
- Arbitrary custom command execution

### Panels

**Right Panel** — Configurable layout with swappable widgets: media player, notification history, calendar, script runner, crypto portfolio viewer, and an anime image viewer powered by the [Danbooru](https://danbooru.donmai.us) and [Gelbooru](https://gelbooru.com) APIs.

**Left Panel** — Power-user tools: an integrated chatbot (multi-API), a booru image browser, a manga reader ([MangaDex](https://mangadex.org/) API, WIP), live keybinds reference, and a Hyprland/Quickshell settings panel.

### Installer & Updater

The entire configuration deploys via a single command using a Python-based installer that handles dependency resolution, git-based dotfile deployment, and package management automatically. Post-install, the environment stays up to date with a single `archeclipse` command.

---

## Workspace Layout

| Workspace      | Assigned Application |
| -------------- | -------------------- |
| W2             | Browser              |
| W4             | Spotify              |
| W5             | Btop                 |
| W6             | Discord              |
| W7             | Steam / Lutris       |
| W10            | Games                |
| W1, W3, W8, W9 | General purpose      |

Applications launch automatically into their designated workspaces at login.

---

## Installation

**Requirements:** Arch Linux (or Arch-based), Hyprland configured and working, Python 3.

> All other dependencies are installed automatically by the installer.

### One-line Install

```bash
python3 <(curl -fsSL https://raw.githubusercontent.com/AymanLyesri/ArchEclipse/refs/heads/master/.config/hypr/maintenance/install.py)
```

### Update

```bash
archeclipse   # zsh function (defined in ~/.zshrc): fetches and runs maintenance/update.py
```

---

## Configuration Tips

- **User avatar:** `$HOME/.face.icon`
- **Wallpaper picker:** `SUPER + W`
- **Custom wallpapers:** `$HOME/.config/wallpapers/custom`
- **Custom Hyprland config:** `$HOME/.config/hypr/config/custom`
- **Laptop users:** Install `upower` for battery monitoring
- **Full keybinds reference:** [bind.lua](https://github.com/AymanLyesri/ArchEclipse/blob/master/.config/hypr/config/bind.lua) or via the Left Panel in-environment

---

## Roadmap

- [ ] Per-component tutorials and documentation _(in progress)_
- [ ] Gaming performance optimization _(in progress)_
- [ ] Continuous polish and refinement _(ongoing)_

Issues, suggestions, and feature requests are always welcome — [open one here](https://github.com/AymanLyesri/ArchEclipse/issues).

---

## Support

If this project saved you time or you just enjoy it, a coffee helps keep development going.

<div align="center">

# ❤️ Support My Work

<a href="https://ko-fi.com/aymanlyesri">
  <img src="https://img.shields.io/badge/☕_Ko--fi-29ABE0?style=for-the-badge&logo=ko-fi&logoColor=white" />
</a>
<a href="https://www.buymeacoffee.com/aymanlyesri">
  <img src="https://img.shields.io/badge/Buy_Me_A_Coffee-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=000000" />
</a>
<a href="https://paypal.me/LyesriAyman">
  <img src="https://img.shields.io/badge/PayPal-00457C?style=for-the-badge&logo=paypal&logoColor=white" />
</a>
<br>
<img src="https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&size=16&pause=2500&color=F7931A&center=true&vCenter=true&width=420&height=28&lines=Supporting+open-source+development+❤;Every+donation+helps+🚀" />

<table>
<tr>
<td align="center">

**₿ Bitcoin**

```txt
1JisW9xeatCFadtgsenjbpCcFePZGPyXow
```

</td>
<td align="center">

**Ξ Ethereum / BSC**

```txt
0x52d06d47bb9dc75eaf027f18cb197d5817989a96
```

</td>
</tr>
</table>

---

## Star History

[![Star History Chart](https://star-history.dera.page/svg?repos=aymanlyesri/ArchEclipse&type=Date)](https://star-history.dera.page/#aymanlyesri/ArchEclipse&Date)

---

## Visuals

### Application Launcher

![Application Launcher](.github/assets/app-launcher.png)

### Right Panel — Configurable Layouts

| Layout A                                                  | Layout B                                                  |
| --------------------------------------------------------- | --------------------------------------------------------- |
| ![Right Panel 1](.github/assets/right-panel-layout-1.png) | ![Right Panel 2](.github/assets/right-panel-layout-2.png) |

### Left Panel

| Chatbot                                           | Booru Viewer                                    |
| ------------------------------------------------- | ----------------------------------------------- |
| ![Chatbot](.github/assets/left-panel-chatbot.png) | ![Booru](.github/assets/left-panel-booru-1.png) |

| Settings                                            | Keybinds                                            |
| --------------------------------------------------- | --------------------------------------------------- |
| ![Settings](.github/assets/left-panel-settings.png) | ![Keybinds](.github/assets/left-panel-keybinds.png) |

### Wallpaper Switcher

![Wallpaper Switcher](.github/assets/wallpaper-switcher.png)

### Workspace Overview

![Workspace Overview](.github/assets/workspace-overview.gif)

### Theme Switching

| Dark Mode                              | Light Mode                               |
| -------------------------------------- | ---------------------------------------- |
| ![Dark](.github/assets/dark-theme.png) | ![Light](.github/assets/light-theme.png) |

### Keystroke Visualizer _(optional)_

![Keystroke Visualizer](.github/assets/keystroke-visualizer.gif)

### User Panel

![User Panel](.github/assets/user-panel.gif)
