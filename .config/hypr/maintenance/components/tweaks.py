#!/usr/bin/env python3
"""System tweaks."""

from __future__ import annotations

from .utils import run_cmd, run_shell


def apply_tweaks() -> None:
    run_shell("figlet 'TWEAKS' -f slant | lolcat", check=False)
    print("Boosting boot time...")
    print("Masking NetworkManager-wait-online.service...")
    run_cmd(["sudo", "systemctl", "mask", "NetworkManager-wait-online.service"])


def main() -> None:
    apply_tweaks()


if __name__ == "__main__":
    main()
