<div align="center">

<img src=".github/assets/overview.png" alt="ArchEclipse Overview" width="100%"/>

<br/>

# ArchEclipse

**Hyprland desktop that just works — daily-driven, fully themed, one-command install.**

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

## TL;DR

- **What:** Arch + Hyprland + custom Quickshell UI. Bar, launcher, panels, theming — all integrated.
- **Install:** 1 command (below). Update with `archeclipse`.
- **Try first:** `SUPER + W` = wallpapers. Full keys: [bind.lua](https://github.com/AymanLyesri/ArchEclipse/blob/master/.config/hypr/config/bind.lua).

---

## Install

**Need:** Arch / Arch-based + Hyprland + Python 3. Rest is auto-installed.

```bash
python3 <(curl -fsSL https://raw.githubusercontent.com/AymanLyesri/ArchEclipse/refs/heads/master/.config/hypr/maintenance/install.py)
```

```bash
archeclipse   # update anytime (zsh fn → runs maintenance/update.py)
```

---

## What you get

| Need | How |
| ---- | --- |
| **Bar** | Modular widgets: workspaces, bandwidth, weather, player, tray, crypto |
| **Launcher** | App search + clipboard + emoji + calc + URLs + custom cmds. No Rofi. |
| **Right panel** | Player, notifications, calendar, crypto, anime viewer |
| **Left panel** | Chatbot, booru browser, manga reader (WIP), keybinds, settings |
| **Theming** | Wallpaper → full system colors. Light/dark toggle. Hot-reload. No manual edits. |

**Stack:** QML/QtQuick (Quickshell) · Python 3 + Bash · C (perf utils) · Hyprland/Wayland

| Workspace | Opens |
| --------- | ----- |
| W2 / W4 / W5 / W6 / W7 / W10 | Browser / Spotify / Btop / Discord / Steam / Games |
| W1, W3, W8, W9 | General |

> Apps auto-launch to their workspace at login.

---

## Essentials

- **Avatar:** `$HOME/.face.icon`
- **Wallpapers:** `SUPER + W` → picker. Add yours to `$HOME/.config/wallpapers/custom`
- **Hyprland tweaks:** `$HOME/.config/hypr/config/custom`
- **Laptop:** install `upower` for battery
- **Keys:** [bind.lua](https://github.com/AymanLyesri/ArchEclipse/blob/master/.config/hypr/config/bind.lua) or Left Panel in-app

---

<details>
<summary><b>How it works — architecture, theming, widgets (click to expand)</b></summary>

<br/>

**One idea:** UI + scripts + theming ship as one product. Not random dotfiles.

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
            Utils["utils<br/>SettingsUtils, MonitorUtils,<br/>TimeUtils, WindowManager"]
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

### Theming

- Wallpaper → colors via [Cwal](https://github.com/nitinbhat972/cwal) (C PyWal, 10-50x faster).
- Auto-applies to Quickshell, terminal, UI. Zero manual edits.
- Per-workspace static / video wallpapers. Light/dark toggle. Hot-reload.

### Widgets (Quickshell / QML)

- Reactive QML via `shell.qml` + singletons (`BarState`, `GlobalTheme`, `Supabase`, `Weather`).
- Bar slots swappable at runtime.
- Note: migrated from Eww/AGS on 2026-09-12. Old `~/ArchEclipse-AGS` / `~/agsv1` folders are safe to delete.

### Launcher details

Fuzzy search · clipboard history · emoji · calc · URL forward · custom cmds.

### Panels detail

- **Right:** media, notifications, calendar, script runner, crypto, Danbooru/Gelbooru viewer.
- **Left:** chatbot (multi-API), booru browser, MangaDex reader (WIP), live keybinds, Hyprland/Quickshell settings.

### Deployer

Python installer = deps + dotfiles + packages. One command in, `archeclipse` keeps you updated.

</details>

---

## Roadmap

- [ ] Per-component docs _(in progress)_
- [ ] Gaming perf tuning _(in progress)_
- [ ] Ongoing polish

Bugs / ideas → [open an issue](https://github.com/AymanLyesri/ArchEclipse/issues).

---

## Visuals

### Launcher

![Application Launcher](.github/assets/app-launcher.png)

### Right Panel

| Waifu · Player · Calendar · Notifications | Calendar · Player · Waifu · Resources |
| --- | --- |
| ![Right Panel Layout 1](.github/assets/right-panel-layout-1.png) | ![Right Panel Layout 2](.github/assets/right-panel-layout-2.png) |

### Left Panel

| Chatbot | Booru |
| ------- | ----- |
| ![Chatbot](.github/assets/left-panel-chatbot.png) | ![Booru](.github/assets/left-panel-booru-1.png) |

| Settings | Keybinds |
| -------- | -------- |
| ![Settings](.github/assets/left-panel-settings.png) | ![Keybinds](.github/assets/left-panel-keybinds.png) |

### Wallpaper · Workspaces · Lock

![Wallpaper Switcher](.github/assets/wallpaper-switcher.png)
![Workspace Overview](.github/assets/workspace-overview.png)
![Lock Screen](.github/assets/lock-screen.png)

---

## ❤️ Support

Coffee = more dev. Thanks.

<div align="center">

<a href="https://ko-fi.com/aymanlyesri">
  <img src="https://img.shields.io/badge/☕_Ko--fi-29ABE0?style=for-the-badge&logo=ko-fi&logoColor=white" />
</a>
<a href="https://www.buymeacoffee.com/aymanlyesri">
  <img src="https://img.shields.io/badge/Buy_Me_A_Coffee-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=000000" />
</a>
<a href="https://paypal.me/LyesriAyman">
  <img src="https://img.shields.io/badge/PayPal-00457C?style=for-the-badge&logo=paypal&logoColor=white" />
</a>

<details>
<summary>Crypto addresses</summary>

**₿ Bitcoin**
```txt
1JisW9xeatCFadtgsenjbpCcFePZGPyXow
```

**Ξ Ethereum / BSC**
```txt
0x52d06d47bb9dc75eaf027f18cb197d5817989a96
```

</details>

[![Star History Chart](https://star-history.dera.page/svg?repos=aymanlyesri/ArchEclipse&type=Date)](https://star-history.dera.page/#aymanlyesri/ArchEclipse&Date)

</div>
