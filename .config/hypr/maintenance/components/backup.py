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

    if not conf_dir.exists():
        print(f"Warning: cloned repo not found ({conf_dir}); nothing to back up.")
        return

    date_stamp = datetime.datetime.now().strftime("%Y%m%d")
    backup_dir = Path.home() / f"dotfiles_backup_{date_stamp}"
    backup_dir.mkdir(parents=True, exist_ok=True)

    home_dir = Path.home()
    entries = sorted(conf_dir.iterdir(), key=lambda p: p.name)

    for repo_entry in entries:
        src = home_dir / repo_entry.name
        dst = backup_dir / repo_entry.name

        if not src.exists() and not src.is_symlink():
            print(f"Skipping {src} (not present in ~/).")
            continue

        if repo_entry.is_dir():
            dst.mkdir(parents=True, exist_ok=True)
            for child in sorted(repo_entry.iterdir(), key=lambda p: p.name):
                child_src = src / child.name
                child_dst = dst / child.name

                if not child_src.exists() and not child_src.is_symlink():
                    print(f"Skipping {child_src} (not present in ~/).")
                    continue

                if child_dst.exists() or child_dst.is_symlink():
                    (
                        shutil.rmtree(child_dst)
                        if child_dst.is_dir()
                        else child_dst.unlink()
                    )

                if child_src.is_dir():
                    shutil.copytree(child_src, child_dst)
                else:
                    shutil.copy2(child_src, child_dst)

                print(f"Backed up {child_src} -> {child_dst}")
        else:
            if dst.exists() or dst.is_symlink():
                dst.unlink()
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
