#!/usr/bin/env python3
"""
PLUGINS.py - Install and configure Hyprland plugins
"""

import subprocess
import sys
from components.figlet import print_archeclipse_banner_text, print_figlet_lolcat


def main():
    """Main function"""
    print_archeclipse_banner_text()
    print_figlet_lolcat("PLUGINS")

    # Request sudo access
    try:
        subprocess.run(["sudo", "-v"], check=True, capture_output=True)
    except subprocess.CalledProcessError:
        print("Error: sudo access is required.")
        sys.exit(1)

    # Update and install plugins
    print("Updating hyprland plugins manager... (streaming output)")
    try:
        subprocess.run(["hyprpm", "update"], check=True)
    except subprocess.CalledProcessError as e:
        print(f"hyprpm update failed: {e}")

    print("Adding hyprland plugins... (streaming output)")
    try:
        subprocess.run(
            ["hyprpm", "add", "https://github.com/hyprwm/hyprland-plugins"],
            check=True,
        )
    except subprocess.CalledProcessError as e:
        print(f"hyprpm add (hyprland-plugins) failed: {e}")

    try:
        subprocess.run(
            ["hyprpm", "add", "https://github.com/virtcode/hypr-dynamic-cursors"],
            check=True,
        )
    except subprocess.CalledProcessError as e:
        print(f"hyprpm add (hypr-dynamic-cursors) failed: {e}")

    print("Enabling plugins... (streaming output)")
    try:
        subprocess.run(["hyprpm", "enable", "dynamic-cursors"], check=True)
    except subprocess.CalledProcessError as e:
        print(f"hyprpm enable (dynamic-cursors) failed: {e}")

    try:
        subprocess.run(["hyprpm", "enable", "hyprexpo"], check=True)
    except subprocess.CalledProcessError as e:
        print(f"hyprpm enable (hyprexpo) failed: {e}")

    print("Reloading Hyprland configuration... (streaming output)")
    try:
        subprocess.run(["hyprctl", "reload"], check=True)
    except subprocess.CalledProcessError as e:
        print(f"hyprctl reload failed: {e}")

    print("Plugins installation complete.")


if __name__ == "__main__":
    main()
