# capture-readme — on-demand README screenshot refresher

Script: `scripts/capture-readme.py` (stdlib only + `grim` + `qs` + `hyprctl`).
Tests: `scripts/test_capture_readme.py` → `python3 scripts/test_capture_readme.py`.

The Quickshell side lives in `services/CaptureIpc.qml` (IPC target `capture`,
instantiated in `shell.qml`): a lease-guarded session that opens widgets,
reports the real pill geometry, and restores the prior bar state, left tab,
launcher results and bar reveal. Right-panel captures use temporary, nonpersistent
widget models; your configured layout is never overwritten. `Bar.qml` registers each
monitor's bar as `capture-bar-<monitor>` and exposes `captureGeometry()`.

## Usage (run from the `$HOME` dotfiles root)

```bash
python3 .config/quickshell/archeclipse/scripts/capture-readme.py --list
python3 .config/quickshell/archeclipse/scripts/capture-readme.py --dry-run
# All supported shots, previewed into a fresh cache dir:
python3 .config/quickshell/archeclipse/scripts/capture-readme.py
# Single widget preview:
python3 .config/quickshell/archeclipse/scripts/capture-readme.py --only left-panel-keybinds \
  --output-dir /tmp/archeclipse-capture-smoke
# Explicit install into .github/assets with backups + rollback:
python3 .config/quickshell/archeclipse/scripts/capture-readme.py --replace
```

## Live smoke test

`python3 .config/quickshell/archeclipse/scripts/smoke_capture_readme.py`

Requires Pillow in addition to the capture tools. Restarts this shell with
`MANGOHUD=0`, captures all nine supported shots, checks pixel statistics,
and verifies README/assets stayed unchanged. Outputs `report.json` and PNGs
in a fresh cache directory. It leaves the shell running. Pixel statistics
catch flat/empty pictures; they do not prove semantic correctness.

## Shots

Supported (captured live through the shell's own island state):
`app-launcher`, `right-panel-layout-1` (Waifu, Player, Calendar, Notification History),
`right-panel-layout-2` (Calendar, Player, Waifu, System Resources),
`left-panel-chatbot`, `left-panel-booru-1`, `left-panel-settings`,
`left-panel-keybinds`, `wallpaper-switcher`, `workspace-overview`.

Manual-only (listed with a reason, never faked): `overview` (desktop hero),
`dark-theme` / `light-theme` (whole-desktop theme switch), `lock-screen`
(current secure lock screen — never locked automatically; image: `.github/assets/lock-screen.png`).

`workspace-overview` writes a new PNG and updates only that README reference
(on `--replace` success). The original GIF remains on disk.

## Rules

- Default captures to a fresh preview dir under `~/.cache/archeclipse-capture/`;
  `--output-dir` is preview-only (refused with `--replace`).
- `--replace` installs into `.github/assets` only after ALL shots validate
  (real PNG, expected size, layout stable before and after `grim`) and the
  shell state restored successfully. Backups land in
  `~/.cache/archeclipse-capture/backups/<stamp>/` and are restored on any
  mid-install failure.
- A `begin` IPC lease snapshots the current bar state/tab; a watchdog
  (15 s, refreshed by every `status`) auto-restores if the script dies.
  Interruption (SIGINT/SIGTERM), capture failure, or failed restoration
  aborts with no install.
- Captures show live private content. Review every PNG before publishing.
  No auto upload/commit.

## How a capture works

1. Focused monitor via `hyprctl monitors -j` (never hardcoded).
2. `capture begin <monitor>` snapshots state (and pauses rival BarState
   activations while the lease is active).
3. `capture select <shot>` opens the island/launcher and primes content
   (launcher runs the `apps` query; BooruViewer readiness requires
   `progressStatus` not loading/error).
4. Poll `capture status` until the pill reports the desired state, the
   geometry (pill rect in surface coordinates) is stable for `--settle`
   seconds, and no images are still loading. Wallpaper capture also waits for
   a nonempty list, fetch/thumbnail-generation completion, aspect updates, and
   thumbnail decoding/fade-in (including tiles still at opacity zero).
   Empty/error wallpaper content times out instead of installing a blank capture.
   Use `--timeout 90` for slow first-load thumbnail generation.
5. Crop the pill rect from `hyprctl layers -j` and `grim -s 1 -g …`, then
   validate the PNG (CRCs, single IHDR, concatenated IDAT, IEND, expected
   dimensions) and re-verify the pill did not change during capture.
6. `capture end` restores; only then may `--replace` touch the repo.
