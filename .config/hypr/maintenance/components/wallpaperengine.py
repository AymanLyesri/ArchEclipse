#!/usr/bin/env python3
"""Install linux-wallpaperengine (the renderer behind the Wallpaper Engine integration).

The daemon (``~/.config/hypr/wallpaper-daemon/wallpaperengine.sh``) and the AGS selector
depend on fork-only features (a live control socket, ``--render-scale`` supersampling and
native 3D ``.mdl`` model rendering), so this builds from source rather than using the
upstream AUR package. The binary is placed where the daemon looks for it:

    ~/linux-wallpaperengine/build/output/linux-wallpaperengine

Source selection is asked at install time (no silent default). Environment variables
override the prompt for non-interactive / scripted installs:

    WPE_LOCAL_REPO   path to an existing local checkout (built in place, symlinked into place)
    WPE_REPO_URL     remote git URL to clone
    WPE_REPO_REF     branch / tag / commit for WPE_REPO_URL (default: the repo's default branch)
    WPE_FORCE=1      replace an existing ~/linux-wallpaperengine (backed up to .bak) without asking
    WPE_SKIP=1       skip this step entirely

A build failure is reported as a warning and does NOT abort the rest of the installation.
"""

from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path
from typing import Optional

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parent.parent))
    from components.utils import run_cmd, run_shell, fzf_select
    from components.presentation import print_step, print_success, print_warning
else:
    from .utils import run_cmd, run_shell, fzf_select
    from .presentation import print_step, print_success, print_warning

# The ArchEclipse Wallpaper Engine fork + the branch that carries the integration features.
# Offered as a menu choice; never used unless the user explicitly picks it (or sets the env vars).
FORK_URL = "https://github.com/beingsuz/linux-wallpaperengine.git"
FORK_REF = "feat/better-wallpaper-support"

# Where the daemon expects the binary: ~/linux-wallpaperengine/build/output/linux-wallpaperengine
DEST = Path.home() / "linux-wallpaperengine"

# Arch build dependencies. CEF is downloaded automatically by CMake (CMakeModules/DownloadCEF.cmake),
# so it is not listed here. base-devel covers make/gcc/etc.
BUILD_DEPS: list[str] = [
    "base-devel",
    "cmake",
    "git",
    "pkgconf",
    "glew",
    "glfw",
    "glm",
    "freeglut",
    "sdl2",
    "lz4",
    "zlib",
    "ffmpeg",
    "mpv",
    "libpulse",
    "freetype2",
    "fftw",
    "gmp",
    "libx11",
    "libxrandr",
    "libxinerama",
    "libxcursor",
    "libxi",
    "libxxf86vm",
    "wayland",
    "wayland-protocols",
    "libglvnd",
    "mesa",
]


# --------------------------------------------------------------------------- source selection

def _env(name: str) -> Optional[str]:
    value = os.environ.get(name)
    value = value.strip() if value else ""
    return value or None


def _truthy(name: str) -> bool:
    return (os.environ.get(name) or "").strip().lower() in {"1", "true", "yes", "y", "on"}


def _choose_source() -> Optional[tuple[str, str, Optional[str]]]:
    """Return (kind, location, ref) where kind is 'remote' or 'local', or None to skip.

    Precedence: WPE_SKIP -> WPE_LOCAL_REPO -> WPE_REPO_URL -> interactive prompt.
    """
    if _truthy("WPE_SKIP"):
        print_warning("WPE_SKIP set — skipping Wallpaper Engine.")
        return None

    local = _env("WPE_LOCAL_REPO")
    if local:
        return ("local", str(Path(local).expanduser()), None)

    url = _env("WPE_REPO_URL")
    if url:
        return ("remote", url, _env("WPE_REPO_REF"))

    if not sys.stdin.isatty():
        print_warning(
            "No TTY and no WPE_* override set — skipping Wallpaper Engine. "
            "Set WPE_REPO_URL or WPE_LOCAL_REPO to install non-interactively."
        )
        return None

    options = [
        f"ArchEclipse fork  ({FORK_URL.split('://')[-1]} @ {FORK_REF})",
        "Custom remote repository (enter a git URL)",
        "Local repository (enter a path to an existing checkout)",
        "Skip Wallpaper Engine",
    ]
    print("Choose where to get linux-wallpaperengine from:")
    selection = fzf_select(options)
    if not selection or selection.startswith("Skip"):
        print_warning("No source selected — skipping Wallpaper Engine.")
        return None

    if selection.startswith("ArchEclipse fork"):
        return ("remote", FORK_URL, FORK_REF)

    if selection.startswith("Custom remote"):
        url = input("  Git URL: ").strip()
        if not url:
            print_warning("No URL entered — skipping Wallpaper Engine.")
            return None
        ref = input("  Branch / tag / commit (leave blank for the default branch): ").strip()
        return ("remote", url, ref or None)

    # Local repository
    path = input("  Path to the local checkout: ").strip()
    if not path:
        print_warning("No path entered — skipping Wallpaper Engine.")
        return None
    return ("local", str(Path(path).expanduser()), None)


# --------------------------------------------------------------------------- dependencies

def _install_build_deps(aur_helper: str) -> None:
    print_step("*", "Installing build dependencies")
    # Mirror packages.py: feed targets on stdin so the helper resolves official + AUR repos.
    run_cmd(
        [aur_helper, "-S", "--needed", "-"],
        input_text="\n".join(BUILD_DEPS),
    )


# --------------------------------------------------------------------------- source preparation

def _confirm_overwrite() -> bool:
    if _truthy("WPE_FORCE"):
        return True
    if not sys.stdin.isatty():
        return False
    answer = input(
        f"  {DEST} already exists. Replace it (a backup is kept as .bak)? [y/N]: "
    ).strip().lower()
    return answer.startswith("y")


def _backup_dest() -> None:
    backup = DEST.with_name(DEST.name + ".bak")
    if backup.is_symlink() or backup.exists():
        if backup.is_dir() and not backup.is_symlink():
            shutil.rmtree(backup)
        else:
            backup.unlink()
    shutil.move(str(DEST), str(backup))
    print_warning(f"Existing checkout moved to {backup}")


def _prepare_source(kind: str, location: str, ref: Optional[str]) -> Optional[Path]:
    """Make sure the source tree exists at DEST and return its real build directory."""
    if kind == "local":
        src = Path(location)
        if not (src / "CMakeLists.txt").is_file():
            print_warning(f"'{src}' does not look like a linux-wallpaperengine checkout — skipping.")
            return None
        if src.resolve() == DEST.resolve():
            return DEST
        # Point ~/linux-wallpaperengine at the local checkout so the daemon finds the build.
        if DEST.exists() or DEST.is_symlink():
            if not _confirm_overwrite():
                print_warning(f"Keeping existing {DEST}; building it instead of the local path.")
                return DEST
            _backup_dest()
        DEST.symlink_to(src, target_is_directory=True)
        print_success(f"Linked {DEST} -> {src}")
        return src

    # remote
    if DEST.exists() or DEST.is_symlink():
        if not _confirm_overwrite():
            print_warning(f"{DEST} already exists — rebuilding it (source override ignored).")
            return DEST
        _backup_dest()

    print_step("*", f"Cloning {location}" + (f" ({ref})" if ref else ""))
    clone = ["git", "clone", "--depth", "1", location, str(DEST)]
    if ref:
        # ref must be a branch or tag (shallow clone can't target an arbitrary commit).
        clone[4:4] = ["--branch", ref]
    run_cmd(clone)
    return DEST


# --------------------------------------------------------------------------- build

def _build(repo_dir: Path) -> None:
    build_dir = repo_dir / "build"
    build_dir.mkdir(parents=True, exist_ok=True)
    print_step("*", "Configuring (CMake — this downloads CEF on first run)")
    run_cmd(["cmake", "-DCMAKE_BUILD_TYPE=Release", ".."], cwd=build_dir)
    print_step("*", "Compiling (this can take a while)")
    jobs = str(os.cpu_count() or 1)
    run_cmd(["cmake", "--build", ".", "-j", jobs], cwd=build_dir)

    binary = build_dir / "output" / "linux-wallpaperengine"
    if not binary.is_file():
        raise RuntimeError(f"build finished but {binary} is missing")
    print_success(f"Built {binary}")


def _print_steam_notice() -> None:
    print("")
    print_warning(
        "Wallpaper Engine assets come from Steam: you must OWN and install Wallpaper Engine "
        "(via Steam, Proton/Windows build) so its Workshop items appear under "
        "~/.local/share/Steam/steamapps/workshop/content/431960. The renderer itself is now "
        "built; subscribe to wallpapers in Steam, then pick them with Super+W."
    )


# --------------------------------------------------------------------------- entrypoint

def install_wallpaper_engine(aur_helper: str = "yay") -> None:
    run_shell("figlet 'WALLPAPER ENGINE' -f slant | lolcat", check=False)

    try:
        source = _choose_source()
        if source is None:
            return
        kind, location, ref = source
        _install_build_deps(aur_helper)
        repo_dir = _prepare_source(kind, location, ref)
        if repo_dir is None:
            return
        _build(repo_dir)
        _print_steam_notice()
    except Exception as exc:  # noqa: BLE001 — never abort the whole install for this optional step
        print_warning(f"Wallpaper Engine setup failed: {exc}")
        print_warning(
            "You can finish it later: install the deps, then "
            "`cd ~/linux-wallpaperengine && cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build`."
        )


def main() -> None:
    aur_helper = sys.argv[1] if len(sys.argv) > 1 else "yay"
    install_wallpaper_engine(aur_helper)


if __name__ == "__main__":
    main()
