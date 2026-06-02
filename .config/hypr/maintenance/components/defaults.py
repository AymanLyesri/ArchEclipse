#!/usr/bin/env python3
"""Apply default configurations.

Copy default hyprland configuration files from .config/hypr/config/defaults
to .config/hypr/config/custom.
"""

from __future__ import annotations

import sys
from pathlib import Path
import shutil

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parent.parent))
    from components.utils import run_shell
else:
    from .utils import run_shell


def _copy_children(src_dir: Path, dst_dir: Path) -> None:
    dst_dir.mkdir(parents=True, exist_ok=True)
    for child in src_dir.iterdir():
        dst = dst_dir / child.name
        if child.is_dir():
            shutil.copytree(child, dst, dirs_exist_ok=True)
        else:
            shutil.copy2(child, dst)


def apply_defaults() -> None:
    run_shell("figlet 'DEFAULTS' -f slant | lolcat", check=False)

    src_dir = Path.home() / ".config/hypr/config/defaults"
    dst_dir = Path.home() / ".config/hypr/config/custom"

    print(
        "Copying default hyprland configuration files from "
        f"{src_dir} to {dst_dir}..."
    )
    _copy_children(src_dir, dst_dir)
    print("Done.")

    print("Default hyprland configuration files copied successfully.")

def main() -> None:
    apply_defaults()

if __name__ == "__main__":
    main()