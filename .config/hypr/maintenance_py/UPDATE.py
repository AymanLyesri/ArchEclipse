#!/usr/bin/env python3
"""
UPDATE.py - Update ArchEclipse configuration and packages
"""

import os
import subprocess
import sys
import tempfile
import shutil
import atexit
from pathlib import Path

# Import utility modules
sys.path.insert(0, os.path.dirname(__file__))
from PRESENTATION import *
from ESSENTIALS import *

REPO_URL = "https://github.com/AymanLyesri/ArchEclipse.git"
REPO_DIR = os.path.expanduser("~")
MAINTENANCE_DIR = os.path.join(REPO_DIR, ".config/hypr/maintenance")
TEMP_DIR = None


def cleanup_temp_files():
    """Clean up temporary files"""
    global TEMP_DIR
    if TEMP_DIR and os.path.exists(TEMP_DIR):
        shutil.rmtree(TEMP_DIR, ignore_errors=True)


def register_cleanup():
    """Register cleanup to run on exit"""
    atexit.register(cleanup_temp_files)


def is_repo_intact():
    """Check if repository is intact"""
    git_dir = os.path.join(REPO_DIR, ".git")

    if not os.path.isdir(git_dir):
        return False

    # Check if it's a git repository
    result = subprocess.run(
        ["git", "-C", REPO_DIR, "rev-parse", "--is-inside-work-tree"],
        capture_output=True,
    )
    if result.returncode != 0:
        return False

    # Check origin URL
    result = subprocess.run(
        ["git", "-C", REPO_DIR, "remote", "get-url", "origin"],
        capture_output=True,
        text=True,
    )
    origin_url = result.stdout.strip()
    if origin_url != REPO_URL:
        return False

    # Check HEAD
    result = subprocess.run(
        ["git", "-C", REPO_DIR, "rev-parse", "--verify", "HEAD"], capture_output=True
    )
    if result.returncode != 0:
        return False

    # Check for corrupted objects
    result = subprocess.run(
        ["git", "-C", REPO_DIR, "fsck", "--no-progress"], capture_output=True
    )
    if result.returncode != 0:
        return False

    return True


def deploy_configs(branch):
    """Deploy configuration files"""
    global TEMP_DIR

    if is_repo_intact():
        print("🌿 Repository history intact, syncing with remote...")
        os.chdir(REPO_DIR)
        subprocess.run(["git", "checkout", branch], capture_output=True)
        subprocess.run(["git", "fetch", "origin", branch], capture_output=True)
        subprocess.run(
            ["git", "reset", "--hard", f"origin/{branch}"], capture_output=True
        )
        print("✓ Repository successfully updated from origin/{branch}.")
    else:
        print(
            "⚠️ Local git history is missing/corrupt. Falling back to fresh clone deployment."
        )

        TEMP_DIR = tempfile.mkdtemp()

        print("📦 Cloning latest repository state...")
        subprocess.run(
            [
                "git",
                "clone",
                "--depth",
                "1",
                "--single-branch",
                "--branch",
                branch,
                REPO_URL,
                TEMP_DIR,
            ],
            check=True,
            capture_output=True,
        )

        print("[1/1] Overwriting home configuration...")

        git_dir = os.path.join(REPO_DIR, ".git")
        if os.path.exists(git_dir):
            shutil.rmtree(git_dir)

        # Copy everything from TEMP_DIR to HOME
        for item in os.listdir(TEMP_DIR):
            src = os.path.join(TEMP_DIR, item)
            dst = os.path.join(REPO_DIR, item)

            if os.path.exists(dst):
                if os.path.isdir(dst):
                    shutil.rmtree(dst)
                else:
                    os.remove(dst)

            if os.path.isdir(src):
                shutil.copytree(src, dst)
            else:
                shutil.copy2(src, dst)

        print("✓ Configuration successfully updated from fresh clone.")


def ask_yes_no(prompt: str, default: str = "y") -> bool:
    """Prompt user with a y/n question and return True for yes."""
    default = default.lower()
    suffix = "(Y/n)" if default == "y" else "(y/N)"

    while True:
        print(f"{prompt} {suffix}: ", end="", flush=True)
        try:
            response = input().strip().lower()
        except EOFError:
            response = ""

        if not response:
            return default == "y"
        if response in ["y", "yes"]:
            return True
        if response in ["n", "no"]:
            return False
        print("Please answer y or n.")


def main():
    """Main function"""
    register_cleanup()

    # Send counter
    try:
        subprocess.run(
            [
                "curl",
                "-s",
                "-o",
                "/dev/null",
                "https://personal-counter-two.vercel.app/api/increment?workspace=archeclipse&counter=update",
            ],
            capture_output=True,
            timeout=5,
        )
    except Exception:
        pass

    print("")
    print("============================================================")
    print("🔄 UPDATE")
    print("============================================================")

    branch = sys.argv[1] if len(sys.argv) > 1 else "master"

    print("")
    deploy_choice = ask_yes_no("deploying the config", default="y")
    package_update_choice = ask_yes_no("package update", default="y")
    plugin_update_choice = ask_yes_no("plugin update", default="y")

    print("")

    # Request sudo access before executing steps
    print("🔐 Requesting sudo password...")
    try:
        subprocess.run(["sudo", "-v"], check=True, capture_output=True)
        print("✓ Sudo access granted\n")
    except subprocess.CalledProcessError:
        print("✗ Error: sudo access is required.")
        sys.exit(1)

    if deploy_choice:
        deploy_configs(branch)
    else:
        print("✗ Skipping configuration deployment.")

    # Load utilities
    try:
        print_main_header("UPDATE")

        run_step("⚙️", "Installing core tools", "install_core_tools")

        # Reload Bar
        print_section_header("🔄 RELOADING BAR")

        run_step(
            "🔄",
            "Reloading bar configuration",
            f"{REPO_DIR}/.config/hypr/scripts/bar.sh &",
        )

        # Package Manager Cleanup
        print_section_header("🧹 PACKAGE MANAGER CLEANUP")

        procs = ["pacman", "yay", "paru"]
        cleaned = 0

        for proc in procs:
            result = subprocess.run(["pgrep", "-x", proc], capture_output=True)
            if result.returncode == 0:
                print(f"Killing {proc}...")
                subprocess.run(["sudo", "killall", "-9", proc], capture_output=True)
                cleaned += 1

        if cleaned == 0:
            print_warning("No running package manager processes found")
        else:
            print_success(f"Killed {cleaned} process(es)")

        pacman_lock = "/var/lib/pacman/db.lck"
        if os.path.exists(pacman_lock):
            subprocess.run(["sudo", "rm", "-f", pacman_lock], capture_output=True)
            print_success("Pacman lock file removed")

        # Detect AUR Helper
        print_section_header("📥 PACKAGE UPDATES")

        aur_helper = ""
        for helper in ["yay", "paru"]:
            if command_exists(helper):
                aur_helper = helper
                break

        if package_update_choice and aur_helper:
            run_step(
                "📦",
                f"Updating necessary packages (using {aur_helper})",
                f"{REPO_DIR}/.config/hypr/pacman/install-pkgs.sh {aur_helper}",
            )
        elif package_update_choice and not aur_helper:
            print_warning("No AUR helper installed.")
        else:
            print_warning("Package update skipped by user")

        # Plugins
        print_section_header("🔌 PLUGINS")

        if plugin_update_choice:
            run_step(
                "🔌",
                "Updating plugins",
                os.path.join(REPO_DIR, ".config/hypr/maintenance_py/PLUGINS.py"),
            )
        else:
            print_warning("Plugin update skipped by user")

        # Completion
        print_section_header("✅ UPDATE COMPLETE")
        print_update_completion_message()

    except Exception as e:
        error_exit(f"Error during update: {e}")


if __name__ == "__main__":
    main()
