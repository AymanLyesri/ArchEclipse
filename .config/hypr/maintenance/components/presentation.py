#!/usr/bin/env python3
"""Terminal presentation helpers."""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Callable, Optional

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parent.parent))
    from components.essentials import Colors, continue_prompt
    from components.utils import read_json_output, run_shell
else:
    from .essentials import Colors, continue_prompt
    from .utils import read_json_output, run_shell

BOLD = "\033[1m"
CYAN = "\033[0;36m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
MAGENTA = "\033[0;35m"
RED = "\033[0;31m"
BLUE = "\033[0;34m"
NC = "\033[0m"


def error_exit(message: str) -> None:
    print(f"{RED}ERROR {message}{NC}")
    raise SystemExit(1)


def print_section_header(title: str) -> None:
    print("")
    print(f"{BOLD}{CYAN}{'=' * 62}{NC}")
    print(f"{BOLD}{MAGENTA}{title}{NC}")
    print(f"{BOLD}{CYAN}{'=' * 62}{NC}")
    print("")


def print_step(step: str, description: str) -> None:
    print(f"{YELLOW}{step}{NC} {description}")


def print_success(message: str) -> None:
    print(f"{GREEN}OK{NC} {message}")


def print_warning(message: str) -> None:
    print(f"{YELLOW}WARN{NC} {message}")


def print_main_header(mode: str = "INSTALL & UPDATE") -> None:
    subtitle = "ArchEclipse Installation & Configuration"
    if mode == "UPDATE":
        subtitle = "ArchEclipse Update & Synchronization"

    run_shell(f"figlet '{mode}' -f slant | lolcat", check=False)
    print(f"{BOLD}{CYAN}{'=' * 63}{NC}")
    print(f"{BOLD}{MAGENTA}{subtitle}{NC}")
    print(f"{BOLD}{CYAN}{'=' * 63}{NC}")
    print("")


def print_install_completion_message() -> None:
    print(f"{BOLD}{GREEN}{'=' * 63}{NC}")
    print(f"{BOLD}{GREEN}Installation completed successfully.{NC}")
    print(f"{BOLD}{GREEN}{'=' * 63}{NC}")
    print("")
    print(f"{YELLOW}Please reboot your system to apply all changes:{NC}")
    print("")
    print(f"{CYAN}sudo reboot{NC}")
    print("")


def print_update_completion_message() -> None:
    print(f"{BOLD}{GREEN}{'=' * 63}{NC}")
    print(f"{BOLD}{GREEN}System updated successfully.{NC}")
    print(f"{BOLD}{GREEN}{'=' * 63}{NC}")
    prompt_for_donation()


def run_step(
    step_num: str, description: str, command: Optional[Callable[[], None] | str]
) -> None:
    print_step(step_num, description)
    try:
        if command is None:
            return
        if callable(command):
            command()
        else:
            run_shell(command)
        print_success(description)
        print("")
    except Exception as exc:  # noqa: BLE001
        error_exit(f"Failed: {description} ({exc})")


def run_interactive_step(
    icon: str,
    description: str,
    command: Optional[Callable[[], None] | str],
    default_choice: str = "none",
) -> None:
    exit_code = continue_prompt(f"{icon} {description}", command, default_choice)
    if exit_code != 0:
        error_exit(f"Failed: {description} (exit code: {exit_code})")


def run_section_step(
    icon: str, description: str, command: Optional[Callable[[], None] | str]
) -> None:
    print_step(icon, description)
    try:
        if command is None:
            return
        if callable(command):
            command()
        else:
            run_shell(command)
        print_success(description)
    except Exception as exc:  # noqa: BLE001
        error_exit(f"Failed: {description} ({exc})")


def prompt_for_donation() -> None:
    monitor_name = ""
    try:
        monitors = read_json_output(["hyprctl", "monitors", "-j"])
        for monitor in monitors:
            if monitor.get("focused"):
                monitor_name = str(monitor.get("name", ""))
                break
    except Exception:
        monitor_name = ""

    print("")
    print("Support the project if it helped your setup.")
    print("Thank you for being part of the ArchEclipse community.")
    print("")

    continue_prompt(
        "Would you like to support the project?",
        f"ags request donations {monitor_name}",
    )
