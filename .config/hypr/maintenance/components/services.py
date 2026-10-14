"""User-level systemd service management."""

from __future__ import annotations

import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parent.parent))
    from components.utils import run_cmd
else:
    from .utils import run_cmd


USER_TIMERS = ("battery-check.timer", "updates-check.timer")


def enable_user_timers() -> None:
    """Reload and enable the ArchEclipse user timers."""
    print("Enabling ArchEclipse user timers...")
    run_cmd(["systemctl", "--user", "daemon-reload"])
    run_cmd(["systemctl", "--user", "enable", "--now", *USER_TIMERS])
