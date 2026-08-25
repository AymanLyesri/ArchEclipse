#!/usr/bin/env python3
"""Wallpaper Engine renderer (kirie) setup.

kirie renders Wallpaper Engine wallpapers on Wayland. It is a single static
binary published on GitHub rather than a package, so it is fetched here into
~/.local/bin instead of going through the AUR helper with everything else.

The wallpaper switcher and the settings panel only show their Wallpaper Engine
parts when this binary is present, so skipping this step costs nothing beyond
those features.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.request
from pathlib import Path

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parent.parent))
    from components.utils import command_exists, ensure_dir, run_shell
else:
    from .utils import command_exists, ensure_dir, run_shell

RELEASE_API = "https://api.github.com/repos/UnhingedSoftware/kirie/releases/latest"
# The webview build renders web wallpapers too, which a plain build cannot.
ASSET = "kirie-web-webview-linux-x86_64"
INSTALL_PATH = Path.home() / ".local/bin/kirie"
STAMP_PATH = Path.home() / ".local/share/kirie/installed-version"


def _latest_release() -> tuple[str, str] | None:
    """The latest release tag and the download URL of the asset."""
    try:
        request = urllib.request.Request(
            RELEASE_API, headers={"Accept": "application/vnd.github+json"}
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            release = json.load(response)
    except Exception as error:  # offline, rate limited, API change
        print(f"Could not reach the kirie release feed: {error}")
        return None

    for asset in release.get("assets", []):
        if asset.get("name") == ASSET:
            return release.get("tag_name", ""), asset["browser_download_url"]

    print(f"Release {release.get('tag_name')} has no {ASSET} asset")
    return None


def install_kirie() -> None:
    run_shell("echo ' ArchEclipse ' | lolcat", check=False)
    run_shell("figlet 'WALLPAPER ENGINE' -f slant | lolcat", check=False)

    # A kirie that ArchEclipse did not install is someone's own build or
    # package; replacing it with a release would throw their work away.
    if not STAMP_PATH.is_file() and (INSTALL_PATH.is_file() or command_exists("kirie")):
        print("kirie is already installed by other means; leaving it alone")
        return

    latest = _latest_release()
    if latest is None:
        return
    tag, url = latest

    installed = STAMP_PATH.read_text().strip() if STAMP_PATH.is_file() else ""
    if installed == tag and INSTALL_PATH.is_file():
        print(f"kirie {tag} already installed")
        return

    ensure_dir(INSTALL_PATH.parent)
    ensure_dir(STAMP_PATH.parent)
    download_path = INSTALL_PATH.with_suffix(".download")

    print(f"Downloading kirie {tag}...")
    try:
        urllib.request.urlretrieve(url, download_path)
    except Exception as error:
        print(f"Failed to download kirie: {error}")
        download_path.unlink(missing_ok=True)
        return

    # Replace in one step: a half-written binary is worse than the old one.
    download_path.chmod(0o755)
    os.replace(download_path, INSTALL_PATH)
    STAMP_PATH.write_text(f"{tag}\n")
    print(f"Installed kirie {tag} to {INSTALL_PATH}")


def main() -> None:
    install_kirie()


if __name__ == "__main__":
    main()
