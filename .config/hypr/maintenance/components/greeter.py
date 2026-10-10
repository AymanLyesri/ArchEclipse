#!/usr/bin/env python3
"""greetd + quickshell-greeter configuration (replaces SDDM)."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parent.parent))
    from components.utils import run_cmd, run_shell
else:
    from .utils import run_cmd, run_shell

GREETD_CONFIG = """[terminal]
vt = 1

[default_session]
command = "/usr/bin/start-hyprland -- -c /etc/xdg/quickshell/archeclipse-greeter/hyprland.lua"
user = "greeter"
# fallback (previous login): command = "/usr/bin/noctalia-greeter-session"
"""

# Any admin user may re-sync (bar.sh runs it as the daily user, not the
# installer): scope to %wheel, never a baked-in name. A name here would
# ship a dead rule to every other machine — and strand multi-user boxes
# where installer != daily user.
SUDOERS_CONTENT = (
    "%wheel ALL=(root) NOPASSWD: "
    "/usr/bin/mkdir -p /etc/xdg/quickshell/archeclipse-greeter, "
    "/usr/bin/rsync *, "
    "/usr/bin/chmod -R a+rX /etc/xdg/quickshell/archeclipse-greeter, "
    # Generated files (sessions.json, keyboard-input.lua today): pinning
    # each name broke the sync the day a new one was added (2026-10-10:
    # input.conf never landed, hard-error popup every boot). Top-level
    # wildcard inside this single greeter-config dir only.
    "/usr/bin/tee /etc/xdg/quickshell/archeclipse-greeter/*"
)

GREETD_CONFIG_PATH = "/etc/greetd/config.toml"
GREETD_BACKUP_PATH = "/etc/greetd/config.toml.bak-noctalia"
SUDOERS_PATH = "/etc/sudoers.d/quickshell-greeter-sync"
SYNC_SCRIPT = str(
    Path.home() / ".config/quickshell/archeclipse/scripts/sync-greeter.sh"
)


def configure_greeter() -> None:
    run_shell("figlet 'GREETER' -f slant | lolcat", check=False)

    # This distro is systemd-only in practice, but never strand a machine:
    # without systemctl the DM steps are skipped and the login is untouched.
    has_systemd = shutil.which("systemctl") is not None

    print("Disabling other display managers (ignore errors if not installed)...")
    if has_systemd:
        run_cmd(["sudo", "systemctl", "disable", "sddm.service"], check=False)
        run_cmd(["sudo", "systemctl", "disable", "lightdm.service"], check=False)
        run_cmd(["sudo", "systemctl", "disable", "gdm.service"], check=False)
        print("Done.")
    else:
        print("No systemctl found — leaving display managers unchanged.")

    print("Enabling greetd...")
    if has_systemd:
        run_cmd(["sudo", "systemctl", "enable", "greetd.service"])
        print("Done.")
    else:
        print("No systemctl found — skipping (login manager unchanged).")

    print("Adding greeter user to video,input groups...")
    run_cmd(["sudo", "usermod", "-aG", "video,input", "greeter"])
    print("Done.")

    print("Installing greeter sync sudoers rule...")
    run_cmd(["sudo", "tee", SUDOERS_PATH], input_text=SUDOERS_CONTENT + "\n")
    run_cmd(["sudo", "chmod", "440", SUDOERS_PATH])
    print("Done.")

    print("Syncing greeter theme mirror (first run)...")
    run_cmd(["bash", SYNC_SCRIPT])
    run_cmd(["sudo", "-u", "greeter", "ls", "/etc/xdg/quickshell/archeclipse-greeter"])
    print("Done.")

    print("Enabling VT2 text login (rescue if the greeter fails)...")
    if has_systemd:
        run_cmd(["sudo", "systemctl", "enable", "getty@tty2.service"], check=False)
    else:
        print("No systemctl found — skipping.")
    print("Done.")

    print("Backing up current greetd config (once, never overwritten)...")
    run_shell(
        f"test -f {GREETD_BACKUP_PATH} || sudo cp {GREETD_CONFIG_PATH} {GREETD_BACKUP_PATH}"
    )
    print("Pointing greetd at the quickshell greeter...")
    run_cmd(["sudo", "tee", GREETD_CONFIG_PATH], input_text=GREETD_CONFIG)
    print("Done.")

    print("Greeter configuration complete (takes effect after reboot).")


def remove_arch_eclipse_greeter_config() -> None:
    current = run_cmd(
        ["sudo", "cat", GREETD_CONFIG_PATH], check=False, capture_output=True
    )
    if current.returncode == 0 and current.stdout == GREETD_CONFIG:
        backup = run_cmd(
            ["sudo", "cat", GREETD_BACKUP_PATH], check=False, capture_output=True
        )
        if backup.returncode == 0:
            run_cmd(["sudo", "cp", GREETD_BACKUP_PATH, GREETD_CONFIG_PATH])
            print(f"Restored previous greetd configuration: {GREETD_CONFIG_PATH}")
        else:
            print(
                f"Keeping ArchEclipse greetd configuration (no backup at "
                f"{GREETD_BACKUP_PATH}): {GREETD_CONFIG_PATH}"
            )
    else:
        print(f"Keeping modified greetd configuration: {GREETD_CONFIG_PATH}")

    sudoers = run_cmd(
        ["sudo", "cat", SUDOERS_PATH], check=False, capture_output=True
    )
    if sudoers.returncode == 0 and sudoers.stdout == SUDOERS_CONTENT + "\n":
        run_cmd(["sudo", "rm", "-f", SUDOERS_PATH])
        print(f"Removed ArchEclipse greeter sudoers rule: {SUDOERS_PATH}")
    else:
        print(f"Keeping modified sudoers file: {SUDOERS_PATH}")

    print(
        "greetd service enablement, greeter user groups, and the "
        "/etc/xdg/quickshell/archeclipse-greeter mirror were left unchanged."
    )


def main() -> None:
    configure_greeter()


if __name__ == "__main__":
    main()
