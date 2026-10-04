#!/usr/bin/env python3
"""Remove ArchEclipse dotfiles while preserving a full safety backup."""

from __future__ import annotations

import argparse
import importlib
import os
import pwd
import shutil
import subprocess
import sys
import tempfile
from collections.abc import Callable
from pathlib import Path, PurePosixPath


REPO_URL = "https://github.com/AymanLyesri/ArchEclipse"
ZSH_CONFIG = ".zshrc"
TEMP_BACKUP_PREFIX = "archeclipse-uninstall-"
TEMP_BACKUP_ROOT = Path("/tmp")
BACKUP_RELATIVE = PurePosixPath(".cache/archeclipse/uninstall-backups")
LEGACY_BACKUP_RELATIVE = PurePosixPath(".local/share/archeclipse/uninstall-backups")
PREVIOUS_BACKUPS = "dotfiles_backup_*"
EXTRA_MANAGED_PATHS = (PurePosixPath(".config/wallpapers"),)


def run_cmd(
    args: list[str], *, capture_output: bool = False
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        check=True,
        capture_output=capture_output,
        text=True,
    )


def normalize_repo_url(url: str) -> str:
    url = url.strip().rstrip("/")
    if url.startswith("git@github.com:"):
        url = "https://github.com/" + url.removeprefix("git@github.com:")
    if url.endswith(".git"):
        url = url[:-4]
    return url.lower()


def managed_home_git_metadata(home_dir: Path) -> PurePosixPath | None:
    git_path = home_dir / ".git"
    if not git_path.is_dir() or git_path.is_symlink():
        return None

    result = subprocess.run(
        ["git", "-C", str(home_dir), "rev-parse", "--show-toplevel"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 or Path(result.stdout.strip()).resolve() != home_dir:
        return None

    git_dir_result = subprocess.run(
        ["git", "-C", str(home_dir), "rev-parse", "--absolute-git-dir"],
        check=False,
        capture_output=True,
        text=True,
    )
    if (
        git_dir_result.returncode != 0
        or Path(git_dir_result.stdout.strip()).resolve() != git_path.resolve()
    ):
        return None

    for remote in ("origin", "upstream"):
        result = subprocess.run(
            ["git", "-C", str(home_dir), "remote", "get-url", remote],
            check=False,
            capture_output=True,
            text=True,
        )
        if (
            result.returncode == 0
            and normalize_repo_url(result.stdout) == REPO_URL.lower()
        ):
            return PurePosixPath(".git")
    return None


def managed_home_paths(repo_dir: Path, home_dir: Path) -> list[PurePosixPath]:
    expected_repo = home_dir / "ArchEclipse"
    resolved_repo = repo_dir.resolve()
    backup_bases = {
        (home_dir / BACKUP_RELATIVE).resolve(),
        (home_dir / LEGACY_BACKUP_RELATIVE).resolve(),
    }
    is_home_clone = resolved_repo == expected_repo.resolve()
    is_backup_clone = (
        resolved_repo.name == "ArchEclipse"
        and (
            resolved_repo.parent.parent in backup_bases
            or (
                resolved_repo.parent.parent == TEMP_BACKUP_ROOT
                and resolved_repo.parent.name.startswith(TEMP_BACKUP_PREFIX)
            )
        )
    )
    if not is_home_clone and not is_backup_clone:
        raise RuntimeError(
            f"Expected clone at {expected_repo} or inside one of {backup_bases}"
        )
    if not repo_dir.is_dir():
        raise RuntimeError(f"ArchEclipse clone not found: {repo_dir}")

    git_dir = Path(
        run_cmd(
            ["git", "-C", str(repo_dir), "rev-parse", "--absolute-git-dir"],
            capture_output=True,
        ).stdout.strip()
    ).resolve()
    git_args = [
        "git",
        f"--git-dir={git_dir}",
        f"--work-tree={repo_dir.resolve()}",
    ]
    root = Path(
        run_cmd(
            [*git_args, "rev-parse", "--show-toplevel"],
            capture_output=True,
        ).stdout.strip()
    ).resolve()
    if root != repo_dir.resolve():
        raise RuntimeError(f"Not a repository root: {repo_dir}")

    remotes = []
    for remote in ("origin", "upstream"):
        result = subprocess.run(
            [*git_args, "remote", "get-url", remote],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            remotes.append(normalize_repo_url(result.stdout))
    if REPO_URL.lower() not in remotes:
        raise RuntimeError(f"{repo_dir} is not an ArchEclipse repository clone")

    output = run_cmd(
        [*git_args, "ls-files", "-z"],
        capture_output=True,
    ).stdout
    root_entries: set[str] = set()
    config_entries: set[str] = set()
    for raw_path in output.split("\0"):
        if not raw_path:
            continue
        tracked_path = PurePosixPath(raw_path)
        if (
            tracked_path.is_absolute()
            or ".." in tracked_path.parts
            or not tracked_path.parts
        ):
            continue
        if tracked_path.parts[0] == ".config":
            if len(tracked_path.parts) > 1:
                config_entries.add(tracked_path.parts[1])
        elif tracked_path.parts[0] != ".git":
            root_entries.add(tracked_path.parts[0])

    paths = {
        PurePosixPath(repo_dir.name),
        *(PurePosixPath(entry) for entry in root_entries if entry != ZSH_CONFIG),
        *(
            PurePosixPath(".config", entry)
            for entry in config_entries
        ),
    }
    home_git_metadata = managed_home_git_metadata(home_dir)
    if home_git_metadata is not None:
        paths.add(home_git_metadata)
    return sorted(paths)


def find_repository_source(home_dir: Path) -> tuple[Path, list[PurePosixPath]]:
    candidates = [home_dir / "ArchEclipse"]
    recovery_clone = Path(__file__).resolve().parent / "ArchEclipse"
    if recovery_clone != candidates[0]:
        candidates.append(recovery_clone)
    for relative_base in (BACKUP_RELATIVE, LEGACY_BACKUP_RELATIVE):
        backup_base = home_dir / relative_base
        if backup_base.is_dir() and not backup_base.is_symlink():
            previous_backups = sorted(
                (
                    path
                    for path in backup_base.iterdir()
                    if path.is_dir() and not path.is_symlink()
                ),
                reverse=True,
            )
            candidates.extend(path / "ArchEclipse" for path in previous_backups)
    if TEMP_BACKUP_ROOT.is_dir():
        temp_backups = sorted(
            (
                path
                for path in TEMP_BACKUP_ROOT.iterdir()
                if path.name.startswith(TEMP_BACKUP_PREFIX)
                and path.is_dir()
                and not path.is_symlink()
            ),
            reverse=True,
        )
        candidates.extend(path / "ArchEclipse" for path in temp_backups)

    errors = []
    for candidate in candidates:
        if not candidate.is_dir():
            continue
        try:
            return candidate, managed_home_paths(candidate, home_dir)
        except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
            errors.append(f"{candidate}: {exc}")
    if errors:
        raise RuntimeError(
            "No valid ArchEclipse clone found. " + "; ".join(errors)
        )
    raise RuntimeError(
        f"Neither {home_dir / 'ArchEclipse'} nor an archived clone was found"
    )


def safe_home_target(home_dir: Path, relative_path: PurePosixPath) -> Path | None:
    if relative_path.is_absolute() or ".." in relative_path.parts:
        return None
    target = home_dir.joinpath(*relative_path.parts)
    parent = home_dir
    for part in relative_path.parts[:-1]:
        parent /= part
        if parent.is_symlink():
            return None
        if parent.exists() and not parent.is_dir():
            return None
    return target


def existing_targets(home_dir: Path, relative_paths: list[PurePosixPath]) -> list[Path]:
    targets = []
    for relative_path in relative_paths:
        target = safe_home_target(home_dir, relative_path)
        if target is None:
            print(f"Keeping path with unsafe parent: {relative_path}")
        elif os.path.lexists(target):
            targets.append(target)
    return targets


def create_safety_backup(
    home_dir: Path, relative_paths: list[PurePosixPath], uninstaller_source: Path
) -> tuple[Path, int]:
    backup_dir = Path(
        tempfile.mkdtemp(prefix=TEMP_BACKUP_PREFIX, dir=TEMP_BACKUP_ROOT)
    )

    copied = 0
    for relative_path in relative_paths:
        source = safe_home_target(home_dir, relative_path)
        if source is None or not os.path.lexists(source):
            continue
        destination = backup_dir.joinpath(*relative_path.parts)
        destination.parent.mkdir(parents=True, exist_ok=True)
        if source.is_symlink():
            destination.symlink_to(os.readlink(source))
        elif source.is_dir():
            shutil.copytree(source, destination, symlinks=True)
        elif source.is_file():
            shutil.copy2(source, destination)
        else:
            raise RuntimeError(f"Cannot safely back up filesystem entry: {source}")
        copied += 1

    if not uninstaller_source.is_file():
        raise RuntimeError(f"Cannot preserve the uninstaller: {uninstaller_source}")
    shutil.copy2(uninstaller_source, backup_dir / "uninstall.py")
    return backup_dir, copied


def remove_targets(
    home_dir: Path, relative_paths: list[PurePosixPath]
) -> tuple[int, list[str]]:
    removed = 0
    errors: list[str] = []
    removed_targets: list[Path] = []
    for relative_path in relative_paths:
        target = safe_home_target(home_dir, relative_path)
        if target is None:
            print(f"Keeping path with unsafe parent: {relative_path}")
            continue
        if not os.path.lexists(target):
            continue
        try:
            if target.is_symlink() or target.is_file():
                target.unlink()
            elif target.is_dir():
                shutil.rmtree(target)
            else:
                target.unlink()
            removed += 1
            removed_targets.append(target)
        except OSError as exc:
            errors.append(f"{target}: {exc}")
    prune_empty_parents(home_dir, removed_targets)
    return removed, errors


def prune_empty_parents(home_dir: Path, targets: list[Path]) -> None:
    parents = {
        parent
        for target in targets
        for parent in target.parents
        if parent != home_dir and parent.is_relative_to(home_dir)
    }
    for parent in sorted(parents, key=lambda path: len(path.parts), reverse=True):
        if parent.is_symlink() or not parent.is_dir():
            continue
        try:
            parent.rmdir()
        except OSError:
            pass


def latest_dotfiles_backup(home_dir: Path) -> Path | None:
    backups = sorted(
        path
        for path in home_dir.glob(PREVIOUS_BACKUPS)
        if path.is_dir() and not path.is_symlink()
    )
    return backups[-1] if backups else None


def restore_backup_tree(
    backup_dir: Path, source_dir: Path, home_dir: Path
) -> tuple[int, int]:
    restored = 0
    skipped = 0
    for entry in sorted(source_dir.iterdir(), key=lambda path: path.name):
        relative_path = PurePosixPath(entry.relative_to(backup_dir).as_posix())
        target = safe_home_target(home_dir, relative_path)
        if target is None:
            skipped += 1
            continue

        if entry.is_dir() and not entry.is_symlink():
            if os.path.lexists(target) and (target.is_symlink() or not target.is_dir()):
                skipped += 1
                continue
            target.mkdir(parents=True, exist_ok=True)
            child_restored, child_skipped = restore_backup_tree(
                backup_dir, entry, home_dir
            )
            restored += child_restored
            skipped += child_skipped
        elif os.path.lexists(target):
            skipped += 1
        elif entry.is_symlink():
            target.parent.mkdir(parents=True, exist_ok=True)
            target.symlink_to(os.readlink(entry))
            restored += 1
        elif entry.is_file():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(entry, target)
            restored += 1
        else:
            skipped += 1
    return restored, skipped


def confirm(prompt: str) -> bool:
    try:
        return input(f"{prompt} [y/N] ").strip().lower() in {"y", "yes"}
    except (EOFError, KeyboardInterrupt):
        print("")
        return False


def current_login_shell() -> str:
    try:
        return pwd.getpwuid(os.getuid()).pw_shell
    except KeyError:
        return ""


def reset_login_shell_to_bash() -> None:
    bash = Path("/bin/bash")
    if not bash.is_file():
        raise RuntimeError(f"Bash was not found at {bash}; keeping zsh configuration.")
    run_cmd(["chsh", "-s", str(bash)])
    login_shell = current_login_shell()
    if not login_shell or Path(login_shell).resolve() != bash.resolve():
        raise RuntimeError(
            f"Login shell is still {login_shell or 'unknown'}; keeping {ZSH_CONFIG}."
        )


def load_package_uninstaller(
    maintenance_dir: Path,
) -> Callable[..., None]:
    sys.path.insert(0, str(maintenance_dir))
    try:
        component = importlib.import_module("components.packages")
        uninstall_packages = component.uninstall_packages
    except ImportError as exc:
        raise RuntimeError(
            "Could not load maintenance/components/packages.py; "
            "cannot safely remove the package list."
        ) from exc
    return uninstall_packages


def cleanup_system_changes(
    maintenance_dir: Path, remove_plugins: bool
) -> list[str]:
    sys.path.insert(0, str(maintenance_dir))
    failures = []

    cleanups = [
        ("sddm", "remove_arch_eclipse_sddm_config"),
        ("tweaks", "restore_tweaks"),
    ]
    if remove_plugins:
        cleanups.append(("plugins", "remove_plugins"))

    for component_name, function_name in cleanups:
        try:
            component = importlib.import_module(f"components.{component_name}")
            getattr(component, function_name)()
        except (
            AttributeError,
            ImportError,
            OSError,
            RuntimeError,
            subprocess.CalledProcessError,
        ) as exc:
            message = f"{component_name} cleanup failed: {exc}"
            print(message, file=sys.stderr)
            failures.append(message)
    return failures


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Remove ArchEclipse files and optionally its installed packages."
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Skip prompts; keep packages unless --remove-packages is set",
    )
    parser.add_argument(
        "--no-restore",
        action="store_true",
        help="Do not restore the latest dotfiles_backup_* after removal",
    )
    backup_group = parser.add_mutually_exclusive_group()
    backup_group.add_argument(
        "--backup",
        action="store_true",
        help="Create a temporary recovery backup in /tmp without prompting",
    )
    backup_group.add_argument(
        "--no-backup",
        action="store_true",
        help="Do not create a recovery backup or ask about one",
    )
    package_group = parser.add_mutually_exclusive_group()
    package_group.add_argument(
        "--remove-packages",
        action="store_true",
        help="Remove installed packages from the project list without prompting",
    )
    package_group.add_argument(
        "--keep-packages",
        action="store_true",
        help="Keep installed packages from the project list",
    )
    parser.add_argument(
        "--remove-plugins",
        action="store_true",
        help="Remove the Hyprland plugin repositories configured by ArchEclipse",
    )
    parser.add_argument(
        "--reset-shell",
        action="store_true",
        help="Switch the login shell to bash and remove ~/.zshrc",
    )
    args = parser.parse_args()

    if os.geteuid() == 0:
        raise SystemExit("Run this script as your regular user, not with sudo.")

    home_dir = Path.home().resolve()
    uninstaller_source = Path(__file__).resolve()
    maintenance_dir = uninstaller_source.parent
    if not (maintenance_dir / "components").is_dir():
        recovery_maintenance_dir = maintenance_dir / ".config/hypr/maintenance"
        if (recovery_maintenance_dir / "components").is_dir():
            maintenance_dir = recovery_maintenance_dir
    if not (maintenance_dir / "components").is_dir():
        raise SystemExit(
            f"Could not locate maintenance components for {uninstaller_source}"
        )
    try:
        repo_dir, managed_paths = find_repository_source(home_dir)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        raise SystemExit(
            f"Cannot determine ArchEclipse paths to remove: {exc}"
        ) from exc

    login_shell = current_login_shell()
    shell_name = Path(login_shell).name if login_shell else ""
    reset_shell = args.reset_shell
    if shell_name == "zsh" and not reset_shell and not args.yes:
        reset_shell = confirm(
            "Your login shell is zsh. Switch it to /bin/bash and remove ~/.zshrc?"
        )

    relative_paths = list(managed_paths)
    relative_paths.extend(
        path for path in EXTRA_MANAGED_PATHS if path not in relative_paths
    )
    remove_zsh = reset_shell or bool(shell_name and shell_name != "zsh")
    if remove_zsh and PurePosixPath(ZSH_CONFIG) not in relative_paths:
        relative_paths.append(PurePosixPath(ZSH_CONFIG))

    targets = existing_targets(home_dir, relative_paths)
    remove_packages_requested = args.remove_packages
    if not remove_packages_requested and not args.keep_packages and not args.yes:
        remove_packages_requested = confirm(
            "Remove installed packages listed by ArchEclipse?"
        )

    package_uninstaller = None
    if remove_packages_requested:
        try:
            package_uninstaller = load_package_uninstaller(maintenance_dir)
        except (ImportError, RuntimeError) as exc:
            raise SystemExit(f"Could not prepare package removal: {exc}") from exc

    if not targets:
        print("None of the listed ArchEclipse paths exist.")
        if package_uninstaller is not None:
            try:
                package_uninstaller(remove_zsh=remove_zsh)
            except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
                raise SystemExit(
                    f"Could not remove the selected packages: {exc}"
                ) from exc
        return

    print("The following paths will be removed completely:")
    for target in targets:
        print(f"  {target}")
    if not remove_zsh:
        reason = (
            "because the login shell is zsh"
            if shell_name == "zsh"
            else "because the login shell is unknown"
        )
        print(f"  Keeping {home_dir / ZSH_CONFIG} {reason}.")
    if remove_packages_requested:
        print(
            "Installed packages from components/packages.py will also be "
            "offered for removal individually; Pacman will keep packages "
            "required by other software."
        )
    remove_plugins = args.remove_plugins
    if not remove_plugins and not args.yes:
        remove_plugins = confirm(
            "Remove the Hyprland plugin repositories configured by ArchEclipse?"
        )
    if not args.yes and not confirm("Continue with ArchEclipse removal?"):
        print("Cancelled.")
        return

    create_backup = args.backup
    if not create_backup and not args.no_backup and not args.yes:
        create_backup = confirm("Create a temporary recovery backup in /tmp?")

    if create_backup:
        try:
            safety_backup, backed_up = create_safety_backup(
                home_dir, relative_paths, uninstaller_source
            )
        except (OSError, RuntimeError) as exc:
            raise SystemExit(
                f"Could not create the safety backup; nothing was removed: {exc}"
            ) from exc
        print(f"Safety copy of {backed_up} path(s): {safety_backup}")
        print(
            "If interrupted, resume with: "
            f"python3 {safety_backup / 'uninstall.py'} --yes --no-restore --no-backup"
        )
    else:
        print("No recovery backup will be created.")

    if reset_shell:
        try:
            reset_login_shell_to_bash()
        except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
            raise SystemExit(
                f"Could not switch the login shell; dotfiles were not removed: {exc}"
            ) from exc

    errors = cleanup_system_changes(
        maintenance_dir, remove_plugins=remove_plugins
    )

    repo_path = PurePosixPath("ArchEclipse")
    paths_before_repo = [path for path in relative_paths if path != repo_path]
    repo_paths = [path for path in relative_paths if path == repo_path]
    removed, removal_errors = remove_targets(home_dir, paths_before_repo)
    errors.extend(removal_errors)
    print(f"Removed {removed} path(s) (directories included all their contents).")

    if errors:
        print("Some paths could not be removed:", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)

    previous_backup = latest_dotfiles_backup(home_dir)
    should_restore = previous_backup is not None and not args.no_restore and (
        args.yes
        or confirm(f"Restore files from the installation backup {previous_backup}?")
    )
    if should_restore and previous_backup is not None:
        try:
            restored, skipped = restore_backup_tree(
                previous_backup, previous_backup, home_dir
            )
        except OSError as exc:
            print(f"Could not fully restore {previous_backup}: {exc}", file=sys.stderr)
            errors.append(str(exc))
        else:
            print(
                f"Restored {restored} file(s) from {previous_backup}; "
                f"skipped {skipped} existing or unsafe paths."
            )
    elif previous_backup is None:
        print("No previous dotfiles_backup_* directory found.")

    if not errors:
        repo_removed, repo_errors = remove_targets(home_dir, repo_paths)
        removed += repo_removed
        errors.extend(repo_errors)
        if repo_removed:
            print("Removed ~/ArchEclipse after completing other cleanup.")

    if errors:
        raise SystemExit(1)

    if package_uninstaller is not None:
        try:
            package_uninstaller(remove_zsh=remove_zsh)
        except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
            raise SystemExit(
                "ArchEclipse files were removed, but selected packages could "
                f"not be removed: {exc}"
            ) from exc

    print("")
    print("=" * 63)
    print("ArchEclipse removal completed successfully.")
    print("=" * 63)
    print("")
    print("Please reboot your system to apply all changes:")
    print("")
    print("sudo reboot")


if __name__ == "__main__":
    main()
