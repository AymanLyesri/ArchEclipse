#!/usr/bin/env python3
"""ArchEclipse update entrypoint."""

from __future__ import annotations

import importlib
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

COUNTER_URL = "https://personal-counter-two.vercel.app/api/increment?workspace=archeclipse&counter=update"
REPO_URL = "https://github.com/AymanLyesri/ArchEclipse.git"


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


def run_shell(command: str, *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, check=check, shell=True, text=True)


def load_components(maintenance_dir: Path) -> dict[str, Any]:
    sys.path.insert(0, str(maintenance_dir))
    return {
        "essentials": importlib.import_module("components.essentials"),
        "presentation": importlib.import_module("components.presentation"),
        "packages": importlib.import_module("components.packages"),
        "plugins": importlib.import_module("components.plugins"),
    }


def is_repo_intact(repo_dir: Path, repo_url: str) -> bool:
    if not (repo_dir / ".git").exists():
        return False

    if (
        run_cmd(
            ["git", "-C", str(repo_dir), "rev-parse", "--is-inside-work-tree"],
            check=False,
        ).returncode
        != 0
    ):
        return False

    origin_url = run_cmd(
        ["git", "-C", str(repo_dir), "remote", "get-url", "origin"],
        check=False,
        capture_output=True,
    ).stdout.strip()
    if origin_url != repo_url:
        return False

    if (
        run_cmd(
            ["git", "-C", str(repo_dir), "rev-parse", "--verify", "HEAD"], check=False
        ).returncode
        != 0
    ):
        return False

    if (
        run_cmd(
            ["git", "-C", str(repo_dir), "fsck", "--no-progress"], check=False
        ).returncode
        != 0
    ):
        return False

    return True


def update_repo(repo_dir: Path, branch: str) -> None:
    if is_repo_intact(repo_dir, REPO_URL):
        print("Repository history intact, syncing with remote...")
        run_cmd(
            [
                "git",
                "-C",
                str(repo_dir),
                "fetch",
                "origin",
                f"{branch}:refs/remotes/origin/{branch}",
            ]
        )
        run_cmd(
            [
                "git",
                "-C",
                str(repo_dir),
                "checkout",
                "-B",
                branch,
                f"origin/{branch}",
            ]
        )
        run_cmd(["git", "-C", str(repo_dir), "reset", "--hard", f"origin/{branch}"])
        print(f"Repository successfully updated from origin/{branch}.")
        return

    print(
        "Local git history is missing/corrupt. Falling back to fresh clone deployment."
    )
    temp_dir = Path(tempfile.mkdtemp())

    try:
        print("Cloning latest repository state...")
        run_cmd(
            [
                "git",
                "clone",
                "--depth",
                "1",
                "--single-branch",
                "--branch",
                branch,
                REPO_URL,
                str(temp_dir),
            ]
        )

        print("Overwriting home configuration...")
        run_cmd(["rm", "-rf", str(repo_dir / ".git")], check=False)
        run_cmd(["cp", "-a", "--remove-destination", f"{temp_dir}/.", str(Path.home())])
        print("Configuration successfully updated from fresh clone.")
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)


def cleanup_package_manager(presentation: Any) -> None:
    presentation.print_section_header("PACKAGE MANAGER CLEANUP")

    procs = ["pacman", "yay", "paru"]
    cleaned = 0

    for proc in procs:
        if run_cmd(["pgrep", "-x", proc], check=False).returncode == 0:
            print(f"Killing {proc}...")
            run_cmd(["sudo", "killall", "-9", proc], check=False)
            cleaned += 1

    if cleaned == 0:
        presentation.print_warning("No running package manager processes found")
    else:
        presentation.print_success(f"Killed {cleaned} process(es)")

    pacman_lock = Path("/var/lib/pacman/db.lck")
    if pacman_lock.exists():
        run_cmd(["sudo", "rm", "-f", str(pacman_lock)])
        presentation.print_success("Pacman lock file removed")


def detect_aur_helper() -> str:
    for helper in ("yay", "paru"):
        if shutil.which(helper):
            return helper
    return ""


def main() -> None:
    maintenance_dir = Path.home() / ".config/hypr/maintenance"
    if not maintenance_dir.exists():
        print(f"Required local maintenance scripts not found in {maintenance_dir}.")
        raise SystemExit(1)

    modules = load_components(maintenance_dir)
    presentation = modules["presentation"]
    essentials = modules["essentials"]

    aur_helper = detect_aur_helper()
    package_description = (
        f"Updating necessary packages (using {aur_helper})"
        if aur_helper
        else "Updating necessary packages"
    )

    plan = presentation.collect_section_choices(
        "UPDATE PLAN",
        [
            presentation.PlannedStep(
                "proceed", "Begin update process", default_choice="y"
            ),
            presentation.PlannedStep(
                "core_tools", "Installing core tools", default_choice="y"
            ),
            presentation.PlannedStep(
                "reload_bar", "Reloading bar configuration", default_choice="y"
            ),
            presentation.PlannedStep(
                "packages", package_description, default_choice="y"
            ),
            presentation.PlannedStep(
                "plugins", "Updating plugins", default_choice="y"
            ),
        ],
    )

    if not plan["proceed"]:
        print("Action cancelled.")
        raise SystemExit(0)

    run_cmd(["sudo", "-v"])
    run_cmd(["curl", "-s", "-o", "/dev/null", COUNTER_URL], check=False)

    branch = sys.argv[1] if len(sys.argv) > 1 else "master"
    repo_dir = Path.home()

    print("")
    print("============================================================")
    print("UPDATE")
    print("============================================================")

    print("Deploying config files")
    update_repo(repo_dir, branch)

    presentation.print_main_header("UPDATE")
    presentation.execute_planned_step(
        "*",
        "Installing core tools",
        essentials.install_core_tools,
        run=plan["core_tools"],
    )

    presentation.print_section_header("RELOADING BAR")
    presentation.execute_planned_step(
        "*",
        "Reloading bar configuration",
        "~/.config/hypr/scripts/bar.sh &",
        run=plan["reload_bar"],
    )

    if plan["packages"]:
        cleanup_package_manager(presentation)

    presentation.print_section_header("PACKAGE UPDATES")
    if plan["packages"] and aur_helper:
        presentation.execute_planned_step(
            "*",
            package_description,
            lambda: modules["packages"].install_packages(aur_helper),
            run=True,
        )
    elif plan["packages"]:
        presentation.print_step("*", package_description)
        presentation.print_warning("No AUR helper installed — skipping packages.")
        print("")
    else:
        presentation.execute_planned_step(
            "*",
            package_description,
            lambda: modules["packages"].install_packages(aur_helper),
            run=False,
        )

    presentation.print_section_header("PLUGINS")
    presentation.execute_planned_step(
        "*",
        "Updating plugins",
        modules["plugins"].install_plugins,
        run=plan["plugins"],
    )

    presentation.print_section_header("UPDATE COMPLETE")
    presentation.print_update_completion_message()


if __name__ == "__main__":
    main()
