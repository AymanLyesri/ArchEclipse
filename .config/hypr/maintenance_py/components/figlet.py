#!/usr/bin/env python3
"""
Shared figlet/lolcat rendering helpers for maintenance_py scripts.
"""

import subprocess
from typing import Sequence


def print_figlet_lolcat(text: str, font: str = "slant") -> None:
    """Render text with figlet piped to lolcat, with plain-text fallback."""
    try:
        figlet_proc = subprocess.Popen(
            ["figlet", text, "-f", font],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        lolcat_proc = subprocess.Popen(
            ["lolcat"],
            stdin=figlet_proc.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        figlet_proc.stdout.close()  # type: ignore
        output, _ = lolcat_proc.communicate()
        print(output.decode("utf-8", errors="replace"), end="")
    except (FileNotFoundError, OSError):
        print(text)


def print_lolcat_text(text: str, args: Sequence[str] | None = None) -> None:
    """Render plain text through lolcat, with plain-text fallback."""
    if args is None:
        args = []

    try:
        lolcat_proc = subprocess.Popen(
            ["lolcat", *args],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        output, _ = lolcat_proc.communicate(text.encode("utf-8"))
        print(output.decode("utf-8", errors="replace"), end="")
    except (FileNotFoundError, OSError):
        print(text)


def print_archeclipse_banner_text() -> None:
    """Print the ArchEclipse label through lolcat."""
    print_lolcat_text(" ArchEclipse ")
    # Add a break after the banner for spacing
    print()
