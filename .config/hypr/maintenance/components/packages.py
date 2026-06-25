#!/usr/bin/env python3
"""Install packages from the embedded package list."""

from __future__ import annotations

import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parent.parent))
    from components.utils import run_shell, run_cmd
else:
    from .utils import run_shell, run_cmd

# ---------------------------------------------------------------------------
# Package list (ported from pacman/pkglist.txt)
# Lines starting with '#' and blank lines are ignored at install time.
# ---------------------------------------------------------------------------
PACKAGES: list[str] = [
    # General utilities
    "aylurs-gtk-shell-git",
    "gst-libav",
    "libastal-meta",
    "bat",
    "bc",
    "figlet",
    "git",
    "p7zip",
    "wl-clipboard",
    "lsd",
    "cron",

    # Development tools
    "socat",
    "btop",
    "dart-sass",
    "sassc",
    "fd",
    "jq",
    "translate-shell",
    "python2-bin",
    "python-requests",
    "python-pillow",
    "zsh",
    "zsh-auto-notify",
    "zsh-history-substring-search",
    "zsh-syntax-highlighting",
    "zsh-autosuggestions-git",
    "zsh-sudo-git",
    "fzf-tab-git",

    # System and network management
    "bluez",
    "bluez-utils",
    "blueman-git",
    "network-manager-applet",
    "networkmanager",
    "pamixer",
    "pavucontrol",
    "playerctl",
    "pipewire",
    "brightnessctl",
    "hyprcursor",
    "hyprland",

    # Audio / video and media
    "swayimg",
    "kitty",
    "grimblast-git",
    "grim",
    "wf-recorder",
    "vlc",
    "imagemagick",
    "mpvpaper",
    "zenity",

    # Themes and UI enhancements
    "sddm",
    "where-is-my-sddm-theme-git",
    "cwal",
    "fastfetch",
    "starship",
    "gtk4",
    "libadwaita",
    "gnome-themes-extra",
    "gvfs",
    "hyprlock",
    "hyprpaper",
    "hyprpolkitagent",
    "ttf-jetbrains-mono-nerd",
    "noto-fonts-emoji",
    "phinger-cursors",
    "whitesur-gtk-theme",
    "whitesur-icon-theme",
    "kvantum",
    "kvantum-theme-whitesur-git",
    "qt5ct",
    "qt6ct-kde",
    "c-lolcat",

    # Extra build tools
    "cmake",
    "meson",
    "cpio",
    "pkg-config",
    "gcc",
    "libwebp-utils",
]


def install_packages(aur_helper: str = "yay") -> None:
    run_shell("figlet 'PACKAGES' -f slant | lolcat", check=False)

    pkg_input = "\n".join(PACKAGES)
    run_cmd(
        [aur_helper, "-Syu", "--needed", "-"],
        input_text=pkg_input,
    )


def main() -> None:
    aur_helper = sys.argv[1] if len(sys.argv) > 1 else "yay"
    install_packages(aur_helper)


if __name__ == "__main__":
    main()
