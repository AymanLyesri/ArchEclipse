#!/usr/bin/env python3
"""
DEFAULTS.py - Set up default custom configuration files
"""

import os
import shutil
import subprocess
from components.figlet import print_archeclipse_banner_text, print_figlet_lolcat


def main():
    """Main function"""
    print_archeclipse_banner_text()
    print_figlet_lolcat("DEFAULTS")

    home = os.path.expanduser("~")
    custom_dir = os.path.join(home, ".config/hypr/configs/custom")
    defaults_dir = os.path.join(home, ".config/hypr/configs/defaults")

    print(
        "Do you want to set up default custom files (not necessary after the first time)"
    )

    response = input("y/n: ").strip().lower()

    if response != "y":
        print("Exiting...")
        return

    print("Setting up default configuration files...")

    # Copy all files from defaults to custom
    if os.path.exists(defaults_dir):
        for filename in os.listdir(defaults_dir):
            src = os.path.join(defaults_dir, filename)
            dst = os.path.join(custom_dir, filename)

            if os.path.isfile(src):
                os.makedirs(custom_dir, exist_ok=True)
                shutil.copy2(src, dst)

    print(" Done.")


if __name__ == "__main__":
    main()
