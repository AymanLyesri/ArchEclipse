#!/usr/bin/env python3
"""SDDM configuration."""

from __future__ import annotations

import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parent.parent))
    from components.utils import run_cmd, run_shell
else:
    from .utils import run_cmd, run_shell

THEME_CONTENT = """[General]
passwordCharacter=*
passwordMask=true
passwordInputWidth=0.5
passwordInputBackground=
passwordInputRadius=
passwordInputCursorVisible=true
passwordFontSize=69
passwordCursorColor=random
passwordTextColor=
passwordAllowEmpty=false

cursorBlinkAnimation=true

showSessionsByDefault=true
sessionsFontSize=14

showUsersByDefault=true
usersFontSize=14
showUserRealNameByDefault=true

background=
backgroundFill=#000000
backgroundFillMode=aspect

basicTextColor=#808080

blurRadius=0

hideCursor=false
"""


def configure_sddm() -> None:
    run_shell("figlet 'SDDM' -f slant | lolcat", check=False)

    print("Disabling lightdm and GDM (ignore errors if not installed)...")
    run_cmd(["sudo", "systemctl", "disable", "lightdm.service"], check=False)
    run_cmd(["sudo", "systemctl", "disable", "gdm.service"], check=False)
    print("Done.")

    print("Enabling sddm...")
    run_cmd(["sudo", "systemctl", "enable", "sddm"])
    print("Done.")

    print("Setting up where-is-my-sddm theme...")
    run_cmd(["sudo", "mkdir", "-p", "/usr/share/sddm/themes/where_is_my_sddm_theme"])
    run_cmd(
        ["sudo", "tee", "/usr/share/sddm/themes/where_is_my_sddm_theme/theme.conf"],
        input_text=THEME_CONTENT,
    )
    print("Done.")

    print("Setting sddm theme...")
    run_cmd(["sudo", "mkdir", "-p", "/etc/sddm.conf.d"])
    run_cmd(
        ["sudo", "tee", "/etc/sddm.conf.d/theme.conf"],
        input_text="[Theme]\nCurrent=where_is_my_sddm_theme\n",
    )
    print("Done.")

    print("Sddm configuration complete.")


def main() -> None:
    configure_sddm()


if __name__ == "__main__":
    main()
