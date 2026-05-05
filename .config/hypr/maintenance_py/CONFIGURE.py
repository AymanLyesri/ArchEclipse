#!/usr/bin/env python3
"""
CONFIGURE.py - Configure keyboard layouts for Hyprland
"""

import os
import subprocess
import sys
from components.figlet import print_figlet_lolcat

FZF_HEIGHT = "40%"


def continue_prompt(prompt_text):
    """Prompt user for yes/no confirmation"""
    GREEN = "\033[32m"
    RED = "\033[31m"
    CYAN = "\033[36m"
    BOLD = "\033[1m"
    RESET = "\033[0m"

    while True:
        print(
            f"{CYAN}{BOLD}{prompt_text}{RESET} {GREEN}[Y]{RESET}/{RED}[N]{RESET}: ",
            end="",
            flush=True,
        )
        try:
            choice = input().strip().lower()
        except EOFError:
            choice = ""

        if choice in ["y", "yes"]:
            print(f"{GREEN}Great! Continuing...{RESET}")
            return 0
        elif choice in ["n", "no"]:
            print(f"{RED}Okay, exiting...{RESET}")
            return 1
        else:
            print(f"{RED}Please answer with Y or N.{RESET}")


def configure_keyboard():
    """Configure keyboard layouts and variants"""
    home = os.path.expanduser("~")
    hypr_dir = os.path.join(home, ".config/hypr")
    keyboard_conf = os.path.join(hypr_dir, "configs/custom/keyboard.conf")

    print_figlet_lolcat("KEYBOARD")

    # Get available layouts and variants
    try:
        result = subprocess.run(
            ["localectl", "list-x11-keymap-layouts"], capture_output=True, text=True
        )
        kb_layouts = result.stdout.strip().split("\n")
    except Exception as e:
        print(f"Error getting keyboard layouts: {e}")
        return

    try:
        result = subprocess.run(
            ["localectl", "list-x11-keymap-variants"], capture_output=True, text=True
        )
        kb_variants = result.stdout.strip().split("\n")
    except Exception as e:
        print(f"Error getting keyboard variants: {e}")
        return

    selected_layouts = []
    selected_variants = []

    while True:
        print("Configuring keyboard layout for Hyprland... (eg: us, es, fr, de, etc)")

        # Use fzf to select layout
        try:
            fzf_input = "\n".join(kb_layouts)
            result = subprocess.run(
                f"echo {chr(39)}{fzf_input}{chr(39)} | fzf --height {FZF_HEIGHT}",
                shell=True,
                capture_output=True,
                text=True,
            )
            new_layout = result.stdout.strip()
        except Exception as e:
            print(f"Error selecting layout: {e}")
            return

        if not new_layout:
            print("No layout selected. Please select a layout.")
            continue

        print(f"Selected layout: {new_layout}")
        selected_layouts.append(new_layout)

        # Variant selection
        print(
            "OPTIONAL (tip: leave empty for qwerty): Configuring Custom keyboard variant for Hyprland... (eg: intl, dvorak, etc)"
        )

        try:
            fzf_input = "\n".join(kb_variants)
            result = subprocess.run(
                f"echo {chr(39)}{fzf_input}{chr(39)} | fzf --height {FZF_HEIGHT}",
                shell=True,
                capture_output=True,
                text=True,
            )
            new_variant = result.stdout.strip()
        except Exception as e:
            print(f"Error selecting variant: {e}")
            return

        if new_variant:
            print(f"Selected variant: {new_variant}")
            selected_variants.append(new_variant)
        else:
            print("No variant selected. Leaving it empty.")
            selected_variants.append("")

        # Ask if user wants to add more
        ret = continue_prompt("Would you like to add another layout and variant pair?")
        if ret != 0:
            break

    # Apply the changes to the config file
    os.makedirs(os.path.dirname(keyboard_conf), exist_ok=True)

    layouts_str = ",".join(selected_layouts)
    variants_str = ",".join(selected_variants)

    config_content = (
        f"input {{\n\tkb_layout={layouts_str}\n\tkb_variant={variants_str}\n}}\n"
    )

    with open(keyboard_conf, "w") as f:
        f.write(config_content)

    print(f"Keyboard layouts have been configured to: {layouts_str}")
    print(f"Keyboard variants have been configured to: {variants_str}")

    # Reload the configuration
    subprocess.run(["hyprctl", "reload"], capture_output=True)


def main():
    """Main function"""
    configure_keyboard()


if __name__ == "__main__":
    main()
