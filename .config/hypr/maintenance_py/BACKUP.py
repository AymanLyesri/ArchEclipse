#!/usr/bin/env python3
"""
BACKUP.py - Backup and restore dotfiles
"""

import os
import subprocess
import sys
from datetime import datetime
from components.figlet import print_figlet_lolcat


def run_command(cmd, check=False):
    """Run a command"""
    result = subprocess.run(cmd, shell=True, capture_output=False)
    if check and result.returncode != 0:
        print(f"Command failed: {cmd}")
        sys.exit(1)
    return result.returncode == 0


def backup_dotfiles():
    """Backup dotfiles"""
    date = datetime.now().strftime("%Y%m%d")
    home = os.path.expanduser("~")
    backup_dir = os.path.join(home, f"dotfiles_backup_{date}")

    os.makedirs(backup_dir, exist_ok=True)

    config_dir = os.path.join(home, ".config")
    backup_config_dir = os.path.join(backup_dir, ".config")

    subprocess.run(["cp", "-r", config_dir, backup_config_dir])

    print(f"Dotfiles have been copied to {backup_dir}.")


def restore_dotfiles():
    """Restore dotfiles from latest backup"""
    home = os.path.expanduser("~")
    os.chdir(home)

    # Find latest backup directory
    import glob

    backups = sorted(glob.glob("dotfiles_backup_*"), reverse=True)

    if not backups:
        print("No backup directory found.")
        sys.exit(1)

    backup_dir = backups[0]
    backup_path = os.path.join(home, backup_dir)

    # Restore using rsync
    subprocess.run(
        [
            "rsync",
            "-av",
            "--ignore-existing",
            f"{backup_path}/",
            os.path.expanduser("~/"),
        ],
        check=False,
    )

    # Clean up if empty
    if not os.listdir(backup_path):
        os.rmdir(backup_path)
    else:
        print(f"{backup_dir} is not empty, not removing.")

    print("Dotfiles have been restored.")


def main():
    """Main function"""
    print_figlet_lolcat("BACKUP")

    if len(sys.argv) > 1 and sys.argv[1] == "--restore":
        restore_dotfiles()
    else:
        backup_dotfiles()


if __name__ == "__main__":
    main()
