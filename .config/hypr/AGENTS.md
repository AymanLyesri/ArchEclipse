# AGENTS.md — hypr config (`~/.config/hypr`)

ArchEclipse Hyprland configuration. Lua-based config (`hyprland.lua` entrypoint,
requires Hyprland with Lua support), plus shell helpers, C daemons, wallpaper
daemon, theme scripts, `evremap`, and Python maintenance tooling.

> Scope: this file covers `~/.config/hypr` only. Quickshell bar lives in
> `~/.config/quickshell/archeclipse` — don't edit it from here.

## Layout

```
hyprland.lua            # entrypoint: sets XDG env, require_all() base modules, then custom/
config/*.lua            # tracked base config, one file per Hyprland section
config/custom/*.lua     # MACHINE-LOCAL overrides (gitignored, except .gitkeep)
config/defaults/*.lua   # template files with {{ PLACEHOLDERS }} for maintenance/install.py
hyprpaper.conf          # static hyprpaper config (splash off)
theme/theme.conf        # gitignored runtime theme state (autocolor/autovariant)
theme/scripts/          # wal/cwal, gtk/icon/cursor/system theme appliers
wallpaper-daemon/       # set-wallpaper.sh, hyprpaper.sh, mpvpaper.sh, reload.sh + config/<monitor>/defaults.conf
scripts/                # bar.sh, screenshot.sh, change-brightness.sh, clipboard-monitor.sh, ...
scripts-c/              # battery-check.c, updates-check.c, wallpaper-loop.c (compiled to /tmp by compile-run-binaries.sh)
evremap/                # remap.toml + configuration.sh + evremap.service (numlock/numpad remaps)
maintenance/            # update.py + install.py + components/*.py (ArchEclipse installer/updater)
```

## Load order (`hyprland.lua`)

1. `hl.env(...)` XDG vars.
2. `require_all({...})` — fixed alphabetical-ish list: animations, bind, decoration,
   device, env, exec, general, gesture, input, layerrule, layouts, misc, monitor,
   windowrule, workspace.
3. `require_custom_dir()` — loads every `config/custom/*.lua` sorted
   alphabetically (quoted path, `sort`). Keep custom modules self-contained
   anyway; don't rely on order.

To add a new base section: create `config/<name>.lua` + append to the
`require_all` list. For host-specific tweaks use `config/custom/` (never edit
tracked base files for local-only needs).

## Conventions

- Lua API is `hl.*`: `hl.config({...})`, `hl.bind(...)`, `hl.device(...)`,
  `hl.monitor(...)`, `hl.window_rule(...)`, `hl.layer_rule(...)`,
  `hl.workspace_rule(...)`, `hl.gesture(...)`, `hl.env(...)`, `hl.exec_cmd(...)`,
  `hl.on("hyprland.start", fn)`.
- Keybinds live in `config/bind.lua`. `mainMod = "SUPER"`. Comment each bind with
  `--- <description>` (one line above `hl.bind`). Quickshell IPC goes through
  `qsIpc = "qs -p <qsCfg> ipc call bar "` + action + monitor. The `monitor`
  var is a shell subshell evaluated at keypress time — keep it, and keep it
  cheap (`hyprctl activeworkspace -j`, never a full `monitors` scan per keypress).
- Never put `hyprpm reload && hyprctl reload` in `hyprland.start` (reload loop /
  slow start). Run `hyprpm` manually once after plugin changes.
- Window rules in `config/windowrule.lua`: one `hl.window_rule` per concern;
  merge rules with identical `match` instead of repeating them.
- Startup apps in `config/exec.lua` (`hl.on("hyprland.start", ...)`) and
  `config/custom/exec.lua` + `browser.lua` / `discord_client.lua` (workspace-tagged
  autostart). `config/defaults/*.lua` are the templated originals — update them
  when you change the corresponding `custom/` file's shape.
- Custom override files (`decoration_blur_size.lua` style, underscores — never
  colons, which break Lua `require` and most tooling) map 1:1 to a single key.
  Prefer editing the base file unless the value is truly host-local.
- Shell scripts: `#!/usr/bin/env bash` + `set -euo pipefail` for new code.
  C helpers: `gcc -O2 -Wall` semantics, no `system()` on hot paths (see
  `wallpaper-loop.c` `run_wait`/`spawn_detached` pattern).
- Wallpaper state: `wallpaper-daemon/config/<monitor>/defaults.conf`
  (`w-<id>=<path>` lines) is gitignored runtime state. `defaults.conf` at the
  top is the seed template. Never commit per-monitor files.
  `set-wallpaper.sh` holds `flock` on `${config}.lock` — don't add
  unsynchronized writers of `defaults.conf`.
- Wallpaper downloads (`maintenance/components/wallpapers.py`) manage ONLY the
  four `~/.config/wallpapers/defaults/<category>` dirs. Unknown top-level files
  are quarantined to `~/.cache/archeclipse-wallpaper-quarantine/<category>/`,
  never deleted; subdirs/symlinks are ignored entirely.
- Screenshots: `scripts/screenshot.sh --now|--area [output.png]`; heavy
  ImageMagick recompress is opt-in via `SCREENSHOT_OPTIMIZE=1` — keep it off.

## Maintenance (`maintenance/`)

- `install.py` / `update.py` share a plan-then-run UX (`presentation.py`):
  collect choices upfront, then run unattended. New steps: add a
  `PlannedStep`, load the module in `load_components`, execute it.
- `components/defaults.py` is copy-if-missing — it never overwrites
  `config/custom/`. To reset a custom file to default, delete it and re-run.
- `custom/browser.lua` / `discord_client.lua` are REGENERATED from
  `config/defaults/` templates on every install (`essentials.py`
  `_render_custom_config`). Keep the `{{ APP_NAME }}` / `{{ CLASS_NAME }}`
  markers intact in the defaults templates or installs break.
- `components/locales.py` (`ensure_arch_locale`) is wired as an opt-in
  install step — don't duplicate locale setup elsewhere.
- C helpers: `battery-check` reads `/sys/class/power_supply/BAT0|BAT1`
  directly (no `upower` dependency); `updates-check` uses `git -C $HOME`.

## Verify

- Syntax: `luac -p hyprland.lua config/*.lua config/custom/*.lua` (`config/defaults/`
  holds `{{ }}` template markers, not valid Lua — don't lint it), `bash -n scripts/*.sh`,
  `shellcheck scripts/*.sh wallpaper-daemon/*.sh theme/scripts/*.sh` (if installed),
  `python3 -m py_compile maintenance/install.py maintenance/update.py maintenance/components/*.py`.
- Reload live: `hyprctl reload` (or `hyprpm reload && hyprctl reload` after plugin changes).
- Startup exec: `hyprctl exec-once '...'` semantics — check `hyprctl exec-once` for dupes.
- C daemons: `gcc scripts-c/<name>.c -o /tmp/<name>` then run once manually.
- Wallpaper loop logs: `/tmp/wallpaper-daemon.log`.
- Bar logs: `/tmp/qs-bar-$USER.log`.

## Gotchas for agents

- `~` is a git repo with remote `origin https://github.com/AymanLyesri/ArchEclipse.git`;
  `~/.config/hypr` is its own repo with the SAME `origin` (AymanLyesri/ArchEclipse) —
  `VitoSanctis` is only a PR-review remote, never push to it. Don't commit,
  push, or run `maintenance/update.py` / `install.py` (they `reset --hard` and
  `cp -a` over `$HOME`). Read-only inspection only unless asked.
- Never commit `config/custom/`, `config/defaults/` generated output,
  `theme/theme.conf`, `wallpaper-daemon/config/*` (except seed `defaults.conf`),
  `monitors.conf/.lua`, `workspaces.conf/.lua`, `__pycache__/`.
- `compile-run-binaries.sh` installs cron entries only when missing and
  recompiles only stale binaries — safe to run once to test, but don't run
  it in a loop.
- `wl-paste --watch clipboard-monitor.sh` self-cleans stale watchers on
  start (`exec.lua`); when testing manually, still kill old
  `clipboard-monitor` / `wl-paste --watch` processes first.
- `maintenance/update.py` phones home to a counter URL, has NO backup before
  `reset --hard`, and uses `sudo`/`killall -9` on package managers — never
  execute it autonomously.
- The `archeclipse` updater is a zsh function (`~/.zshrc`) that fetches
  `update.py` REMOTELY on every run — editing the local copy does not change
  what `archeclipse` executes.
- `evremap/remap.toml` hardcodes `AT Translated Set 2 keyboard` — changes only
  apply to that device.
- Commit hygiene: `__pycache__/*.pyc` files exist on disk; if they show in
  `git status`, `git rm --cached` them instead of committing.
