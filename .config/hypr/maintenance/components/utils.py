#!/usr/bin/env python3
"""Shared helpers for maintenance scripts."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Iterable, Optional, Sequence


def command_exists(command: str) -> bool:
    return shutil.which(command) is not None


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def run_cmd(
    args: Sequence[str],
    *,
    check: bool = True,
    capture_output: bool = False,
    cwd: Optional[Path] = None,
    env: Optional[dict[str, str]] = None,
    input_text: Optional[str] = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(args),
        check=check,
        capture_output=capture_output,
        cwd=str(cwd) if cwd else None,
        env=env,
        text=True,
        input=input_text,
    )


def run_shell(
    command: str,
    *,
    check: bool = True,
    cwd: Optional[Path] = None,
    env: Optional[dict[str, str]] = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        check=check,
        cwd=str(cwd) if cwd else None,
        env=env,
        text=True,
        shell=True,
    )


def fzf_select(options: Iterable[str], height: str = "40%") -> Optional[str]:
    options_text = "\n".join(options)
    result = run_cmd(
        ["fzf", "--height", height],
        check=False,
        capture_output=True,
        input_text=options_text,
    )
    if result.returncode != 0:
        return None
    selection = (result.stdout or "").strip()
    return selection or None


def read_json_output(command: Sequence[str]) -> list[dict]:
    result = run_cmd(command, capture_output=True)
    data = (result.stdout or "").strip()
    if not data:
        return []
    return json.loads(data)


def is_root() -> bool:
    return os.geteuid() == 0


def require_sudo() -> None:
    run_cmd(["sudo", "-v"])


def print_stderr(message: str) -> None:
    print(message, file=sys.stderr)
