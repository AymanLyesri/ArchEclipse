#!/usr/bin/env python3
"""Hyprland plugin setup."""

from __future__ import annotations

import os
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parent.parent))
    from components.utils import run_cmd, run_shell
else:
    from .utils import run_cmd, run_shell


def install_plugins() -> None:
    run_shell("echo ' ArchEclipse ' | lolcat", check=False)
    run_shell("figlet 'PLUGINS' -f slant | lolcat", check=False)

    # hyprpm needs a running Hyprland to know which version to build against.
    if not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        print("Hyprland is not running; skipping plugins.")
        print("Run this step again from inside a Hyprland session:")
        print("  python3 ~/ArchEclipse/.config/hypr/maintenance/components/plugins.py")
        return

    run_cmd(["hyprpm", "update"])

    plugins = [
        ("hyprland-plugins", "https://github.com/hyprwm/hyprland-plugins"),
        ("dynamic-cursors", "https://github.com/virtcode/hypr-dynamic-cursors"),
    ]

    for plugin, repo in plugins:
        result = run_cmd(["hyprpm", "list"], capture_output=True, check=False)
        if plugin in (result.stdout or ""):
            print(f"{plugin} already installed")
            continue

        run_cmd(["hyprpm", "add", repo])
        run_cmd(["hyprpm", "enable", plugin])

    run_cmd(["hyprctl", "reload"], check=False)


def main() -> None:
    install_plugins()


if __name__ == "__main__":
    main()
