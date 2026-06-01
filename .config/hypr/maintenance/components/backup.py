#!/usr/bin/env python3
"""Backup and restore dotfiles."""

from __future__ import annotations

import datetime
import shutil
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parent.parent))
    from components.utils import run_cmd, run_shell
else:
    from .utils import run_cmd, run_shell


def backup_dotfiles() -> None:
    run_shell("figlet 'BACKUP' -f slant | lolcat", check=False)

    date_stamp = datetime.datetime.now().strftime("%Y%m%d")
    backup_dir = Path.home() / f"dotfiles_backup_{date_stamp}"
    backup_dir.mkdir(parents=True, exist_ok=True)

    source = Path.home() / ".config"
    dest = backup_dir / ".config"
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(source, dest)

    print(f"Dotfiles have been copied to {backup_dir}.")


def restore_dotfiles() -> None:
    backup_dirs = sorted(Path.home().glob("dotfiles_backup_*"))
    if not backup_dirs:
        print("No backup directory found.")
        raise SystemExit(1)

    backup_dir = backup_dirs[-1]

    run_cmd(
        [
            "rsync",
            "-av",
            "--ignore-existing",
            f"{backup_dir}/",
            str(Path.home()) + "/",
        ]
    )

    if not any(backup_dir.iterdir()):
        backup_dir.rmdir()
    else:
        print(f"{backup_dir} is not empty, not removing.")

    print("Dotfiles have been restored.")


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="Backup or restore dotfiles.")
    parser.add_argument(
        "--restore", action="store_true", help="Restore the latest backup"
    )
    args = parser.parse_args()

    if args.restore:
        restore_dotfiles()
    else:
        backup_dotfiles()


if __name__ == "__main__":
    main()
