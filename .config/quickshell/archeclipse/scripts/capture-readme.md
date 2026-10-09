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
# All supported shots, auto-replacing .github/assets with backups:
python3 .config/quickshell/archeclipse/scripts/capture-readme.py
# Preview only into a fresh cache dir (no repo changes):
python3 .config/quickshell/archeclipse/scripts/capture-readme.py --no-replace
# Single widget preview:
python3 .config/quickshell/archeclipse/scripts/capture-readme.py --only left-panel-keybinds \
  --output-dir /tmp/archeclipse-capture-smoke
# Explicit install flag (default; kept for scripts that pass it):
python3 .config/quickshell/archeclipse/scripts/capture-readme.py --replace
# Fixed wallpaper for the run (path or http(s) URL, restored afterwards):
python3 .config/quickshell/archeclipse/scripts/capture-readme.py --wallpaper https://example.com/wall.jpg
```

## Live smoke test

`python3 .config/quickshell/archeclipse/scripts/smoke_capture_readme.py`

Requires Pillow in addition to the capture tools. Restarts this shell with
`MANGOHUD=0`, captures all ten supported shots, checks pixel statistics,
and verifies README/assets stayed unchanged. Outputs `report.json` and PNGs
in a fresh cache directory. It leaves the shell running. Pixel statistics
catch flat/empty pictures; they do not prove semantic correctness.

## Shots

Supported (captured live through the shell's own island state):
`overview` (ArchEclipse hero: player island + BooruViewer left +
default right + floating `foot` / `foot cava` at reference rects),
`app-launcher`, `control-panel`,
`right-panel-layout-1` (Waifu, Player, Calendar, Notification History),
`right-panel-layout-2` (Calendar, Player, Waifu, System Resources),
`left-panel-chatbot`, `left-panel-booru-1`, `left-panel-settings`,
`left-panel-keybinds`, `wallpaper-switcher`, `workspace-overview`.

`app-launcher`, `control-panel`, `wallpaper-switcher`, `workspace-overview`
and `overview`
capture the
full monitor output (wallpaper + island in context); the rest are pill
crops. The pill must still be open and layout-stable before any capture.

Manual-only (listed with a reason, never faked):
`dark-theme` / `light-theme` (whole-desktop theme switch), `lock-screen`
(current secure lock screen — never locked automatically; image: `.github/assets/lock-screen.png`).

`workspace-overview` writes a new PNG and updates only that README reference
(on `--replace` success). The original GIF remains on disk.

## Rules

- Default auto-replaces `.github/assets` (with backups + rollback, see
  below); `--no-replace` previews into a fresh dir under
  `~/.cache/archeclipse-capture/` without touching the repo.
  `--output-dir` is preview-only (implies `--no-replace`; refused with an
  explicit `--replace`).
- `--replace` installs into `.github/assets` only after ALL shots validate
  (real PNG, expected size, layout stable before and after `grim`) and the
  shell state restored successfully. Backups land in
  `~/.cache/archeclipse-capture/backups/<stamp>/` and are restored on any
  mid-install failure.
- A `begin` IPC lease snapshots the current bar state/tab; a watchdog
  (15 s, refreshed by every `status`) auto-restores if the script dies.
  Interruption (SIGINT/SIGTERM), capture failure, or failed restoration
  aborts with no install.
- Every run switches to empty workspace 10 first
  (`hyprctl dispatch 'hl.dsp.focus({workspace = 10})'`, created when
  missing) so open windows never leak into shots; the previous workspace
  is restored afterwards. After the switch the run waits
  `--workspace-settle` seconds (default 2) before any wallpaper change, so
  the compositor slide animation and the daemon's ws10 wallpaper reapply
  finish first.
- `--wallpaper` sets one image for the whole run (local path or
  http(s) URL, downloaded into `~/.cache/archeclipse-capture/wallpapers/`)
  via `walleclipse set`: the capture workspace mapping is updated and
  restored afterwards, no theme regen.
  A shot's own `wallpaper="..."` manifest entry wins for that shot.
  The saved mapping is restored afterwards.
- Captures show live private content. Review every PNG before publishing.
  No auto upload/commit.

## How a capture works

1. Focused monitor via `hyprctl monitors -j` (never hardcoded).
2. Switch to empty workspace 10 and wait until it is active, then wait out
   `--workspace-settle` so the wallpaper daemon's reapply settles.
3. `capture begin <monitor>` snapshots state (and pauses rival BarState
   activations while the lease is active).
3. `capture select <shot>` opens the island/launcher and primes content
   (launcher runs the `apps` query; BooruViewer readiness requires
   `progressStatus` not loading/error; `wallpaper-switcher` additionally
   switches the panel to `defaults/images_sfw` — first sfw-bearing
   category when it is missing — on the local provider, non-persistently).
4. Poll `capture status` until the pill reports the desired state, the
   geometry (pill rect in surface coordinates) is stable for `--settle`
   seconds, and no images are still loading. Wallpaper capture also waits for
   a nonempty list, fetch/thumbnail-generation completion, aspect updates, and
   thumbnail decoding/fade-in (including tiles still at opacity zero).
   Empty/error wallpaper content times out instead of installing a blank capture.
   Use `--timeout 90` for slow first-load thumbnail generation.
5. Crop from `hyprctl layers -j` and `grim -s 1 -g …`, then
   validate the PNG (CRCs, single IHDR, concatenated IDAT, IEND, expected
   dimensions) and re-verify the pill did not change during capture.
   Pill shots crop the pill rect; fullscreen shots capture the whole
   monitor rect.
6. `capture end` restores shell state (including the wallpaper
   category/provider the `wallpaper-switcher` detour borrowed), then the
   previous workspace is restored; only then may `--replace` touch the repo.
