#!/usr/bin/env python3
"""
TWEAKS.py - Apply system performance tweaks
"""

import subprocess
from components.figlet import print_figlet_lolcat


def main():
    """Main function"""
    print_figlet_lolcat("TWEAKS")

    # Boosting boot time
    print("\tBoosting boot time...")

    # Disable NetworkManager-wait-online.service
    print("\t\tMasking NetworkManager-wait-online.service...")
    subprocess.run(
        ["sudo", "systemctl", "mask", "NetworkManager-wait-online.service"],
        capture_output=True,
    )


if __name__ == "__main__":
    main()
