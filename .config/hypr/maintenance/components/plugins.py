#!/usr/bin/env python3
"""Hyprland plugin setup."""

from __future__ import annotations

from .utils import run_cmd, run_shell


def install_plugins() -> None:
    run_shell("echo ' ArchEclipse ' | lolcat", check=False)
    run_shell("figlet 'PLUGINS' -f slant | lolcat", check=False)

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

    run_cmd(["hyprpm", "update"])
    run_cmd(["hyprctl", "reload"], check=False)


def main() -> None:
    install_plugins()


if __name__ == "__main__":
    main()
