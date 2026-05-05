#!/usr/bin/env python3
"""
LOCALES.py - Configure system locales on Arch Linux
"""

import subprocess
import sys
import os
from components.figlet import print_figlet_lolcat


def add_arch_locale():
    """Add en_US.UTF-8 locale to Arch Linux system"""
    print("Adding en_US.UTF-8 locale to Arch Linux system...")

    # Check if locale is already enabled
    try:
        result = subprocess.run(
            ["grep", "^en_US.UTF-8 UTF-8", "/etc/locale.gen"], capture_output=True
        )
        if result.returncode == 0:
            # Check if locale is actually generated
            result = subprocess.run(["locale", "-a"], capture_output=True, text=True)
            if "en_US.utf8" in result.stdout:
                print("Locale en_US.UTF-8 is already installed and enabled.")
                return 0
    except Exception as e:
        print(f"Error checking locale: {e}")

    # Uncomment the locale in locale.gen
    print("Enabling locale in /etc/locale.gen...")

    try:
        # Try sed first
        subprocess.run(
            [
                "sudo",
                "sed",
                "-i",
                "s/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/",
                "/etc/locale.gen",
            ],
            check=False,
        )
    except Exception as e:
        print(f"Error modifying locale.gen: {e}")
        # Fallback: append to file
        try:
            result = subprocess.run(
                ["echo", "en_US.UTF-8 UTF-8"], capture_output=True, text=True
            )
            subprocess.run(
                ["sudo", "tee", "-a", "/etc/locale.gen"],
                input=result.stdout.encode(),
                capture_output=True,
            )
        except Exception as e:
            print(f"Error appending to locale.gen: {e}")
            return 1

    # Generate the locale
    print("Generating locale (this may take a moment)...")
    result = subprocess.run(["sudo", "locale-gen"], capture_output=True)

    if result.returncode != 0:
        print(f"Error generating locale")
        return 1

    # Verify the locale was added
    try:
        result = subprocess.run(["locale", "-a"], capture_output=True, text=True)
        if "en_US.utf8" in result.stdout:
            print("Successfully added en_US.UTF-8 locale.")
            return 0
        else:
            print("Failed to add en_US.UTF-8 locale.")
            return 1
    except Exception as e:
        print(f"Error verifying locale: {e}")
        return 1


def main():
    """Main function"""
    print_figlet_lolcat("LOCALES")

    print("Arch Linux Locale Configuration")
    print("This script will add the en_US.UTF-8 locale to your system.")

    # Prompt for sudo password upfront
    try:
        subprocess.run(["sudo", "-v"], check=True, capture_output=True)
    except subprocess.CalledProcessError:
        print("Error: sudo access is required to modify system locales.")
        sys.exit(1)

    exit_code = add_arch_locale()
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
