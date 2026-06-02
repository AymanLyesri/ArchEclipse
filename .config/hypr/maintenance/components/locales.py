#!/usr/bin/env python3
"""Locale configuration."""

from __future__ import annotations

import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parent.parent))
    from components.utils import run_cmd
else:
    from .utils import run_cmd


def add_arch_locale() -> int:
    print("Adding en_US.UTF-8 locale to Arch Linux system...")

    locale_gen = "/etc/locale.gen"
    try:
        with open(locale_gen, "r", encoding="utf-8") as handle:
            contents = handle.read()
    except FileNotFoundError:
        contents = ""

    if "en_US.UTF-8 UTF-8" in contents:
        check = run_cmd(["locale", "-a"], capture_output=True, check=False)
        if "en_US.utf8" in (check.stdout or ""):
            print("Locale en_US.UTF-8 is already installed and enabled.")
            return 0

    print("Enabling locale in /etc/locale.gen...")
    run_cmd(
        ["sudo", "sed", "-i", "s/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/", locale_gen],
        check=False,
    )
    run_cmd(
        ["sudo", "bash", "-c", "echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen"],
        check=False,
    )

    print("Generating locale (this may take a moment)...")
    run_cmd(["sudo", "locale-gen"])

    check = run_cmd(["locale", "-a"], capture_output=True, check=False)
    if "en_US.utf8" in (check.stdout or ""):
        print("Successfully added en_US.UTF-8 locale.")
        return 0

    print("Failed to add en_US.UTF-8 locale.")
    return 1


def main() -> None:
    print("Arch Linux Locale Configuration")
    print("This script will add the en_US.UTF-8 locale to your system.")
    run_cmd(["sudo", "-v"])

    exit_code = add_arch_locale()
    raise SystemExit(exit_code)


if __name__ == "__main__":
    main()
