#!/usr/bin/env python3
"""Configure keyboard layouts and variants."""

from __future__ import annotations

import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parent.parent))
    from components.essentials import FZF_HEIGHT
    from components.utils import run_cmd, run_shell, fzf_select
else:
    from .essentials import FZF_HEIGHT
    from .utils import run_cmd, run_shell, fzf_select


def configure_keyboard() -> None:
    run_shell("figlet 'KEYBOARD' -f slant | lolcat", check=False)

    layouts_output = run_cmd(
        ["localectl", "list-x11-keymap-layouts"], capture_output=True
    )
    variants_output = run_cmd(
        ["localectl", "list-x11-keymap-variants"], capture_output=True
    )

    kb_layouts = [
        line for line in (layouts_output.stdout or "").splitlines() if line.strip()
    ]
    kb_variants = [
        line for line in (variants_output.stdout or "").splitlines() if line.strip()
    ]

    selected_layouts: list[str] = []
    selected_variants: list[str] = []

    while True:
        print("Configuring keyboard layout for Hyprland (eg: us, es, fr, de, etc)")
        new_layout = fzf_select(kb_layouts, height=FZF_HEIGHT)
        if not new_layout:
            print("No layout selected. Please select a layout.")
            continue

        print(f"Selected layout: {new_layout}")
        selected_layouts.append(new_layout)

        print("Optional: select a keyboard variant (eg: intl, dvorak) or leave empty")
        new_variant = fzf_select(kb_variants, height=FZF_HEIGHT)
        if not new_variant:
            print("No variant selected. Leaving it empty.")
            new_variant = ""
        else:
            print(f"Selected variant: {new_variant}")

        selected_variants.append(new_variant)

        if not _prompt_yes_no("Would you like to add another layout and variant pair?"):
            break

    layout_value = ",".join(selected_layouts)
    variant_value = ",".join(selected_variants)

    keyboard_conf = Path.home() / ".config/hypr/config/custom/keyboard.lua"
    keyboard_conf.parent.mkdir(parents=True, exist_ok=True)
    keyboard_conf.write_text(
        "hl.config({\n"
        "    input = {\n"
        f'        kb_layout = "{layout_value}",\n'
        f'        kb_variant = "{variant_value}",\n'
        "    },\n"
        "})\n",
        encoding="utf-8",
    )

    print(f"Keyboard layouts have been configured to: {layout_value}")
    print(f"Keyboard variants have been configured to: {variant_value}")

    run_cmd(["hyprctl", "reload"], check=False)


def main() -> None:
    configure_keyboard()


if __name__ == "__main__":
    main()


def _prompt_yes_no(prompt: str) -> bool:
    while True:
        choice = input(f"{prompt} [Y/N]: ").strip().lower()
        if choice in {"y", "yes"}:
            return True
        if choice in {"n", "no"}:
            return False
        print("Please answer Y or N.")
