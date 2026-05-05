#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ArchEclipse Maintenance Scripts - Python Migration

This directory contains Python versions of the ArchEclipse maintenance scripts.
All scripts have been migrated from Bash to Python while maintaining the same
functionality.

Directory Structure:
====================

maintenance/          - Original Bash scripts (preserved)
maintenance_py/       - New Python scripts
  ├── PRESENTATION.py  - Display utilities (library)
  ├── ESSENTIALS.py    - Essential utilities (library)
  ├── BACKUP.py        - Backup/restore dotfiles
  ├── CONFIGURE.py     - Configure keyboard layouts
  ├── DEFAULTS.py      - Set up default configs
  ├── INSTALL.py       - Full installation script
  ├── LOCALES.py       - Configure system locales
  ├── PLUGINS.py       - Install Hyprland plugins
  ├── SDDM.py          - Configure SDDM theme
  ├── TWEAKS.py        - Apply system tweaks
  ├── UPDATE.py        - Update system configs
  └── WALLPAPERS.py    - Manage wallpapers

Usage:
======

All scripts use Python 3 and can be executed directly:

    ./BACKUP.py
    ./CONFIGURE.py
    ./DEFAULTS.py
    ./INSTALL.py
    ./LOCALES.py
    ./PLUGINS.py
    ./SDDM.py
    ./TWEAKS.py
    ./UPDATE.py <branch>
    ./WALLPAPERS.py

Requirements:
=============

Core Python (3.7+) is required. The following system tools are recommended:
- figlet: For styled text output
- lolcat: For colored output
- fzf: For interactive selection
- curl: For HTTP requests
- git: For repository management
- ffmpeg: For video/image conversion (WALLPAPERS.py)
- hyprctl: For Hyprland configuration (CONFIGURE.py, PLUGINS.py)
- localectl: For keyboard configuration (CONFIGURE.py)

Key Changes from Bash:
======================

1. Module Structure:
   - PRESENTATION.py and ESSENTIALS.py are library modules
   - Other scripts import from these libraries
   - Use Python's import system instead of 'source' command

2. Error Handling:
   - Python's exception handling replaces Bash's set -euo pipefail
   - Subprocess calls are properly checked with return codes
   - Graceful degradation when external tools (figlet, lolcat) are unavailable

3. Package Management:
   - Subprocess module replaces shell command execution
   - Better cross-platform compatibility
   - Cleaner handling of complex command chains

4. Data Structures:
   - Python dictionaries replace Bash associative arrays
   - Lists replace Bash arrays
   - Better type safety and clarity

5. Interactive Input:
   - Python's input() replaces Bash's read command
   - Consistent handling of EOF and empty input
   - Better terminal handling

Testing Notes:
==============

The Python versions have been created to maintain functional equivalence with
the original Bash scripts. However, thorough testing is recommended before
production use, particularly for:

1. INSTALL.py - Complex multi-step installation
2. UPDATE.py - Repository management and sync
3. WALLPAPERS.py - URL handling and media conversion
4. ESSENTIALS.py - Package management functions

Compatibility:
==============

All Python scripts maintain backward compatibility with the original scripts:
- Same command-line arguments
- Same output formatting
- Same directory structures
- Same system operations

Migration Path:
===============

To use the Python scripts instead of Bash:
1. Replace references from ~/.config/hypr/maintenance/ paths
2. Change script extensions from .sh to .py
3. Ensure Python 3 is available in the system
4. Test each script individually before using in automation

Important Notes:
================

1. Both Bash and Python versions will coexist - the original scripts remain
   in the maintenance/ directory for reference and fallback.

2. The Python versions use subprocess to call external tools (sudo, git, pacman, etc.)
   which allows them to work on any Unix-like system with Python 3.

3. Some features like interactive terminal coloring require figlet and lolcat
   to be installed. Scripts gracefully fall back to plain text if unavailable.

4. The scripts maintain full permission requirements - sudo access is still
   required where necessary.

Author: Migration from Bash to Python
Date: 2026-05-05
License: Same as ArchEclipse project
"""

if __name__ == "__main__":
    print(__doc__)
