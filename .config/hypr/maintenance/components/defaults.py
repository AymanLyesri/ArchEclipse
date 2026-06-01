#!/usr/bin/env python3
"""Apply default configurations."""

from __future__ import annotations

from pathlib import Path
import sys

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parent.parent))
    from components.configure_keyboard import configure_keyboard
else:
    from .configure_keyboard import configure_keyboard


def apply_defaults() -> None:
    configure_keyboard()


def main() -> None:
    apply_defaults()


if __name__ == "__main__":
    main()
