#!/usr/bin/env python3
"""Apply default configurations."""

from __future__ import annotations

from .configure_keyboard import configure_keyboard


def apply_defaults() -> None:
    configure_keyboard()


def main() -> None:
    apply_defaults()


if __name__ == "__main__":
    main()
