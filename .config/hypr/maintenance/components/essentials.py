#!/usr/bin/env python3
"""Core installation helpers."""

from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path
from typing import Callable, Optional

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parent.parent))
    from components.utils import command_exists, run_cmd, run_shell, fzf_select
else:
    from .utils import command_exists, run_cmd, run_shell, fzf_select

FZF_HEIGHT = "40%"


class Colors:
    GREEN = "\033[32m"
    RED = "\033[31m"
    CYAN = "\033[36m"
    YELLOW = "\033[1;33m"
    BOLD = "\033[1m"
    RESET = "\033[0m"


def install_core_tools() -> None:
    packages_to_install: list[str] = []
    packages_names = ["git", "fzf", "figlet", "lolcat"]

    print("Checking core tools installation...")

    for package in packages_names:
        if command_exists(package):
            print(f"OK {package} is already installed.")
        else:
            print(f"MISSING {package} is not installed. Marking for installation...")
            packages_to_install.append(package)

    if packages_to_install:
        print(f"Installing: {' '.join(packages_to_install)}")
        run_cmd(["sudo", "pacman", "-S", "--noconfirm", *packages_to_install])
        print("Core tools installation completed.")
    else:
        print("All core tools are already installed.")


def _install_aur_helper(helper_name: str, repo_url: str) -> None:
    if command_exists(helper_name):
        print(f"{helper_name} is already installed.")
        return

    print(f"{helper_name} is not installed. Installing {helper_name}...")
    run_cmd(["sudo", "pacman", "-Syu", "--noconfirm"])
    run_cmd(["sudo", "pacman", "-S", "--needed", "--noconfirm", "base-devel", "git"])

    if Path(helper_name).exists():
        shutil.rmtree(helper_name)

    run_cmd(["git", "clone", repo_url])
    run_cmd(["makepkg", "-si", "--noconfirm"], cwd=Path(helper_name))
    shutil.rmtree(helper_name, ignore_errors=True)
    print(f"{helper_name} has been successfully installed.")


def install_yay() -> None:
    _install_aur_helper("yay", "https://aur.archlinux.org/yay.git")


def install_paru() -> None:
    _install_aur_helper("paru", "https://aur.archlinux.org/paru.git")


def install_browser(aur_helper: str = "yay") -> None:
    title = ""
    package = ""
    app = ""

    print("Choose a browser to install (recommended: zen-browser)")
    browsers = ["zen-browser", "firefox", "chromium", "google-chrome"]
    selection = fzf_select(browsers, height=FZF_HEIGHT)
    if not selection:
        print("No browser selected.")
        return

    print(f"Browser selected: {selection}")
    if selection == "zen-browser":
        title = "Zen Browser"
        package = "zen-browser-bin"
        app = "zen-browser"
    elif selection == "firefox":
        title = "Firefox"
        package = "firefox"
        app = "firefox"
    elif selection == "chromium":
        title = "Chromium"
        package = "chromium"
        app = "chromium"
    elif selection == "google-chrome":
        title = "Google Chrome"
        package = "google-chrome"
        app = "google-chrome"

    run_cmd([aur_helper, "-S", "--noconfirm", package])

    config_path = Path.home() / ".config/hypr/configs/defaults/browser.conf"
    config_path.write_text(
        f"exec-once = {app} \n windowrule = workspace 2 silent, match:title ^({title})$",
        encoding="utf-8",
    )


def install_discord_client(aur_helper: str = "yay") -> None:
    class_name = ""
    package = ""
    app = ""

    print("Choose a Discord client to install (recommended: legcord)")
    cords = ["legcord", "discord", "betterdiscord"]
    selection = fzf_select(cords, height=FZF_HEIGHT)
    if not selection:
        print("No Discord client selected.")
        return

    print(f"Discord client selected: {selection}")
    if selection == "legcord":
        class_name = "legcord"
        package = "legcord"
        app = "legcord"
    elif selection == "discord":
        class_name = "discord"
        package = "discord"
        app = "discord"
    elif selection == "betterdiscord":
        class_name = "BetterDiscord"
        package = "betterdiscord"
        app = "betterdiscord"

    run_cmd([aur_helper, "-S", "--noconfirm", package])

    config_path = Path.home() / ".config/hypr/configs/defaults/discord_client.conf"
    config_path.write_text(
        f"workspace = 6, gapsout:69, on-created-empty:{class_name} \n "
        "windowrule = workspace 6 silent, match:class ^.*cord$",
        encoding="utf-8",
    )


def remove_packages() -> None:
    packages_to_remove = ["dunst", "swaync"]

    installed_packages = []
    for pkg in packages_to_remove:
        if run_cmd(["pacman", "-Q", pkg], check=False).returncode == 0:
            installed_packages.append(pkg)
            run_cmd(["pkill", "-x", pkg], check=False)

    if installed_packages:
        print(f"Removing packages: {' '.join(installed_packages)}")
        run_cmd(["sudo", "pacman", "-Rns", "--noconfirm", *installed_packages])
    else:
        print("No specified packages are installed.")


def prompt_yes_no(prompt: str, default_choice: str = "none") -> bool:
    """Ask once whether to run a step. Returns True to run, False to skip."""
    default_choice = default_choice.lower()
    if default_choice not in {"y", "n", "none"}:
        default_choice = "none"

    choice_label = f"{Colors.GREEN}y{Colors.RESET}/{Colors.RED}n{Colors.RESET}"
    if default_choice == "y":
        choice_label = f"{Colors.GREEN}[Y]{Colors.RESET}/{Colors.RED}n{Colors.RESET}"
    elif default_choice == "n":
        choice_label = f"{Colors.GREEN}y{Colors.RESET}/{Colors.RED}[N]{Colors.RESET}"

    while True:
        print("")
        print(f"{Colors.CYAN}{Colors.BOLD}? {prompt}{Colors.RESET}")
        print(
            f"{Colors.CYAN}{Colors.BOLD}   Enter your choice {choice_label}{Colors.RESET}: ",
            end="",
        )
        choice = input().strip()

        if not choice:
            if default_choice == "none":
                print(
                    f"{Colors.RED}Invalid choice. Please answer Y or N.{Colors.RESET}"
                )
                continue
            choice = default_choice

        if choice.lower().startswith("y"):
            return True
        if choice.lower().startswith("n"):
            return False

        print(f"{Colors.RED}Invalid choice. Please answer Y or N.{Colors.RESET}")


def continue_prompt(
    prompt: str,
    action: Optional[Callable[[], None] | str] = None,
    default_choice: str = "none",
) -> int:
    if not prompt_yes_no(prompt, default_choice):
        print(f"{Colors.YELLOW}Step skipped by user{Colors.RESET}")
        print("")
        return 0

    if action is None:
        return 0
    try:
        if callable(action):
            action()
        else:
            run_shell(action)
        print(f"{Colors.GREEN}Step completed successfully{Colors.RESET}")
        print("")
        return 0
    except Exception as exc:  # noqa: BLE001 - report action failures
        print(f"{Colors.RED}Step failed: {exc}{Colors.RESET}")
        print("")
        return 1


__all__ = [
    "install_core_tools",
    "install_yay",
    "install_paru",
    "install_browser",
    "install_discord_client",
    "remove_packages",
    "continue_prompt",
    "prompt_yes_no",
    "fzf_select",
    "FZF_HEIGHT",
    "Colors",
]
