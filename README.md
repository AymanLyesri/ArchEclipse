# **Arch Eclipse**

# Description

This is my daily driver configuration that I use on both my laptop and desktop for coding, gaming, trading, browsing the web, etc., with Dvorak in mind. I am constantly adding new features and improvements.

I use Arch BTW.. :)

> **Feel free to open an issue ♡ (anything you can think of)!**

# Discord

New official [Discord](https://discord.gg/fMGt4vH6s5) server.

# See Wiki

> The README as an organized [WIKI](https://archeclipse-wiki.vercel.app/)

# Design Philosophy

- Enhanced productivity
- Faster responsiveness
- Smooth animations
- Vibrant color schemes
- It just works

# Features

- **Dynamic wallpapers** based on workspaces: Custom scripts & [Hyprpaper](https://github.com/hyprwm/hyprpaper)
- **Dynamic color schemes** based on current wallpaper: Custom scripts & [PyWal](https://github.com/dylanaraps/pywal)
- **Global Theme switcher (Light/Dark)**: Custom scripts
- **Ags V3 - GTK 4 widgets** ~~(Eww replaced & Ags V2 - Gtk 3 replaced)~~: _these are just some of the features_
  - Color scheme based on current wallpaper
  - Main bar
    - Dark/light modes
    - Bandwidth speed monitor
  - Application launcher ~~(Rofi replaced)~~
    - App launcher
    - Emojis
    - Arithmetics
    - Url forwarding to default browser
    - custom commands
  - Wallpaper switcher for each workspace
  - Media player
  - Right Panel
    - Waifu display -- using [Danbooru](https://danbooru.donmai.us) and [Gelbooru](https://gelbooru.com) APIs
    - Media Player
    - Notification history - filter
    - Calendar
    - Script Timer
  - Left Panel
    - Chat Bot -- multiple APIs + image generation
    - Booru Viewer -- using [Danbooru](https://danbooru.donmai.us) and [Gelbooru](https://gelbooru.com) APIs
  - Hyprland Settings widget
  - User Panel (logout etc...)
- **High-quality wallpapers** from [Danbooru](https://danbooru.donmai.us), [Yandere](https://yande.re), and [Gelbooru](https://gelbooru.com)

# Current Workflow

> **Important:** Screenshots below ⊽

| W1  | W2      | W3  | W4                                                  | W5                                           | W6                                                  | W7                                                                            | W8  | W9  | W10   |
| --- | ------- | --- | --------------------------------------------------- | -------------------------------------------- | --------------------------------------------------- | ----------------------------------------------------------------------------- | --- | --- | ----- |
| --- | Browser | --- | [Spotify](https://wiki.archlinux.org/title/spotify) | [Btop](https://github.com/aristocratos/btop) | [Discord](https://wiki.archlinux.org/title/Discord) | [Steam](https://wiki.archlinux.org/title/steam)/[Lutris](https://lutris.net/) | --- | --- | Games |

- **W`id`**: Workspace with corresponding ID.
- **`---`**: Placeholder, any app can go here.
- **`name`**: Application that opens automatically in its designated workspace.

# To-Do List

- **Users: Any suggestions or issues?**
- AGS V3 bundling
- Make sure the dot-files work for every machine not just mine **(WIP)**
- Add tutorials for each part of the dot-files **(WIP)**
- Continuous improvements and polishing **(INDEFINITELY)**

# KeyBinds

KeyBinds are displayed and organized [Here](https://github.com/AymanLyesri/hyprland-conf/blob/master/.config/hypr/configs/keybinds.conf), be sure to check them out!

# Installation and Update

## Required Dependencies and packages

- [Arch Linux](https://archlinux.org/) (I use Arch linux BTW)
- [Hyprland](https://hyprland.org/)
- [Necessary packages](https://github.com/AymanLyesri/hyprland-conf/blob/master/.config/hypr/pacman/pkglist.txt) (do not worry they will be installed automatically)

## Installation Guide

> Run this one liner in the terminal -- Say `Yes` to everything

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/AymanLyesri/ArchEclipse/refs/heads/master/.config/hypr/maintenance/INSTALL.sh)"
```

## Update Guide

> To update the config and its related pkgs Simply run `update` in the terminal

```bash
update
```

# Tips

- User Icon is stored in `$HOME/.face.icon`
- Press `SUPER + w` to select the wallpaper you like
- Custom wallpapers should be added in `$HOME/.config/wallpapers/custom`
- Custom hyprland configuration should be put in `$HOME/.config/hypr/configs/custom`
- Most functionalities have associated [keybinds](https://github.com/AymanLyesri/hyprland-conf/blob/master/.config/hypr/configs/keybinds.conf). Check them out!

> **Important**: If you encounter any problems, no matter how small, please feel free to open an issue. I’m happy to help! :)

# Additional Notes

- Machines with batteries (aka: laptops) require `upower` to be installed for battery monitoring to work properly.

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=aymanlyesri/hyprland-conf&type=Date)](https://star-history.com/#aymanlyesri/hyprland-conf&Date)

# Visuals

## Application Launcher

| Apps                                                                                                                | Emojis                                                                                    | Arithmetics                                                                               | URLs                                                                                      |
| ------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| ![clipboard_image_20241013_132106](https://github.com/user-attachments/assets/20f9ed91-79cf-41e7-bf5e-dacad8f3933b) | ![image](https://github.com/user-attachments/assets/a0ee2cb8-129a-4f38-b4f2-0636351a0c69) | ![image](https://github.com/user-attachments/assets/8449ae19-0d81-4505-9d58-7241da8dfd48) | ![image](https://github.com/user-attachments/assets/77cabaf7-1233-4f5f-9f56-c27e6e5e1ea5) |

## Right Panel

> You can customize the widget layout however you want!

| Example Layout                                                                            | Example Layout                                                                            |
| ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| ![image](https://github.com/user-attachments/assets/0e8865aa-9e3e-4b20-af7c-cce5d7cd9206) | ![image](https://github.com/user-attachments/assets/bec585c9-aece-4517-bc09-6d739a7994e9) |

## Left Panel

| Chat Bot                                                                                                                             | Booru Viewer                                                                                                                                       |
| ------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| <img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/aa1a0291-294d-434b-b8b2-1f03ad219936" /> | <img width="1920" height="1080" alt="1763917938_hyprshot" src="https://github.com/user-attachments/assets/80adc9cc-5aa1-40df-bc90-325ddfb6f0d0" /> |

## Media Player

![image](https://github.com/user-attachments/assets/1be9e780-88cd-4d9f-ba12-252784986bec)

## Wallpaper Switcher

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/84749534-449f-4c65-91ed-29810ca85327" />

## Theme Switching

| Dark Theme + Custom colors based on wallpaper                                             | Light Theme + Custom colors based on wallpaper                                            |
| ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| ![image](https://github.com/user-attachments/assets/f3ff78c1-5243-4c00-9e03-898c517cccac) | ![image](https://github.com/user-attachments/assets/7b158721-38fa-4405-9cda-7864c1bc7818) |

## User Panel

![image](https://github.com/user-attachments/assets/d88f9a5e-c7da-4e31-80db-38073dc0278c)

# Tutorials

## App launcher

- `>` `[name]` : Custom Apps
- `emoji` `[name]` : emojis
- `translate` `[text]` `>` `fr|en|es|jp...` : translate text into other languages
- `[...1+2...]` : arithmetics (maths)
- `[link]` : open the link in browser
