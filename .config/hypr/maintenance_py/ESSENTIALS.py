#!/usr/bin/env python3
"""
ESSENTIALS.py - Essential utility functions for ArchEclipse scripts
Provides package management and utility functions
"""

import subprocess
import os
import sys
from typing import List, Optional

FZF_HEIGHT = "40%"


def command_exists(command: str) -> bool:
    """Check if a command exists in PATH"""
    result = subprocess.run(["which", command], capture_output=True)
    return result.returncode == 0


def install_core_tools() -> None:
    """Install core tools: git, fzf, figlet, and lolcat"""
    packages_to_install = []
    packages_names = ["git", "fzf", "figlet", "lolcat"]

    print("Checking core tools installation...")

    for package in packages_names:
        if command_exists(package):
            print(f"✓ {package} is already installed.")
        else:
            print(f"✗ {package} is not installed. Marking for installation...")
            packages_to_install.append(package)

    if packages_to_install:
        print(f"Installing: {' '.join(packages_to_install)}")
        subprocess.run(
            ["sudo", "pacman", "-S", "--noconfirm"] + packages_to_install, check=False
        )
        print("Core tools installation completed.")
    else:
        print("All core tools are already installed.")


def install_yay() -> None:
    """Install yay AUR helper"""
    if command_exists("yay"):
        print("yay is already installed.")
        return

    print("yay is not installed. Installing yay...")

    # Update system packages
    subprocess.run(["sudo", "pacman", "-Syu", "--noconfirm"], check=False)

    # Install base-devel and git if not already installed
    subprocess.run(
        ["sudo", "pacman", "-S", "--needed", "--noconfirm", "base-devel", "git"],
        check=False,
    )

    # Clone yay repository from the AUR
    subprocess.run(["git", "clone", "https://aur.archlinux.org/yay.git"], check=False)

    # Build and install yay
    if os.path.exists("yay"):
        os.chdir("yay")
        subprocess.run(["makepkg", "-si", "--noconfirm"], check=False)
        os.chdir("..")
        subprocess.run(["rm", "-rf", "yay"], check=False)
        print("yay has been successfully installed.")


def install_paru() -> None:
    """Install paru AUR helper"""
    if command_exists("paru"):
        print("paru is already installed.")
        return

    print("paru is not installed. Installing paru...")

    # Update system packages
    subprocess.run(["sudo", "pacman", "-Syu", "--noconfirm"], check=False)

    # Install base-devel and git if not already installed
    subprocess.run(
        ["sudo", "pacman", "-S", "--needed", "--noconfirm", "base-devel", "git"],
        check=False,
    )

    # Clone paru repository from the AUR
    subprocess.run(["git", "clone", "https://aur.archlinux.org/paru.git"], check=False)

    # Build and install paru
    if os.path.exists("paru"):
        os.chdir("paru")
        subprocess.run(["makepkg", "-si", "--noconfirm"], check=False)
        os.chdir("..")
        subprocess.run(["rm", "-rf", "paru"], check=False)
        print("paru has been successfully installed.")


def install_browser(aur_helper: str = "yay") -> None:
    """Install a browser using fzf selection"""
    browsers = ["zen-browser", "firefox", "chromium", "google-chrome"]

    print("Choose a browser to install (recommended: zen-browser)")

    # Use fzf to select browser
    try:
        result = subprocess.run(
            f"echo {chr(39)}"
            + "\\n".join(browsers)
            + f"{chr(39)} | fzf --height {FZF_HEIGHT}",
            shell=True,
            capture_output=True,
            text=True,
        )
        browser = result.stdout.strip()
    except Exception as e:
        print(f"Error selecting browser: {e}")
        return

    if not browser:
        print("No browser selected")
        return

    print(f"Browser selected: {browser}")

    browser_config = {
        "zen-browser": {
            "title": "Zen Browser",
            "package": "zen-browser-bin",
            "app": "zen-browser",
        },
        "firefox": {"title": "Firefox", "package": "firefox", "app": "firefox"},
        "chromium": {"title": "Chromium", "package": "chromium", "app": "chromium"},
        "google-chrome": {
            "title": "Google Chrome",
            "package": "google-chrome",
            "app": "google-chrome",
        },
    }

    if browser not in browser_config:
        print(f"Unknown browser: {browser}")
        return

    config = browser_config[browser]
    package = config["package"]
    app = config["app"]
    title = config["title"]

    # Install browser
    subprocess.run([aur_helper, "-S", "--noconfirm", package], check=False)

    # Create browser config
    home = os.path.expanduser("~")
    browser_conf_path = os.path.join(home, ".config/hypr/configs/defaults/browser.conf")

    with open(browser_conf_path, "w") as f:
        f.write(
            f"exec-once = {app}\nwindowrule = workspace 2 silent, match:title ^({title})$\n"
        )


def install_discord_client(aur_helper: str = "yay") -> None:
    """Install a Discord client using fzf selection"""
    cords = ["legcord", "discord", "betterdiscord"]

    print("Choose a Discord client to install (recommended: legcord)")

    # Use fzf to select client
    try:
        result = subprocess.run(
            f"echo {chr(39)}"
            + "\\n".join(cords)
            + f"{chr(39)} | fzf --height {FZF_HEIGHT}",
            shell=True,
            capture_output=True,
            text=True,
        )
        cord = result.stdout.strip()
    except Exception as e:
        print(f"Error selecting Discord client: {e}")
        return

    if not cord:
        print("No Discord client selected")
        return

    print(f"Discord client selected: {cord}")

    cord_config = {
        "legcord": {"class": "legcord", "package": "legcord", "app": "legcord"},
        "discord": {"class": "discord", "package": "discord", "app": "discord"},
        "betterdiscord": {
            "class": "BetterDiscord",
            "package": "betterdiscord",
            "app": "betterdiscord",
        },
    }

    if cord not in cord_config:
        print(f"Unknown Discord client: {cord}")
        return

    config = cord_config[cord]
    package = config["package"]
    app = config["app"]
    discord_class = config["class"]

    # Install Discord client
    subprocess.run([aur_helper, "-S", "--noconfirm", package], check=False)

    # Create Discord config
    home = os.path.expanduser("~")
    discord_conf_path = os.path.join(
        home, ".config/hypr/configs/defaults/discord_client.conf"
    )

    with open(discord_conf_path, "w") as f:
        f.write(
            f"workspace = 6, gapsout:69, on-created-empty:{app}\nwindowrule = workspace 6 silent, match:class ^.*cord$\n"
        )


def remove_packages() -> None:
    """Remove specified packages"""
    packages_to_remove = ["dunst", "swaync"]

    installed_packages = []

    for pkg in packages_to_remove:
        result = subprocess.run(["pacman", "-Q", pkg], capture_output=True)
        if result.returncode == 0:
            installed_packages.append(pkg)
            # Kill running processes
            subprocess.run(["pkill", "-x", pkg], capture_output=True)

    if installed_packages:
        print(f"Removing packages: {' '.join(installed_packages)}")
        subprocess.run(
            ["sudo", "pacman", "-Rns", "--noconfirm"] + installed_packages, check=False
        )
    else:
        print("No specified packages are installed.")


def continue_prompt(
    prompt: str, command: Optional[str] = None, default_choice: str = "none"
) -> int:
    """
    Prompt user for confirmation and optionally run a command
    Returns 0 for yes/continue, 1 for no/skip
    """
    GREEN = "\033[32m"
    RED = "\033[31m"
    CYAN = "\033[36m"
    YELLOW = "\033[1;33m"
    BOLD = "\033[1m"
    NC = "\033[0m"
    RESET = "\033[0m"

    # Determine choice label
    if default_choice.lower() in ["y", "yes"]:
        default_choice_normalized = "y"
        choice_label = f"{GREEN}[Y]{RESET}/{RED}n{RESET}"
    elif default_choice.lower() in ["n", "no"]:
        default_choice_normalized = "n"
        choice_label = f"{GREEN}y{RESET}/{RED}[N]{RESET}"
    else:
        default_choice_normalized = "none"
        choice_label = f"{GREEN}y{RESET}/{RED}n{RESET}"

    while True:
        print("")
        print(f"{CYAN}{BOLD}❓ {prompt}{RESET}")
        print(
            f"{CYAN}{BOLD}   Enter your choice {choice_label}{RESET}: {NC}",
            end="",
            flush=True,
        )

        try:
            choice = input().strip().lower()
        except EOFError:
            choice = ""

        print("")

        # Apply default when Enter is pressed with no explicit answer
        if not choice:
            if default_choice_normalized == "none":
                print(f"{RED}✗ Invalid choice. Please answer Y or N.{RESET}")
                continue
            choice = default_choice_normalized

        if choice in ["y", "yes"]:
            print("")
            if command:
                # Prefer executing Python functions when possible (use PRESENTATION.execute_command)
                try:
                    import importlib

                    presentation = importlib.import_module("PRESENTATION")
                    exit_code = presentation.execute_command(command)
                except Exception:
                    result = subprocess.run(command, shell=True)
                    exit_code = result.returncode
                if exit_code == 0:
                    print(f"{GREEN}✓ Step completed successfully{RESET}")
                else:
                    print(f"{RED}✗ Step failed with exit code {exit_code}{RESET}")
                    print("")
                    return exit_code
            print("")
            return 0
        elif choice in ["n", "no"]:
            print(f"{YELLOW}⊘ Step skipped by user{RESET}")
            print("")
            return 0
        else:
            print(f"{RED}✗ Invalid choice. Please answer Y or N.{RESET}")


if __name__ == "__main__":
    # This module is meant to be imported, not run directly
    print("This is a utility module. Import it in other scripts.")
