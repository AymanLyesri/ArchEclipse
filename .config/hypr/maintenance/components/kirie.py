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
import shutil
import subprocess
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


def _latest_release() -> tuple[str, dict[str, str]] | None:
    """The latest release tag and its assets, keyed by file name."""
    try:
        request = urllib.request.Request(
            RELEASE_API, headers={"Accept": "application/vnd.github+json"}
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            release = json.load(response)
    except Exception as error:  # offline, rate limited, API change
        print(f"Could not reach the kirie release feed: {error}")
        return None

    assets = {
        asset.get("name", ""): asset.get("browser_download_url", "")
        for asset in release.get("assets", [])
    }
    tag = release.get("tag_name", "")
    if ASSET not in assets:
        print(f"Release {tag} has no {ASSET} asset")
        return None
    return tag, assets


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
    tag, assets = latest

    installed = STAMP_PATH.read_text().strip() if STAMP_PATH.is_file() else ""
    if installed == tag and INSTALL_PATH.is_file():
        print(f"kirie {tag} already installed")
        return

    ensure_dir(INSTALL_PATH.parent)
    ensure_dir(STAMP_PATH.parent)

    if not _download(assets[ASSET], INSTALL_PATH, f"kirie {tag}"):
        return

    STAMP_PATH.write_text(f"{tag}\n")
    print(f"Installed kirie {tag} to {INSTALL_PATH}")
    _ensure_on_path()
    _report_readiness()


def _ensure_on_path() -> None:
    """Make ~/.local/bin reachable, in the session and in shells.

    kirie installs here because it is not a package, and on a machine where
    nothing else has ever installed to ~/.local/bin that directory is on
    nobody's PATH — so `kirie` answers "command not found" on a machine that
    has it.
    """
    bin_dir = INSTALL_PATH.parent
    if shutil.which("kirie"):
        return

    # The systemd user session: what SDDM starts, and therefore what the panel
    # and every launcher inherit.
    env_file = Path.home() / ".config/environment.d/10-local-bin.conf"
    ensure_dir(env_file.parent)
    if not env_file.is_file() or "local/bin" not in env_file.read_text():
        env_file.write_text(f'PATH="{bin_dir}:$PATH"\n')

    # Interactive shells. ArchEclipse ships its own .zshrc with this already,
    # so only files it does not own are appended to — and only when the
    # directory is not mentioned at all, so re-running changes nothing.
    for name in (".bashrc", ".profile"):
        rc = Path.home() / name
        if not rc.is_file():
            continue
        if "local/bin" in rc.read_text():
            continue
        with rc.open("a") as handle:
            handle.write(f'\nexport PATH="{bin_dir}:$PATH"\n')

    print(f"  ! {bin_dir} was not on PATH; added it.")
    print("    Open a new shell or log out and back in for `kirie` to resolve.")


def _report_readiness() -> None:
    """Say what kirie still needs, while the user is here to act on it.

    The binary installing successfully is not the same as it being able to
    render: it needs a Vulkan driver, and Wallpaper Engine's own assets for
    scene wallpapers. Both are silent failures later — an empty wallpaper
    picker, or a wallpaper that never appears.
    """
    try:
        gpus = subprocess.run(
            [str(INSTALL_PATH), "gpus"], capture_output=True, text=True, timeout=60
        )
        if "no Vulkan adapter" in (gpus.stdout + gpus.stderr):
            print("  ! No Vulkan driver found; kirie cannot render here.")
            print("    Install the one for your GPU: vulkan-radeon, vulkan-intel,")
            print("    nvidia-utils — or vulkan-swrast to render on the CPU.")
    except Exception:
        pass

    try:
        assets = subprocess.run(
            [str(INSTALL_PATH), "assets"], capture_output=True, text=True, timeout=60
        )
        if assets.returncode != 0:
            print("  ! Wallpaper Engine is not installed; scene wallpapers need its")
            print("    shared assets. Install it via Steam, or set KIRIE_WE_ASSETS.")
    except Exception:
        pass


def _download(url: str, target: Path, what: str) -> bool:
    """Fetch one binary into place, atomically. True when it landed."""
    download_path = target.with_suffix(".download")
    print(f"Downloading {what}...")
    try:
        urllib.request.urlretrieve(url, download_path)
    except Exception as error:
        print(f"Failed to download {what}: {error}")
        download_path.unlink(missing_ok=True)
        return False

    # Replace in one step: a half-written binary is worse than the old one.
    download_path.chmod(0o755)
    os.replace(download_path, target)
    return True


def main() -> None:
    install_kirie()


if __name__ == "__main__":
    main()
