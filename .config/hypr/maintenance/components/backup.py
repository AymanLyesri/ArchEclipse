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


def backup_dotfiles(conf_dir: Path) -> None:
    run_shell("figlet 'BACKUP' -f slant | lolcat", check=False)

    repo_config = conf_dir / ".config"
    if not repo_config.exists():
        print(f"Warning: no .config found in cloned repo ({repo_config}); nothing to back up.")
        return

    date_stamp = datetime.datetime.now().strftime("%Y%m%d")
    backup_dir = Path.home() / f"dotfiles_backup_{date_stamp}"
    backup_dir.mkdir(parents=True, exist_ok=True)

    source_config = Path.home() / ".config"
    dest_config = backup_dir / ".config"
    dest_config.mkdir(parents=True, exist_ok=True)

    entries = sorted(repo_config.iterdir(), key=lambda p: p.name)
    if not entries:
        print(f"Warning: repo .config ({repo_config}) is empty; nothing to back up.")
        return

    for repo_entry in entries:
        src = source_config / repo_entry.name
        dst = dest_config / repo_entry.name

        if not src.exists() and not src.is_symlink():
            print(f"Skipping {src} (not present in ~/.config).")
            continue

        if dst.exists() or dst.is_symlink():
            shutil.rmtree(dst) if dst.is_dir() else dst.unlink()

        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

        print(f"Backed up {src} -> {dst}")

    print(f"Dotfiles have been backed up to {backup_dir}.")


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
    parser.add_argument(
        "--conf-dir",
        type=Path,
        default=Path.home() / "ArchEclipse",
        help="Path to the cloned ArchEclipse repo (default: ~/ArchEclipse)",
    )
    args = parser.parse_args()

    if args.restore:
        restore_dotfiles()
    else:
        backup_dotfiles(args.conf_dir)


if __name__ == "__main__":
    main()