#!/usr/bin/env python3
"""Map Quickshell desktop-entry IDs to the source groups used by the launcher."""

import json
import os
import sys


def normalized(path):
    return os.path.normpath(path)


home = os.environ.get("HOME", "")
user_apps = normalized(os.path.join(home, ".local/share/applications"))
flatpak_user_apps = normalized(
    os.path.join(home, ".local/share/flatpak/exports/share/applications")
)
flatpak_system_apps = "/var/lib/flatpak/exports/share/applications"

data_home = os.environ.get("XDG_DATA_HOME") or os.path.join(home, ".local/share")
data_dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
application_dirs = [normalized(os.path.join(data_home, "applications"))]
application_dirs.extend(
    normalized(os.path.join(path, "applications"))
    for path in data_dirs.split(os.pathsep)
    if path
)


def source_group(path):
    if path == flatpak_user_apps:
        return "Flatpak User Applications"
    if path == flatpak_system_apps:
        return "Flatpak System Applications"
    if path == user_apps:
        return "User Applications"
    if path in ("/usr/share/applications", "/usr/local/share/applications"):
        return "System Applications"
    return "Other Applications"


sources = {}
for root in application_dirs:
    if not os.path.isdir(root):
        continue
    group = source_group(root)
    for current, _directories, filenames in os.walk(root):
        for filename in filenames:
            if not filename.endswith(".desktop"):
                continue
            path = os.path.join(current, filename)
            relative = os.path.relpath(path, root)
            # Quickshell forms IDs from relative desktop-file paths by
            # replacing directory separators with hyphens.
            desktop_id = relative[: -len(".desktop")].replace(os.sep, "-")
            # XDG roots are ordered by precedence; keep the first matching ID.
            sources.setdefault(desktop_id, group)

json.dump(sources, sys.stdout, separators=(",", ":"))
