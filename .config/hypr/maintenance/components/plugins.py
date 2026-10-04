#!/usr/bin/env python3
"""Hyprland plugin setup."""

from __future__ import annotations

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


def remove_plugins() -> None:
    plugins = [
        ("hyprland-plugins", "https://github.com/hyprwm/hyprland-plugins"),
        ("dynamic-cursors", "https://github.com/virtcode/hypr-dynamic-cursors"),
    ]

    result = run_cmd(["hyprpm", "list"], capture_output=True, check=False)
    if result.returncode != 0:
        raise RuntimeError("Could not list installed Hyprland plugins with hyprpm.")

    installed = [
        (name, repo)
        for name, repo in plugins
        if name in (result.stdout or "")
    ]
    if not installed:
        print("No ArchEclipse Hyprland plugin repositories are installed.")
        return

    for name, repo in installed:
        print(f"Removing Hyprland plugin repository: {name}")
        run_cmd(["hyprpm", "remove", repo])

    run_cmd(["hyprpm", "reload"])
    run_cmd(["hyprctl", "reload"], check=False)


def main() -> None:
    install_plugins()


if __name__ == "__main__":
    main()
