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
    "gst-libav",
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
    "fd",
    "jq",
    "translate-shell",
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
    "hyprpm",
    # Audio / video and media
    "swayimg",
    "foot",
    "grimblast-git",
    "grim",
    "wf-recorder",
    "vlc",
    "imagemagick",
    "mpvpaper",
    "walleclipse-git",
    "zenity",
    # Themes and UI enhancements
    "sddm",
    "where-is-my-sddm-theme-git",
    "cwal",
    "fastfetch",
    "starship",
    "libadwaita",
    "gvfs",
    "hyprpolkitagent",
    "ttf-jetbrains-mono-nerd",
    "noto-fonts-emoji",
    "phinger-cursors",
    "whitesur-gtk-theme",
    "whitesur-icon-theme",
    "quickshell",
    "qt6-multimedia",
    "c-lolcat",
    # Extra build tools
    "meson",
    "cpio",
    "pkg-config",
    "libwebp-utils",
]

PROTECTED_PACKAGES = {
    "hyprland": "the running desktop session",
    "hyprpm": "plugin manager for Hyprland",
    "hyprpolkitagent": "graphical authentication agent",
    "hyprcursor": "native cursor format library",
    "foot": "terminal",
    "networkmanager": "network connectivity",
    "networkmanager-applet": "network connectivity applet",
    "wl-clipboard": "Wayland clipboard utility",
    "pipewire": "system audio",
    "bluez": "Bluetooth protocol stack",
    "bluez-utils": "Bluetooth command-line utilities",
    "gvfs": "virtual file system backend for file managers",
    "sddm": "the display manager",
    "starship": "the current shell configuration",
}


def install_packages(aur_helper: str = "yay") -> None:
    run_shell("figlet 'PACKAGES' -f slant | lolcat", check=False)

    run_cmd([aur_helper, "-Syu", "--needed", *PACKAGES])


def uninstall_packages(*, remove_zsh: bool = False) -> None:
    shell_packages = {
        "zsh",
        "zsh-auto-notify",
        "zsh-history-substring-search",
        "zsh-syntax-highlighting",
        "zsh-autosuggestions-git",
        "zsh-sudo-git",
        "fzf-tab-git",
    }
    candidates = [
        package for package in PACKAGES if remove_zsh or package not in shell_packages
    ]
    installed: list[str] = []
    for package in candidates:
        result = run_cmd(["pacman", "-Qq", package], check=False, capture_output=True)
        if result.returncode == 0:
            installed.extend(
                installed_package
                for installed_package in result.stdout.splitlines()
                if installed_package
            )
    installed = list(dict.fromkeys(installed))

    protected = [package for package in installed if package in PROTECTED_PACKAGES]
    installed = [package for package in installed if package not in PROTECTED_PACKAGES]
    if protected:
        print("Keeping protected packages:")
        for package in protected:
            print(f"  {package}: {PROTECTED_PACKAGES[package]}")

    if not installed:
        if not protected:
            print("No removable installed ArchEclipse-list packages found.")
        return

    print(
        "The following installed packages will be offered for removal. "
        "Packages required by other software will be kept:"
    )
    print(" ".join(installed))
    run_cmd(["sudo", "-v"])

    skipped: list[str] = []
    for package in installed:
        result = run_cmd(
            ["sudo", "pacman", "-Rns", package],
            check=False,
        )
        if result.returncode != 0:
            skipped.append(package)

    if skipped:
        print("Kept packages that Pacman could not remove safely: " + " ".join(skipped))


def main() -> None:
    aur_helper = sys.argv[1] if len(sys.argv) > 1 else "yay"
    install_packages(aur_helper)


if __name__ == "__main__":
    main()
