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
    if not home_dir.exists():
        error_exit(f"HOME directory not found: {home_dir}")
    if not conf_dir.exists():
        error_exit(f"Source directory not found: {conf_dir}")

    print(f"Preparing copy operation from {conf_dir} to {home_dir}...")
    print(f"Step 1/2: Removing existing {home_dir}/.config...")

    target = home_dir / ".config"
    if target.exists() or target.is_symlink():
        run_cmd(["sudo", "rm", "-rf", str(target)])

    print("Step 2/2: Copying ArchEclipse content into HOME...")
    run_cmd(
        ["sudo", "cp", "-a", "--remove-destination", f"{conf_dir}/.", str(home_dir)]
    )

    print("Copy completed successfully.")


def load_components(maintenance_dir: Path) -> dict[str, Any]:
    sys.path.insert(0, str(maintenance_dir))
    components = {
        "essentials": importlib.import_module("components.essentials"),
        "presentation": importlib.import_module("components.presentation"),
        "backup": importlib.import_module("components.backup"),
        "configure_keyboard": importlib.import_module("components.configure_keyboard"),
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
        presentation.run_section_step("*", "Installing yay", essentials.install_yay)
    elif aur_helper == "paru":
        presentation.run_section_step("*", "Installing paru", essentials.install_paru)
    else:
        presentation.error_exit("Invalid AUR helper selected")

    print("")

    presentation.print_section_header("CONFIGURATION FILES")
    presentation.run_interactive_step(
        "*",
        "Backing up dotfiles from .config",
        modules["backup"].backup_dotfiles,
    )
    presentation.run_interactive_step(
        "*",
        "Copying configuration files to HOME",
        lambda: sync_configuration_files(conf_dir),
    )

    presentation.print_section_header("KEYBOARD CONFIGURATION (optional)")
    presentation.run_interactive_step(
        "*",
        "Setting up keyboard configuration (optional)",
        modules["configure_keyboard"].configure_keyboard,
    )

    presentation.print_section_header("PACKAGE MANAGEMENT")
    presentation.run_interactive_step(
        "*", "Removing unwanted packages", essentials.remove_packages
    )
    presentation.run_interactive_step(
        "*",
        f"Installing necessary packages (using {aur_helper})",
        f"{conf_dir}/.config/hypr/pacman/install-pkgs.sh {aur_helper}",
    )

    presentation.print_section_header("SYSTEM THEME & APPEARANCE")
    presentation.run_interactive_step(
        "*", "Setting up SDDM theme", modules["sddm"].configure_sddm
    )
    presentation.run_section_step(
        "*", "Applying default configurations", modules["defaults"].apply_defaults
    )
    presentation.run_section_step(
        "*", "Setting up wallpapers", modules["wallpapers"].main
    )

    presentation.print_section_header("PLUGINS & TWEAKS")
    presentation.run_section_step(
        "*", "Installing plugins", modules["plugins"].install_plugins
    )
    presentation.run_section_step(
        "*", "Applying system tweaks", modules["tweaks"].apply_tweaks
    )

    presentation.print_section_header("INSTALLATION COMPLETE")
    presentation.print_install_completion_message()


if __name__ == "__main__":
    main()
