<div align="center">

<img src=".github/assets/overview.png" alt="ArchEclipse Overview" width="100%"/>

<br/>

# ArchEclipse

**A production-grade Hyprland desktop environment — built from scratch, engineered for daily use.**

[![Discord](https://img.shields.io/badge/Discord-Join%20Server-5865F2?logo=discord&logoColor=white)](https://discord.gg/fMGt4vH6s5)

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=arch-linux&logoColor=white)](https://archlinux.org/)
[![Hyprland](https://img.shields.io/badge/Hyprland-blue?style=flat-square)](https://hyprland.org/)
[![GTK4](https://img.shields.io/badge/GTK4-4A86CF?style=flat-square&logo=gtk&logoColor=white)](https://gtk.org/)
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
| **UI / Widgets**                   | GTK4, TypeScript, TSX (Ags framework) |
| **Automation & Tooling**           | Python 3, Bash                        |
| **Performance-Critical Utilities** | C                                     |
| **Compositor**                     | Hyprland (Wayland)                    |

---

## Architecture & Technical Highlights

### Dynamic Theming Engine

A custom pipeline generates a full system color scheme from the active wallpaper at runtime using [PyWal](https://github.com/dylanaraps/pywal). Colors propagate automatically to GTK4 widgets, terminal, and all UI components. No manual color editing required — ever.

- Per-workspace wallpaper assignment with both static and animated (video) support
- Global light/dark mode toggle with instant application across the entire environment
- Color changes hot-reload without restarting any component

### GTK4 Widget System (TypeScript/TSX)

All shell UI is built with the **Ags GTK4 v3** framework — replacing prior Eww and Ags GTK3 implementations. Widgets are written in TypeScript with TSX, enabling type-safe, component-based UI development that mirrors modern web frontend workflows.

The bar is fully modular — widgets are swappable at runtime. Current slots include:

- Workspace overview with live thumbnails
- Network bandwidth monitor
- Weather integration
- Media player (MPRIS)
- System tray
- Notification popups
- Live crypto price display

### Application Launcher (Rofi Replacement)

A custom-built launcher written in GTK4/TS replacing Rofi entirely, with built-in support for:

- App launching with fuzzy search
- Clipboard history browser
- Emoji picker
- Inline arithmetic evaluation
- URL forwarding to default browser
- Arbitrary custom command execution

### Panels

**Right Panel** — Configurable layout with swappable widgets: media player, notification history, calendar, script runner, crypto portfolio viewer, and an anime image viewer powered by the [Danbooru](https://danbooru.donmai.us) and [Gelbooru](https://gelbooru.com) APIs.

**Left Panel** — Power-user tools: an integrated chatbot (multi-API), a booru image browser, a manga reader ([MangaDex](https://mangadex.org/) API, WIP), live keybinds reference, and a Hyprland/Ags settings panel.

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
archeclipse
```

---

## Configuration Tips

- **User avatar:** `$HOME/.face.icon`
- **Wallpaper picker:** `SUPER + W`
- **Custom wallpapers:** `$HOME/.config/wallpapers/custom`
- **Custom Hyprland config:** `$HOME/.config/hypr/configs/custom`
- **Laptop users:** Install `upower` for battery monitoring
- **Full keybinds reference:** [keybinds.conf](https://github.com/AymanLyesri/ArchEclipse/blob/master/.config/hypr/configs/keybinds.conf) or via the Left Panel in-environment

---

## Roadmap

- [ ] Per-component tutorials and documentation _(in progress)_
- [ ] Gaming performance optimization _(in progress)_
- [ ] MangaDex manga reader _(in progress)_
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

[![Star History Chart](https://api.star-history.com/svg?repos=aymanlyesri/ArchEclipse&type=Date)](https://star-history.com/#aymanlyesri/ArchEclipse&Date)

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
