#!/usr/bin/env python3
"""ArchEclipse installation entrypoint."""

from __future__ import annotations

import argparse
import importlib
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

COUNTER_URL = "https://personal-counter-two.vercel.app/api/increment?workspace=archeclipse&counter=install"

def run_cmd(
    args: list[str],
    *,
    check: bool = True,
    capture_output: bool = False,
    cwd: Path | None = None,
    input_text: str | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        check=check,
        capture_output=capture_output,
        cwd=str(cwd) if cwd else None,
        text=True,
        input=input_text,
    )

def error_exit(message: str) -> None:
    print(f"ERROR {message}")
    raise SystemExit(1)

def sync_configuration_files(conf_dir: Path) -> None:
    home_dir = Path.home()

    run_cmd(["git", "config", "core.worktree", str(home_dir)], cwd=conf_dir)
    run_cmd(["git", "config", "status.showUntrackedFiles", "no"], cwd=conf_dir)

    # Checkout using the repo dir explicitly, not relative '.'
    run_cmd(
        ["git", "--git-dir", str(conf_dir / ".git"),
         "--work-tree", str(home_dir),
         "checkout", "--force", "HEAD"],
        cwd=home_dir,
    )

    print("Configuration files deployed successfully.")


def load_components(maintenance_dir: Path) -> dict[str, Any]:
    sys.path.insert(0, str(maintenance_dir))
    components = {
        "essentials": importlib.import_module("components.essentials"),
        "presentation": importlib.import_module("components.presentation"),
        "backup": importlib.import_module("components.backup"),
        "keyboard": importlib.import_module("components.keyboard"),
        "packages": importlib.import_module("components.packages"),
        "defaults": importlib.import_module("components.defaults"),
        "sddm": importlib.import_module("components.sddm"),
        "wallpapers": importlib.import_module("components.wallpapers"),
        "plugins": importlib.import_module("components.plugins"),
        "tweaks": importlib.import_module("components.tweaks"),
    }
    return components


def parse_branch(argv: list[str]) -> str:
    """
    Branch precedence:
    - `--branch/-b <name>`
    - legacy positional `<branch>` (argv[1])
    - env `ARCHECLIPSE_BRANCH`
    - default: `master`
    """
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument(
        "-b",
        "--branch",
        default=None,
        help="ArchEclipse git branch to clone (default: master)",
    )
    parser.add_argument(
        "legacy_branch",
        nargs="?",
        default=None,
        help=argparse.SUPPRESS,
    )

    args = parser.parse_args(argv[1:])

    if args.branch:
        return str(args.branch)
    if args.legacy_branch:
        return str(args.legacy_branch)
    if os.environ.get("ARCHECLIPSE_BRANCH"):
        return str(os.environ["ARCHECLIPSE_BRANCH"])
    return "master"


def main() -> None:
    conf_dir = Path.home() / "ArchEclipse"

    try:
        run_cmd(["curl", "-s", "-o", "/dev/null", COUNTER_URL], check=False)
    except Exception:
        pass

    print("Requesting sudo password...")
    run_cmd(["sudo", "-v"])  # prompt once
    print("Sudo access granted.\n")

    if conf_dir.exists():
        print(f"Repository already exists at {conf_dir}; overwriting")
        shutil.rmtree(conf_dir)

    branch = parse_branch(sys.argv)

    print("Cloning ArchEclipse repository (latest commit only)...")
    run_cmd(
        [
            "git",
            "clone",
            "--depth",
            "1",
            "--single-branch",
            "--branch",
            branch,
            "https://github.com/AymanLyesri/ArchEclipse.git",
            str(conf_dir),
        ]
    )

    print(f"Updating repository to '{branch}' branch...")
    run_cmd(["git", "fetch", "--depth", "1", "origin", branch], cwd=conf_dir)
    run_cmd(["git", "checkout", branch], cwd=conf_dir)
    run_cmd(["git", "reset", "--hard", "FETCH_HEAD"], cwd=conf_dir)
    print("")

    maintenance_dir = conf_dir / ".config/hypr/maintenance"
    if not maintenance_dir.exists():
        error_exit(f"Maintenance directory not found: {maintenance_dir}")

    modules = load_components(maintenance_dir)
    essentials = modules["essentials"]
    presentation = modules["presentation"]

    print("Installing core tools...")
    essentials.install_core_tools()
    print("")

    presentation.print_main_header("INSTALL")
    presentation.print_section_header("REPOSITORY SETUP")
    presentation.print_success("Repository cloned and ready\n")

    plan = presentation.collect_section_choices(
        "INSTALLATION PLAN",
        [
            presentation.PlannedStep(
                "backup", "Backing up old dotfiles from .config", default_choice="n"
            ),
            presentation.PlannedStep(
                "config", "Applying ArchEclipse Configuration", default_choice="y"
            ),
            presentation.PlannedStep(
                "keyboard",
                "Setting up keyboard configuration (optional)",
                default_choice="n",
            ),
            presentation.PlannedStep(
                "remove_packages", "Removing unwanted packages", default_choice="n"
            ),
            presentation.PlannedStep(
                "install_packages",
                "Installing necessary packages (requires AUR helper)",
                default_choice="y",
            ),
            presentation.PlannedStep(
                "sddm", "Setting up SDDM theme", default_choice="n"
            ),
            presentation.PlannedStep(
                "defaults", "Applying default configurations", default_choice="y"
            ),
            presentation.PlannedStep(
                "wallpapers", "Setting up wallpapers", default_choice="y"
            ),
            presentation.PlannedStep(
                "plugins", "Installing plugins", default_choice="y"
            ),
            presentation.PlannedStep(
                "tweaks", "Applying system tweaks", default_choice="y"
            ),
        ],
    )

    presentation.print_section_header("AUR HELPER SELECTION")
    print("Select an AUR helper to install packages:")
    print("  [1] yay  - AUR helper")
    print("  [2] paru - AUR helper")
    print("")

    aur_helpers = ["yay", "paru"]
    aur_helper = essentials.fzf_select(aur_helpers, height="25")
    if not aur_helper:
        presentation.error_exit("No AUR helper selected. Exiting.")

    print("")
    presentation.print_success(f"AUR helper selected: {aur_helper}\n")

    if aur_helper == "yay":
        presentation.execute_planned_step(
            "*", "Installing yay", essentials.install_yay, run=True
        )
    elif aur_helper == "paru":
        presentation.execute_planned_step(
            "*", "Installing paru", essentials.install_paru, run=True
        )
    else:
        presentation.error_exit("Invalid AUR helper selected")

    print("")

    presentation.print_section_header("CONFIGURATION FILES")
    presentation.execute_planned_step(
        "*",
        "Backing up dotfiles from .config",
        lambda: modules["backup"].backup_dotfiles(conf_dir),  # pass conf_dir here
        run=plan["backup"],
    )
    presentation.execute_planned_step(
        "*",
        "Copying configuration files to HOME",
        lambda: sync_configuration_files(conf_dir),
        run=plan["config"],
    )

    presentation.print_section_header("KEYBOARD CONFIGURATION (optional)")
    presentation.execute_planned_step(
        "*",
        "Setting up keyboard configuration (optional)",
        modules["keyboard"].configure_keyboard,
        run=plan["keyboard"],
    )

    presentation.print_section_header("PACKAGE MANAGEMENT")
    presentation.execute_planned_step(
        "*",
        "Removing unwanted packages",
        essentials.remove_packages,
        run=plan["remove_packages"],
    )
    presentation.execute_planned_step(
        "*",
        f"Installing necessary packages (using {aur_helper})",
        lambda helper=aur_helper: modules["packages"].install_packages(helper),
        run=plan["install_packages"],
    )

    presentation.print_section_header("SYSTEM THEME & APPEARANCE")
    presentation.execute_planned_step(
        "*",
        "Setting up SDDM theme",
        modules["sddm"].configure_sddm,
        run=plan["sddm"],
    )
    presentation.execute_planned_step(
        "*",
        "Applying default configurations",
        modules["defaults"].apply_defaults,
        run=plan["defaults"],
    )
    presentation.execute_planned_step(
        "*",
        "Setting up wallpapers",
        modules["wallpapers"].main,
        run=plan["wallpapers"],
    )

    presentation.print_section_header("PLUGINS & TWEAKS")
    presentation.execute_planned_step(
        "*",
        "Installing plugins",
        modules["plugins"].install_plugins,
        run=plan["plugins"],
    )
    presentation.execute_planned_step(
        "*",
        "Applying system tweaks",
        modules["tweaks"].apply_tweaks,
        run=plan["tweaks"],
    )

    presentation.print_section_header("INSTALLATION COMPLETE")
    presentation.print_install_completion_message()

    # Reload Hyprland configuration
    print("Reloading Hyprland configuration...")
    run_cmd(["hyprctl", "reload"], check=False)


if __name__ == "__main__":
    main()
