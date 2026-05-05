#!/usr/bin/env python3
"""
PRESENTATION.py - Display utility functions for ArchEclipse scripts
Provides colored output, headers, and formatted messages
"""

import sys
import subprocess
from typing import Optional
import inspect
import importlib
from components.figlet import print_figlet_lolcat, print_lolcat_text

# Color codes
BOLD = "\033[1m"
CYAN = "\033[0;36m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
MAGENTA = "\033[0;35m"
RED = "\033[0;31m"
BLUE = "\033[0;34m"
NC = "\033[0m"  # No Color


def error_exit(message: str, exit_code: int = 1) -> None:
    """Print error message and exit"""
    print(f"{RED}✗ {message}{NC}")
    sys.exit(exit_code)


def print_section_header(title: str) -> None:
    """Print a formatted section header"""
    print("")
    print(
        f"{BOLD}{CYAN}╔══════════════════════════════════════════════════════════════╗{NC}"
    )
    print(f"{BOLD}{CYAN}║{NC}  {BOLD}{MAGENTA}{title}{NC}  {BOLD}{CYAN}║{NC}")
    print(
        f"{BOLD}{CYAN}╚══════════════════════════════════════════════════════════════╝{NC}"
    )
    print("")


def print_step(step: str, description: str) -> None:
    """Print a step with description"""
    print(f"{YELLOW}{step}{NC} {description}")


def print_success(message: str) -> None:
    """Print success message"""
    print(f"{GREEN}✓{NC} {message}")


def print_warning(message: str) -> None:
    """Print warning message"""
    print(f"{YELLOW}⚠{NC} {message}")


def print_main_header(mode: str = "INSTALL & UPDATE") -> None:
    """Print the main header with figlet and lolcat"""
    subtitle = ""

    if mode == "INSTALL":
        subtitle = "🚀 ArchEclipse Installation & Configuration"
    elif mode == "UPDATE":
        subtitle = "🔄 ArchEclipse Update & Synchronization"
    else:
        subtitle = "🚀 ArchEclipse Installation & Configuration"

    print_figlet_lolcat(mode)

    print(
        f"{BOLD}{CYAN}═══════════════════════════════════════════════════════════════{NC}"
    )
    print(f"{BOLD}{MAGENTA}  {subtitle}{NC}")
    print(
        f"{BOLD}{CYAN}═══════════════════════════════════════════════════════════════{NC}"
    )
    print("")


def print_install_completion_message() -> None:
    """Print installation completion message"""
    print(
        f"{BOLD}{GREEN}╔═══════════════════════════════════════════════════════════════╗{NC}"
    )
    print(
        f"{BOLD}{GREEN}║{NC}                                                               {BOLD}{GREEN}║{NC}"
    )
    print(
        f"{BOLD}{GREEN}║{NC}           🎉 Installation completed successfully! 🎉          {BOLD}{GREEN}║{NC}"
    )
    print(
        f"{BOLD}{GREEN}║{NC}                                                               {BOLD}{GREEN}║{NC}"
    )
    print(
        f"{BOLD}{GREEN}╚═══════════════════════════════════════════════════════════════╝{NC}"
    )
    print("")
    print(f"{YELLOW}⚠️  {BOLD}Please reboot your system to apply all changes:{NC}")
    print("")
    print(f"{CYAN}   {BOLD}sudo reboot{NC}")
    print("")
    print(
        f"{BOLD}{MAGENTA}═══════════════════════════════════════════════════════════════{NC}"
    )
    print("")


def print_update_completion_message() -> None:
    """Print update completion message"""
    print(
        f"{BOLD}{GREEN}╔═══════════════════════════════════════════════════════════════╗{NC}"
    )
    print(
        f"{BOLD}{GREEN}║{NC}                                                               {BOLD}{GREEN}║{NC}"
    )
    print(
        f"{BOLD}{GREEN}║{NC}            ✨ System updated successfully! ✨                 {BOLD}{GREEN}║{NC}"
    )
    print(
        f"{BOLD}{GREEN}║{NC}                                                               {BOLD}{GREEN}║{NC}"
    )
    print(
        f"{BOLD}{GREEN}╚═══════════════════════════════════════════════════════════════╝{NC}"
    )
    prompt_for_donation()


def prompt_for_donation() -> None:
    """Prompt user to support the project"""
    donation_text = """
,d88b.d88b,  |  💝 Support the project
88888888888  |  ArchEclipse is lovingly maintained by a single person
'Y8888888Y'  |  If it improved your setup or saved you time, consider supporting it
  'Y888Y'    |  Thank you for being part of the ArchEclipse community ❤️
    'Y'      |  --Ayman, the maintainer of ArchEclipse
"""

    print_lolcat_text(donation_text, args=["-p"])


def run_step(step: str, description: str, command: str) -> None:
    """Run a step with description"""
    print_step(step, description)
    rc = execute_command(command)

    if rc == 0:
        print_success(description)
        print("")
    else:
        error_exit(f"Failed: {description}")


def run_section_step(icon: str, description: str, command: str) -> None:
    """Run a section step"""
    print_step(icon, description)
    rc = execute_command(command)

    if rc == 0:
        print_success(description)
    else:
        error_exit(f"Failed: {description}")


def execute_command(command):
    """Execute either a Python callable/function name or a shell command.

    - If `command` is a callable, call it and return 0 on success.
    - If `command` is a simple identifier matching a function in the
      caller's globals or in known modules (ESSENTIALS, PRESENTATION), call it.
    - Otherwise run the command through the shell.
    Returns integer exit code.
    """
    # Callables
    if callable(command):
        try:
            result = command()
            return 0 if result is None else int(result)  # type: ignore
        except SystemExit as se:
            return se.code if isinstance(se.code, int) else 1
        except Exception:
            return 1

    # Non-string guard
    if not isinstance(command, str):
        return 1

    # Heuristic: simple function name (no spaces, no slashes)
    import re

    if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", command):
        # try caller globals (two frames up)
        try:
            stack = inspect.stack()
            caller_globals = stack[2].frame.f_globals if len(stack) > 2 else {}
            if command in caller_globals and callable(caller_globals[command]):
                try:
                    result = caller_globals[command]()
                    return 0 if result is None else int(result)
                except SystemExit as se:
                    return se.code if isinstance(se.code, int) else 1
                except Exception:
                    return 1
        except Exception:
            pass

        # try known modules
        for mod_name in ("ESSENTIALS", "PRESENTATION"):
            try:
                mod = importlib.import_module(mod_name)
                if hasattr(mod, command) and callable(getattr(mod, command)):
                    try:
                        result = getattr(mod, command)()
                        return 0 if result is None else int(result)
                    except SystemExit as se:
                        return se.code if isinstance(se.code, int) else 1
                    except Exception:
                        return 1
            except Exception:
                continue

    # Fallback: run as shell command
    try:
        proc = subprocess.run(command, shell=True)
        return proc.returncode
    except Exception:
        return 1


def run_interactive_step(
    icon: str, description: str, command: str, default_choice: str = "none"
) -> None:
    """Run an interactive step with user confirmation"""
    from ESSENTIALS import continue_prompt

    combined_prompt = f"{icon} {description}"
    exit_code = continue_prompt(combined_prompt, command, default_choice)

    if exit_code != 0:
        error_exit(f"Failed: {description} (exit code: {exit_code})")


if __name__ == "__main__":
    # This module is meant to be imported, not run directly
    print("This is a utility module. Import it in other scripts.")
