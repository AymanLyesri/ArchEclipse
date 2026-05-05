#!/usr/bin/env python3
"""
INSTALL.py - ArchEclipse installation script
"""

import os
import subprocess
import sys
import shutil
import tempfile
import atexit

# Add current directory to path for imports
sys.path.insert(0, os.path.dirname(__file__))
from PRESENTATION import *
from ESSENTIALS import *

CONF_DIR = os.path.join(os.path.expanduser("~"), "ArchEclipse")
TEMP_DIR = None


def cleanup():
    """Cleanup function"""
    global TEMP_DIR
    if TEMP_DIR and os.path.exists(TEMP_DIR):
        shutil.rmtree(TEMP_DIR, ignore_errors=True)


def register_cleanup():
    """Register cleanup"""
    atexit.register(cleanup)


def sync_configuration_files():
    """Sync configuration files"""
    home = os.path.expanduser("~")

    if not os.path.exists(home):
        error_exit(f"HOME directory not found: {home}")

    if not os.path.exists(CONF_DIR):
        error_exit(f"Source directory not found: {CONF_DIR}")

    print(f"Preparing copy operation from {CONF_DIR} to {home}...")
    print(f"Step 1/2: Removing existing {home}/.config...")

    config_dir = os.path.join(home, ".config")
    if os.path.exists(config_dir) or os.path.islink(config_dir):
        subprocess.run(["sudo", "rm", "-rf", config_dir], check=True)

    print(f"Step 2/2: Copying ArchEclipse content into {home}...")

    for item in os.listdir(CONF_DIR):
        src = os.path.join(CONF_DIR, item)
        dst = os.path.join(home, item)

        if os.path.exists(dst) or os.path.islink(dst):
            if os.path.isdir(dst) and not os.path.islink(dst):
                shutil.rmtree(dst)
            else:
                os.remove(dst)

        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    print("Copy completed successfully.")


def main():
    """Main function"""
    register_cleanup()

    # Counter for installations
    try:
        subprocess.run(
            [
                "curl",
                "-s",
                "-o",
                "/dev/null",
                "https://personal-counter-two.vercel.app/api/increment?workspace=archeclipse&counter=install",
            ],
            capture_output=True,
            timeout=5,
        )
    except Exception:
        pass

    # Request sudo access
    print("🔐 Requesting sudo password...")
    try:
        subprocess.run(["sudo", "-v"], check=True, capture_output=True)
        print("✓ Sudo access granted\n")
    except subprocess.CalledProcessError:
        error_exit("Error: sudo access is required.")

    # Clone repository
    if os.path.exists(CONF_DIR):
        print(f"🔄 Repository already exists at {CONF_DIR}; overwriting")
        shutil.rmtree(CONF_DIR)

    branch = sys.argv[1] if len(sys.argv) > 1 else "master"

    print("Cloning ArchEclipse repository (latest commit only)...")
    result = subprocess.run(
        [
            "git",
            "clone",
            "--depth",
            "1",
            "--single-branch",
            "--branch",
            branch,
            "https://github.com/AymanLyesri/ArchEclipse.git",
            CONF_DIR,
        ],
        capture_output=True,
    )
    if result.returncode != 0:
        error_exit("Failed to clone repository")

    os.chdir(CONF_DIR)

    print(f"Updating repository to '{branch}' branch...")
    result = subprocess.run(
        ["git", "fetch", "--depth", "1", "origin", branch], capture_output=True
    )
    if result.returncode != 0:
        error_exit("Failed to fetch repository")

    subprocess.run(["git", "checkout", branch], capture_output=True)
    subprocess.run(["git", "reset", "--hard", "FETCH_HEAD"], capture_output=True)

    print("")

    # Set paths
    maintenance_dir = os.path.join(CONF_DIR, ".config/hypr/maintenance")

    # Install core tools early
    print("Installing core tools...")
    try:
        install_core_tools()
    except Exception as e:
        error_exit(f"Failed to install core tools: {e}")

    print("")

    # Display main header (now lolcat and figlet are available)
    print_main_header("INSTALL")

    print_section_header("📦 REPOSITORY SETUP")
    print_success("Repository cloned and ready\n")

    print_section_header("🔧 AUR HELPER SELECTION")

    print(f"{BOLD}{YELLOW}📋 Select an AUR helper to install packages:{NC}")
    print("")
    print(f"{CYAN}  [1]{NC} {BOLD}yay{NC}  - AUR helper (Rust based)")
    print(f"{CYAN}  [2]{NC} {BOLD}paru{NC} - AUR helper (Rust based)")
    print("")

    aur_helpers = ["yay", "paru"]

    # Use fzf to select
    try:
        result = subprocess.run(
            f"echo {chr(39)}"
            + "\\n".join(aur_helpers)
            + f"{chr(39)} | fzf --height 25",
            shell=True,
            capture_output=True,
            text=True,
        )
        aur_helper = result.stdout.strip()
    except Exception:
        error_exit("No AUR helper selected. Exiting.")

    if not aur_helper:
        error_exit("No AUR helper selected. Exiting.")

    print("")
    print_success(f"AUR helper selected: {BOLD}{MAGENTA}{aur_helper}{NC}\n")

    if aur_helper == "yay":
        run_section_step("⚙️", f"Installing {BOLD}yay{NC}", "install_yay")
    elif aur_helper == "paru":
        run_section_step("⚙️", f"Installing {BOLD}paru{NC}", "install_paru")
    else:
        error_exit("Invalid AUR helper selected")

    print("")

    print_section_header("💾 CONFIGURATION FILES")

    # Note: These scripts are called from bash maintenance directory
    run_interactive_step(
        "📁",
        f"Backing up dotfiles from {BOLD}.config{NC}",
        f"{os.path.join(os.path.expanduser('~'), '.config/hypr/maintenance/BACKUP.sh')}",
    )

    run_interactive_step(
        "📋",
        f"Copying configuration files to {os.path.expanduser('~')}",
        "sync_configuration_files",
    )

    print_section_header("⌨️ KEYBOARD CONFIGURATION (optional)")

    run_interactive_step(
        "🔨",
        "Setting up keyboard configuration (optional)",
        f"{os.path.join(os.path.expanduser('~'), '.config/hypr/maintenance/CONFIGURE.sh')}",
    )

    print_section_header("📦 PACKAGE MANAGEMENT")

    run_interactive_step("🧹", "Removing unwanted packages", "remove_packages")

    run_interactive_step(
        "📥",
        f"Installing necessary packages (using {BOLD}{aur_helper}{NC})",
        f"{os.path.join(CONF_DIR, '.config/hypr/pacman/install-pkgs.sh')} {aur_helper}",
    )

    print_section_header("🎨 SYSTEM THEME & APPEARANCE")

    run_interactive_step(
        "🖨️",
        "Setting up SDDM theme",
        f"{os.path.join(os.path.expanduser('~'), '.config/hypr/maintenance/SDDM.sh')}",
    )

    run_section_step(
        "⚙️",
        "Applying default configurations",
        f"{os.path.join(os.path.expanduser('~'), '.config/hypr/maintenance/DEFAULTS.sh')}",
    )

    run_section_step(
        "🖼️",
        "Setting up wallpapers",
        f"{os.path.join(os.path.expanduser('~'), '.config/hypr/maintenance/WALLPAPERS.sh')}",
    )

    print_section_header("🔌 PLUGINS & TWEAKS")

    run_section_step(
        "🔌",
        "Installing plugins",
        f"{os.path.join(os.path.expanduser('~'), '.config/hypr/maintenance/PLUGINS.sh')}",
    )

    run_section_step(
        "✨",
        "Applying system tweaks",
        f"{os.path.join(os.path.expanduser('~'), '.config/hypr/maintenance/TWEAKS.sh')}",
    )

    print_section_header("✅ INSTALLATION COMPLETE")

    print_install_completion_message()


if __name__ == "__main__":
    main()
