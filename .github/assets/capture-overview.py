#!/usr/bin/env python3
"""Record the ArchEclipse overview demo (README hero) as an mp4.

Drives the live shell end to end: per-workspace wallpapers (WallEclipse),
fabricated chatbot session, launcher selections (foot / cava) landed on the
capture workspace at the same rects capture-readme.py uses, right-panel
layout shuffle, left-panel tab walk, and wallpaper-switcher demonstrates.

State mutated during the run (wallpaper mappings, rightPanel.widgets,
waifuWidget.current, booru.pins, booru.tags, the fastfetch pin cache, the temp
chatbot session) is restored afterwards.
Owns nothing but what it spawned: spawned windows are closed by the exact
pid observed at mapping — never kill by class or workspace (a user SCP or
terminal must survive a capture run).

Requires the scripted-capture IPC helpers in services/Ipc.qml
(launcherActivate, launcherRow, chatSession).
"""

import argparse
import base64
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid

ASSETS = Path(__file__).resolve().parent  # ~/.github/assets
OUTPUT = ASSETS / "overview.mp4"
CACHE = (
    Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
    / "archeclipse-capture"
)
QS_CONFIG = Path.home() / ".config/quickshell/archeclipse"
SETTINGS = (
    Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
    / "quickshell/settings/settings.json"
)
CHATBOT_SESSIONS = (
    Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
    / "quickshell/chatbot/sessions"
)
RECORDINGS = Path.home() / "Videos/ScreenRecords/fullscreen"
SCREENRECORD_SCRIPT = Path.home() / ".config/hypr/scripts/screenrecord.sh"
# FastfetchPins renders one webp per pin here; fastfetch.sh shuffles every file
# in the dir, so the demo pin only shows if its render is the only one left.
FASTFETCH_CACHE = Path.home() / ".config/fastfetch/cache"
PIN_CACHE_PREFIX = "booru-pin-"
PIN_CACHE_TIMEOUT = 30.0
CAPTURE_WS = 10
WS9 = 9
# Wallpaper daemon reapplies + opacity transitions; the dwells double as
# the on-camera time each change is visible in the recording.
WORKSPACE_SETTLE = 1.0
WALLPAPER_SETTLE = 1.0
STEP_SETTLE = 1.0
IPC_SETTLE = 0.5
# `qs ipc` answers this while the shell's IPC server is still coming up after a
# reload; the call is never delivered, so a retry cannot apply twice.
IPC_NOT_READY = "Not ready to accept queries yet."
IPC_READY_TIMEOUT = 5.0
# BooruViewer.boot() retries on a 200ms timer and then starts its fetch; the
# demo tags are pushed after both, or a late boot write overwrites them.
BOOT_SETTLE = 1.0
# The bar adopts a recording it did not start on its 1s pgrep poll; this
# dwell lets the sidepill show the running timer before the take begins.
RECORD_SETTLE = 1.5
# Settings.qml watches the file and reloads after a short delay — the
# reactive bindings (right-island widget order, waifu, booru) follow once
# reload lands.
SETTINGS_SETTLE = 2.0
# Visible dwell after each right-panel reorder — the IPC write is
# synchronous, so this is the only wait between layouts.
LAYOUT_SWITCH_DWELL = 1.0
# Window for in-flight shell writers to flush before the drift re-check.
RESTORE_RECHECK = 4.0
# Final mp4 pass goes through compress-video.py (never-bigger in-place).
COMPRESS_AFTER_TAKE = True
# The GIF is the README-sharable artifact (repo mp4 links don't render);
# with dither=none defaults it lands near mp4 size. Off via --no-gif.
GIF_AFTER_TAKE = False

SHELL_API_BOORU = "danbooru"

WAIFU_POST_ID = 8951684
BOORU_TAG = "+rating:g"
WALLPAPER_CATEGORY = "defaults/images_sfw"
CHAT_SESSION_ID = "session-capture-demo"

WALLPAPERS = {
    "shorekeeper": "~/.config/wallpapers/defaults/images_sfw/__shorekeeper_wuthering_waves_drawn_by_void_0__64f5d0531e563ffa6397a023d1e59415.jpg",
    "cartethyia": "~/.config/wallpapers/defaults/images_sfw/__cartethyia_wuthering_waves_drawn_by_void_0__2e35f55f3eb0407853fe119418e4a57e.jpg",
    "chiori": "~/.config/wallpapers/defaults/images_sfw/__chiori_genshin_impact_drawn_by_void_0__8b6aee8b720517f41c675fb49a0f02c1.jpg",
    "yoru": "~/.config/wallpapers/defaults/images_sfw/__yoru_mitaka_asa_pochita_war_devil_and_bucky_chainsaw_man_drawn_by_eaechas__40574201912be4a9dec5589b3374350c.jpg",
    "columbina": "~/.config/wallpapers/defaults/images_sfw/__columbina_genshin_impact_drawn_by_void_0__86cc14bd3da8a9578bff20e148c1e74a.jpg",
}
# Overview hero floats, from capture-readme.py's OVERVIEW_FLOATS (1920x1080).
# cava has no desktop entry: the launcher's `term` prefix mode runs it in
# foot (foot running bash -c cava) — deterministic, unlike the fuzzy
# "Try ... in terminal" fallback that vanishes once any entry matches.
OVERVIEW_FLOATS = [
    dict(query="apps foot", row="foot", x=935, y=580, w=1091, h=469),
    dict(query="term cava", row="Run cava", x=1184, y=389, w=652, h=161),
]
RIGHT_LAYOUTS = [
    (
        "waifu>player>calendar>resources",
        ["Waifu", "Media", "Calendar", "SystemResources"],
    ),
    (
        "player>waifu>resources>calendar",
        ["Media", "Waifu", "SystemResources", "Calendar"],
    ),
    (
        "calendar>resources>waifu>player",
        ["Calendar", "SystemResources", "Waifu", "Media"],
    ),
]
LEFT_TABS = [
    # "UserProfile",
    "BooruViewer",
    "ChatBot",
    # "MangaViewer",
    "SettingsWidget",
    "CustomScripts",
    "KeyBinds",
    # "Donations",
]
CHAT_CONVERSATION = [
    ("user", "Hi! Can you create a Java hello world block for me?"),
    (
        "assistant",
        "Sure! Here is a minimal Java hello world:\n\n```java\n"
        "public class HelloWorld {\n"
        "    public static void main(String[] args) {\n"
        '        System.out.println("Hello, world!");\n'
        "    }\n"
        "}\n"
        "```\n\n"
        "Compile it with `javac HelloWorld.java` and run with `java HelloWorld`.",
    ),
    ("user", "Nice. How do you use markdown formatting like headings, bold and lists?"),
    (
        "assistant",
        "Of course — markdown is all about simple text markers:\n\n"
        "## Heading\n\n"
        "Some **bold**, some *italic*, and some `inline code`.\n\n"
        "- Bullet one\n"
        "- Bullet two\n"
        "  - nested bullet\n\n"
        "1. Numbered one\n"
        "2. Numbered two",
    ),
    ("user", "Show me a small table and a Python inline example."),
    (
        "assistant",
        "Here you go:\n\n"
        "```python\n"
        'print(f"{2 + 2 = }")  # 2 + 2 = 4\n'
        "```\n\n"
        "| Layout | Order |\n"
        "| --- | --- |\n"
        "| waifu | 1 |\n"
        "| player | 2 |",
    ),
]


def run(cmd, timeout=10):
    try:
        return subprocess.run(
            [str(x) for x in cmd],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=True,
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError) as e:
        raise RuntimeError(
            f"Command failed: {cmd}: {getattr(e, 'stderr', '') or e}"
        ) from e


def ipc_call(action, *args, timeout=10):
    deadline = time.monotonic() + IPC_READY_TIMEOUT
    while True:
        text = run(
            ["qs", "-p", QS_CONFIG, "ipc", "call", "bar", action, *args], timeout
        )
        if text != IPC_NOT_READY:
            break
        if time.monotonic() >= deadline:
            raise RuntimeError(f"ipc {action}: shell is not accepting queries")
        time.sleep(0.25)
    if text.startswith("EX: "):
        raise RuntimeError(f"ipc {action}: {text}")
    return text


def focused_monitor():
    monitors = json.loads(run(["hyprctl", "monitors", "-j"]))
    focused = [m for m in monitors if m.get("focused") and not m.get("disabled")]
    if len(focused) != 1:
        raise RuntimeError("Expected one focused monitor")
    return focused[0]["name"]


def active_workspace():
    info = json.loads(run(["hyprctl", "activeworkspace", "-j"]))
    workspace_id = info.get("id")
    if not isinstance(workspace_id, int):
        raise RuntimeError("Unexpected active workspace output")
    return workspace_id


def ensure_workspace(workspace_id, timeout=10):
    # Hyprland's Lua config evaluates dispatch args as Lua: the
    # `hl.dsp.focus` dispatcher works (cf. capture-readme.py) — but
    # dispatching the already-active workspace bounces focus back to the
    # last window's workspace, so no-op when current first.
    if active_workspace() == workspace_id:
        return
    run(
        ["hyprctl", "dispatch", f"hl.dsp.focus({{workspace = {workspace_id}}})"],
        timeout=timeout,
    )
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if active_workspace() == workspace_id:
            return
        time.sleep(0.2)
    raise RuntimeError(f"Workspace {workspace_id} did not become active")


def resolve_wallpaper(url):
    path = Path(url).expanduser()
    if not path.is_file():
        raise RuntimeError("Wallpaper not found: " + url)
    return str(path)


def settings_set(key, value, settle=SETTINGS_SETTLE):
    """Push a setting leaf through the shell's own updateSetting path.

    Writing settings.json directly is clobbered by the shell's scheduled
    persist before the watcher adopts it — the widget drag-reorder and the
    wallpaper picker push through Ipc settingsSet, so the capture does the
    same. Base64: qs ipc splits raw args on spaces/commas. The IPC applies
    synchronously in-process, so callers can shrink settle to just the
    visible dwell they need.
    """
    result = ipc_call(
        "settingsSet",
        key,
        base64.b64encode(json.dumps(value, separators=(",", ":")).encode()).decode(),
    )
    if not result.startswith("set " + key):
        raise RuntimeError(f"settingsSet {key}: {result}")
    time.sleep(settle)


def pin_render_name(pin):
    """Cache filename FastfetchPins derives from a pin (sanitized api + id)."""
    api = (pin.get("api") or {}).get("value")
    if not isinstance(api, str) or not api or pin.get("id") is None:
        return None
    api = re.sub(r"[^a-zA-Z0-9_-]", "_", api)
    return f"{PIN_CACHE_PREFIX}{api}-{pin['id']}.webp"


def wait_pin_renders(pins, timeout=PIN_CACHE_TIMEOUT, strict=False):
    """Poll until FastfetchPins has rendered each pin's webp (async magick)."""
    wanted = {name for name in map(pin_render_name, pins) if name}
    deadline = time.monotonic() + timeout
    while True:
        missing = sorted(n for n in wanted if not (FASTFETCH_CACHE / n).is_file())
        if not missing:
            return
        if time.monotonic() >= deadline:
            message = "fastfetch pin renders missing: " + ", ".join(missing)
            if strict:
                raise RuntimeError(message)
            print("WARNING: " + message, flush=True)
            return
        time.sleep(0.25)


def pin_fastfetch_image():
    """Leave the demo pin as the only image fastfetch can shuffle.

    FastfetchPins converts asynchronously, and its stale sweep drops at most a
    file or two per pass (every removal shares one Process, so most never run)
    — unpinned renders linger and fastfetch.sh's shuffle can pick an old post.
    Wait for the demo render, drop the rest, and refuse to record with a
    foreign image present rather than record the wrong logo.
    """
    demo = {"id": WAIFU_POST_ID, "api": {"value": SHELL_API_BOORU}}
    FASTFETCH_CACHE.mkdir(parents=True, exist_ok=True)
    wait_pin_renders([demo], strict=True)
    expected = pin_render_name(demo)
    for stale in FASTFETCH_CACHE.glob(PIN_CACHE_PREFIX + "*.webp"):
        if stale.name != expected:
            stale.unlink(missing_ok=True)
    extra = sorted(
        p.name
        for p in FASTFETCH_CACHE.iterdir()
        if not p.name.startswith(".") and p.name != expected
    )
    if extra:
        raise RuntimeError(
            "fastfetch cache holds images the take would shuffle in: "
            + ", ".join(extra)
        )
    print(f"Fastfetch image: post {WAIFU_POST_ID} only", flush=True)


def restore_fastfetch_pins(snap):
    """Wait for the restored pins to be re-rendered (we deleted stale ones)."""
    if snap.pins:
        wait_pin_renders(snap.pins)


class Snapshot:
    """Pre-capture state used both by setup and restore."""

    def __init__(self):
        self.monitor = focused_monitor()
        ipc_call("barDiag", "state")  # raises if the shell is not reachable
        self.workspace = active_workspace()
        self.mapping = {}
        for line in run(["walleclipse", "list"]).splitlines():
            parts = line.split(None, 2)
            if len(parts) == 3 and parts[0] == self.monitor:
                self.mapping[int(parts[1])] = parts[2].strip()
        self.settings = json.loads(SETTINGS.read_text())
        self.right_widgets = self.settings.get("rightPanel", {}).get("widgets")
        self.waifu = self.settings.get("waifuWidget", {}).get("current")
        self.pins = self.settings.get("booru", {}).get("pins")
        self.tags = self.settings.get("booru", {}).get("tags")
        # showWidget/chatSession persist the left island's selected tab
        # override (leftPanel.monitors.<mon>.widget) — restore it wholesale.
        self.left_monitors = self.settings.get("leftPanel", {}).get("monitors")
        self.recordings = (
            sorted(RECORDINGS.glob("screenrecord*.mp4")) if RECORDINGS.is_dir() else []
        )


def dry_check(snap):
    for name in ("cartethyia", "chiori", "yoru", "columbina"):
        resolve_wallpaper(WALLPAPERS[name])
    if not SCREENRECORD_SCRIPT.is_file():
        raise RuntimeError("Recording script not found: " + str(SCREENRECORD_SCRIPT))
    data = snap.settings
    if data.get("booru", {}).get("selectedTab") != "Danbooru":
        raise RuntimeError("booru.selectedTab is not Danbooru")
    if data.get("wallpaperSwitcher", {}).get("category") != WALLPAPER_CATEGORY:
        raise RuntimeError(f"wallpaperSwitcher.category is not {WALLPAPER_CATEGORY}")
    pinned = any(
        int(p.get("id", 0)) == WAIFU_POST_ID
        for p in data.get("booru", {}).get("pins") or []
    )
    print(
        f"Dry check OK: monitor={snap.monitor}, ws={snap.workspace}"
        + f", post {WAIFU_POST_ID} {'pinned' if pinned else 'via booru.py'}"
        + ", wallpaper files exist, screenrecord.sh present",
        flush=True,
    )


def setup_phase(snap):
    setup_wallpapers(snap)
    waifu = fetch_waifu_post(snap)
    # BooruViewer's Pins tab and the profile pin count read this list; the
    # demo shows exactly one pinned post.
    settings_set("booru.pins", [waifu])
    print(f"Booru pins: post {WAIFU_POST_ID} only", flush=True)
    pin_fastfetch_image()
    prime_booru_viewer(snap)
    current = snap.settings.get("waifuWidget", {}).get("current") or {}
    if int(current.get("id", 0)) != WAIFU_POST_ID:
        settings_set("waifuWidget.current", waifu)
        print(f"Waifu set to post {WAIFU_POST_ID}", flush=True)
    write_chatbot_session()
    activate_chatbot_session(snap)


def setup_wallpapers(snap):
    cartethyia = resolve_wallpaper(WALLPAPERS["cartethyia"])
    yoru = resolve_wallpaper(WALLPAPERS["yoru"])
    run(["walleclipse", "set", snap.monitor, str(WS9), cartethyia])
    print(f"ws{WS9} wallpaper: " + Path(cartethyia).name, flush=True)
    run(["walleclipse", "set", snap.monitor, str(CAPTURE_WS), yoru])
    print(f"ws{CAPTURE_WS} wallpaper: " + Path(yoru).name, flush=True)
    time.sleep(WALLPAPER_SETTLE)


def fetch_waifu_post(snap):
    """Full waifu object for post 8951684: from a booru pin, else booru.py."""
    pins = snap.settings.get("booru", {}).get("pins") or []
    for pin in pins:
        if int(pin.get("id", 0)) == WAIFU_POST_ID:
            return dict(pin)
    booru = snap.settings.get("booru", {})
    api = dict(booru.get("api") or {})
    api.setdefault("name", "Danbooru")
    api.setdefault("value", SHELL_API_BOORU)
    api.setdefault("url", "https://danbooru.donmai.us/")
    api.setdefault("idSearchUrl", "https://danbooru.donmai.us/posts/")
    cmd = [
        "python3",
        str(QS_CONFIG / "scripts/booru.py"),
        "--api",
        SHELL_API_BOORU,
        "--id",
        str(WAIFU_POST_ID),
    ]
    keys = snap.settings.get("apiKeys", {}).get(SHELL_API_BOORU) or {}
    if keys.get("user") and keys.get("key"):
        cmd += ["--api-user", keys["user"], "--api-key", keys["key"]]
    post = json.loads(run(cmd, timeout=30))
    if not post or int(post[0].get("id", 0)) != WAIFU_POST_ID:
        raise RuntimeError("booru.py could not fetch post " + str(WAIFU_POST_ID))
    post[0].update(api)  # api identity travels inside the waifu object
    return post[0]


def write_chatbot_session():
    session = CHATBOT_SESSIONS / CHAT_SESSION_ID
    if session.exists():
        shutil.rmtree(session)  # our own temp dir, never a user session
    session.mkdir(parents=True)
    messages = []
    clock = time.time() * 1000
    for role, content in CHAT_CONVERSATION:
        response_time = 0 if role == "user" else 900 + len(content) % 1700
        messages.append(
            dict(
                id=str(uuid.uuid4()),
                role=role,
                content=content,
                timestamp=int(clock),
                responseTime=response_time,
            )
        )
        clock += response_time + 2400
    (session / "history.json").write_text(json.dumps(messages, indent=2))
    (session / "meta.json").write_text(
        json.dumps(dict(name="Capture Demo", updatedAt=int(time.time() * 1000)))
    )
    print("Temp session written: " + str(session), flush=True)


def activate_chatbot_session(snap):
    """chatSession primes the ChatBot tab itself (Registry.selectLeftTab).

    The island only exists after its first open, so one toggle may be
    needed; the Loader activates async — retry until the widget reports
    the switch.
    """
    opened = False
    for _ in range(8):
        result = ipc_call("chatSession", CHAT_SESSION_ID, snap.monitor)
        if "no island" in result and not opened:
            ipc_call("toggleLeftPanel", snap.monitor)
            opened = True
            continue
        if "no island" not in result and "not ready" not in result:
            break
        time.sleep(IPC_SETTLE)
    if "chat session=" + CHAT_SESSION_ID not in result:
        if opened:
            ipc_call("toggleLeftPanel", snap.monitor)
        raise RuntimeError("chatSession failed: " + result)
    # chatSession primes the ChatBot tab via Registry.selectLeftTab, which
    # activates the left island on every call — always close it again, and
    # keep the panel/graveyard state out of the capture workspace restore.
    ipc_call("toggleLeftPanel", snap.monitor)
    print("Chatbot session active: " + CHAT_SESSION_ID, flush=True)


def set_left_panel(snap, open_):
    """toggleLeftPanel reports the resulting state; flip it back if wrong."""
    state = ipc_call("toggleLeftPanel", snap.monitor).strip().endswith("open")
    if state != open_:
        state = ipc_call("toggleLeftPanel", snap.monitor).strip().endswith("open")
    if state != open_:
        raise RuntimeError("left island would not " + ("open" if open_ else "close"))


def booru_live_tags(snap):
    return ipc_call("widgetState", "tags", snap.monitor)


def wait_booru_fetch(snap, timeout=45):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        status = ipc_call("widgetState", "fetchStatus", snap.monitor)
        if status == "success":
            return
        if status == "error":
            raise RuntimeError(
                "Booru fetch failed: "
                + ipc_call("widgetState", "lastFetchError", snap.monitor)
            )
        time.sleep(0.5)
    raise RuntimeError("Booru fetch did not finish")


def prime_booru_viewer(snap):
    """Load the Booru tab, then push the demo tags onto the booted widget.

    boot() calls ensureRatingTagFirst(), which prepends -rating:explicit unless
    the list already carries a rating:explicit entry — a first load during the
    take rewrites the demo tags on camera. Booting the lazy Loader here spends
    that one-shot normalization, and the grid is re-fetched so it shows the
    demo query instead of the fetch boot() started with.
    """
    set_left_panel(snap, True)
    ipc_call("showWidget", "BooruViewer", snap.monitor)
    deadline = time.monotonic() + 15
    live = ""
    while time.monotonic() < deadline:
        live = booru_live_tags(snap)
        if not live.startswith("no "):
            break
        time.sleep(0.25)
    else:
        set_left_panel(snap, False)
        raise RuntimeError("BooruViewer never loaded: " + live)
    time.sleep(BOOT_SETTLE)
    settings_set("booru.tags", [BOORU_TAG])
    print("Booru tags: " + BOORU_TAG, flush=True)
    result = ipc_call("widgetState", "fetchApi", snap.monitor)
    if not result.startswith("fetchImages called"):
        set_left_panel(snap, False)
        raise RuntimeError("Booru refetch not started: " + result)
    wait_booru_fetch(snap)
    live = booru_live_tags(snap)
    if live != BOORU_TAG:
        # A late boot write raced the push — reapply once before giving up.
        settings_set("booru.tags", [BOORU_TAG])
        live = booru_live_tags(snap)
        if live != BOORU_TAG:
            set_left_panel(snap, False)
            raise RuntimeError(f"Booru tags are {live!r}, expected {BOORU_TAG!r}")
    set_left_panel(snap, False)
    print("Booru viewer primed, tags applied", flush=True)


def _foot_clients():
    try:
        return [
            c
            for c in json.loads(run(["hyprctl", "clients", "-j"]))
            if c.get("class") == "foot"
        ]
    except (RuntimeError, ValueError):
        return []


def process_start_ticks(pid):
    """Process start time in boot ticks — unique across pid reuse."""
    try:
        tail = Path(f"/proc/{pid}/stat").read_text().rsplit(") ", 1)[1]
        return int(tail.split()[19])
    except (OSError, IndexError, ValueError):
        return 0


def _wait_new_foot(baseline, timeout=15):
    # Adopt only a foot that started strictly AFTER the baseline sample:
    # client lists can miss windows, and a pid not in the baseline is not
    # proof of ownership (ours spawned later; the user's did not).
    floor = max([process_start_ticks(int(pid)) for pid in baseline] + [0])
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        found = [
            c
            for c in _foot_clients()
            if int(c["pid"]) not in baseline
            and process_start_ticks(int(c["pid"])) > floor
        ]
        if found:
            return max(found, key=lambda c: int(c["pid"]))  # newest spawn wins
        time.sleep(0.25)
    raise RuntimeError("No new foot window mapped after launcher activate")


def ensure_search_closed(monitor):
    # A leftover-open search session routes presetSearch through its
    # in-place runQuery branch, where the "apps " preset gets clobbered
    # and the query degrades to fuzzy (11 mixed rows) — reset to the
    # proven close-then-stash path.
    if ipc_call("barDiag", "state") != "search":
        return
    ipc_call("toggleSearch", monitor)
    time.sleep(IPC_SETTLE)
    if ipc_call("barDiag", "state") == "search":
        raise RuntimeError("search island would not close")


def launcher_place_floats(snap, on_spawned):
    baseline = {int(c["pid"]) for c in _foot_clients()}
    for spec in OVERVIEW_FLOATS:
        ensure_search_closed(snap.monitor)
        ipc_call("presetSearch", spec["query"], snap.monitor)
        time.sleep(IPC_SETTLE)
        # Cold-boot race: LauncherPanel's onPanelStatesByMonitorChanged
        # (150ms after open) re-runs its pending-or-default path, and with
        # the stash already consumed that lands on the recents list. The
        # second call goes through the already-open branch and re-applies
        # the real query.
        ipc_call("presetSearch", spec["query"], snap.monitor)
        time.sleep(IPC_SETTLE)
        row = ipc_call("launcherRow", snap.monitor)
        if spec["row"].lower() not in row.lower():
            raise RuntimeError(f"Launcher row does not match {spec['query']}: {row}")
        ipc_call("launcherActivate", snap.monitor)
        target = _wait_new_foot(baseline)
        pid = int(target["pid"])
        baseline.add(pid)
        on_spawned(pid)
        address = target["address"]
        # Launcher-launched apps inherit the shell's tracked workspace, not
        # the focused one — pull the fresh client onto the capture workspace
        # first, then float + size + position it at the reference rect.
        run(
            [
                "hyprctl",
                "dispatch",
                "hl.dsp.window.move({workspace = %d, follow = false, "
                'window = "address:%s"})' % (CAPTURE_WS, address),
            ]
        )
        run(
            [
                "hyprctl",
                "dispatch",
                'hl.dsp.window.float({window = "address:%s"})' % address,
            ]
        )
        time.sleep(0.2)
        run(
            [
                "hyprctl",
                "dispatch",
                'hl.dsp.window.resize({window = "address:%s", x = %d, y = %d})'
                % (address, spec["w"], spec["h"]),
            ]
        )
        time.sleep(0.2)
        run(
            [
                "hyprctl",
                "dispatch",
                'hl.dsp.window.move({window = "address:%s", x = %d, y = %d})'
                % (address, spec["x"], spec["y"]),
            ]
        )
        client = next((c for c in _foot_clients() if int(c["pid"]) == pid), None)
        if client is None:
            raise RuntimeError("Placed window vanished during placement")
        if (
            list(client.get("at", [])) != [spec["x"], spec["y"]]
            or list(client.get("size", [])) != [spec["w"], spec["h"]]
            or not client.get("floating")
            or client.get("workspace", {}).get("id") != CAPTURE_WS
        ):
            raise RuntimeError(
                "Float misplaced: "
                + json.dumps({"at": client.get("at"), "size": client.get("size")})
            )
        print(
            f"Launched {spec['row']} at {spec['x']},{spec['y']} "
            f"{spec['w']}x{spec['h']}",
            flush=True,
        )


def close_spawned(spawned):
    """SIGTERM only pids this run observed mapping; nobody else's windows."""
    for pid in list(spawned):
        try:
            os.kill(pid, signal.SIGTERM)
        except (OSError, ValueError):
            pass
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        alive = {int(c["pid"]) for c in _foot_clients()}
        if all(pid not in alive for pid in spawned):
            return
        time.sleep(0.3)
    raise RuntimeError("Spawned windows did not exit: " + str(spawned))


def process_right_layouts(snap):
    ipc_call("toggleRightPanel", snap.monitor)
    time.sleep(IPC_SETTLE)
    for label, order in RIGHT_LAYOUTS:
        settings_set(
            "rightPanel.widgets",
            [dict(name=n, enabled=True) for n in order],
            settle=LAYOUT_SWITCH_DWELL,
        )
        print("Right panel layout: " + label, flush=True)
    ipc_call("toggleRightPanel", snap.monitor)


def process_left_tabs(snap):
    ipc_call("toggleLeftPanel", snap.monitor)
    time.sleep(IPC_SETTLE)
    for tab in LEFT_TABS:
        result = ipc_call("showWidget", tab, snap.monitor)
        print("Left tab: " + tab + " (" + result + ")", flush=True)
        time.sleep(STEP_SETTLE)
    ipc_call("toggleLeftPanel", snap.monitor)


def process_wallpaper_switcher(snap, wallpaper, workspace):
    ipc_call("togglePanel", "wallpaper-switcher", snap.monitor)
    time.sleep(IPC_SETTLE)
    run(["walleclipse", "set", snap.monitor, str(workspace), wallpaper])
    print(f"Switcher -> {Path(wallpaper).name} on ws{workspace}", flush=True)
    ipc_call("togglePanel", "wallpaper-switcher", snap.monitor)
    time.sleep(WALLPAPER_SETTLE)


def start_recording(snap):
    # Drive screenrecord.sh directly: the shell's screenrecord IPC returns
    # "started" while ScreenRecorder.starting is still set (its pgrep poll +
    # 1.2s settle lag), so the sidepill would spend the take's first seconds
    # on its spinner. The script exits 0 only after gpu-screen-recorder is
    # verified up, and the bar's own poll adopts the external recording.
    run([SCREENRECORD_SCRIPT, "start", "--monitor", snap.monitor], timeout=30)
    print("Recording started: " + snap.monitor, flush=True)


def stop_recording(snap):
    # The script owns the pid file and blocks until the recorder is gone.
    run([SCREENRECORD_SCRIPT, "stop"], timeout=30)


def collect_recording(before, out_path):
    fresh = [
        p
        for p in sorted(
            RECORDINGS.glob("screenrecord*.mp4"), key=lambda p: p.stat().st_mtime
        )
        if p not in before and p.stat().st_size > 0
    ]
    if not fresh:
        raise RuntimeError("No recording file appeared in " + str(RECORDINGS))
    src = fresh[-1]
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".capture-video-", dir=out_path.parent)
    os.close(fd)
    try:
        shutil.copy2(src, tmp)
        with open(tmp, "rb") as head:
            if head.read(12)[4:8] != b"ftyp":
                raise RuntimeError("Not an mp4: " + str(src))
        os.replace(tmp, out_path)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise
    print(f"Recording: {src} -> {out_path}", flush=True)


def restore_settings(snap):
    if snap.right_widgets is not None:
        settings_set("rightPanel.widgets", snap.right_widgets)
    if snap.waifu is not None:
        settings_set("waifuWidget.current", snap.waifu)
    if snap.pins is not None:
        settings_set("booru.pins", snap.pins)
    if snap.tags is not None:
        settings_set("booru.tags", snap.tags)
    if snap.left_monitors is not None:
        settings_set("leftPanelByMonitor", snap.left_monitors)


def settings_drifted(snap, current):
    widgets = current.get("rightPanel", {}).get("widgets", [])
    if snap.right_widgets is not None and [w.get("name") for w in widgets] != [
        w.get("name") for w in snap.right_widgets
    ]:
        return True
    waifu = current.get("waifuWidget", {}).get("current") or {}
    if snap.waifu is not None and waifu.get("id") != (snap.waifu or {}).get("id"):
        return True
    pins = current.get("booru", {}).get("pins") or []
    if snap.pins is not None and [p.get("id") for p in pins] != [
        p.get("id") for p in snap.pins
    ]:
        return True
    if snap.tags is not None and (
        current.get("booru", {}).get("tags") or []
    ) != snap.tags:
        return True
    if (
        snap.left_monitors is not None
        and current.get("leftPanel", {}).get("monitors") != snap.left_monitors
    ):
        return True
    return False


def restore_state(snap, keep):
    try:
        ensure_workspace(snap.workspace)
    except RuntimeError as e:
        print("WARNING: workspace restore: " + str(e), flush=True)
    if keep:
        print(
            "MUTATED (kept): wallpaper rows, right-panel order, waifu, "
            "booru pins/tags, fastfetch image, temp chatbot session, "
            "left-panel tab",
            flush=True,
        )
        return
    try:
        for ws in (WS9, CAPTURE_WS):
            saved = snap.mapping.get(ws)
            if saved:
                run(["walleclipse", "set", snap.monitor, str(ws), saved])
    except RuntimeError as e:
        print("WARNING: wallpaper restore: " + str(e), flush=True)

    # Deactivate choreography actors first: an open left island echoes its
    # selected tab into settings, and the ChatBot widget reacts to its live
    # session vanishing — both can re-persist the demo state over the
    # restore if they fire after the writes.
    session = CHATBOT_SESSIONS / CHAT_SESSION_ID
    if session.exists():
        shutil.rmtree(session)
        # The ChatBot widget's in-memory active session now dangles; it
        # self-heals to sessions[0] on the next tab open (loadSessions).
    try:
        if ipc_call("toggleLeftPanel", snap.monitor).rstrip().endswith("open"):
            ipc_call("toggleLeftPanel", snap.monitor)
            time.sleep(IPC_SETTLE)
    except RuntimeError as e:
        print("WARNING: left panel close: " + str(e), flush=True)

    restore_settings(snap)

    # Late shell-side writers can land a full persist seconds after ours —
    # settle, re-read and heal once if anything drifted back to demo state.
    time.sleep(RESTORE_RECHECK)
    if settings_drifted(snap, json.loads(SETTINGS.read_text())):
        restore_settings(snap)
        print("State re-applied after late shell writes", flush=True)

    restore_fastfetch_pins(snap)
    print(
        "State restored: workspace, wallpapers, right-panel order, waifu, "
        "booru pins/tags, fastfetch image, temp session removed",
        flush=True,
    )


def capture_run(args):
    snap = Snapshot()
    if args.dry_run:
        dry_check(snap)
        return
    spawned = set()  # windows this run observed mapping — the only things we own
    try:
        setup_phase(snap)
        if args.setup_only:
            return  # falls through to the restore below
        ensure_workspace(CAPTURE_WS)
        time.sleep(WORKSPACE_SETTLE)
        start_recording(snap)
        time.sleep(RECORD_SETTLE)
        try:
            launcher_place_floats(snap, spawned.add)
            process_right_layouts(snap)
            process_wallpaper_switcher(
                snap, resolve_wallpaper(WALLPAPERS["columbina"]), CAPTURE_WS
            )
            ensure_workspace(WS9)
            time.sleep(WORKSPACE_SETTLE)
            process_left_tabs(snap)
            process_wallpaper_switcher(
                snap, resolve_wallpaper(WALLPAPERS["chiori"]), WS9
            )
            ensure_workspace(CAPTURE_WS)
            time.sleep(WORKSPACE_SETTLE)
        finally:
            # Recorder first: finalize the video even if teardown hiccups —
            # but never let a stuck recorder skip the window teardown.
            try:
                stop_recording(snap)
            except RuntimeError as e:
                print("WARNING: record stop: " + str(e), flush=True)
            finally:
                if spawned:
                    close_spawned(spawned)
    finally:
        restore_state(snap, args.keep)
    collect_recording(snap.recordings, OUTPUT)
    if COMPRESS_AFTER_TAKE and not args.raw:
        # The take is secured: a compression failure must not fail it.
        # In-place + the compressor's never-bigger guard.
        try:
            run(
                [
                    sys.executable,
                    Path(__file__).parent / "compress-video.py",
                    "--silent",
                    str(OUTPUT),
                ],
                timeout=900,
            )
            print(f"Compressed: {OUTPUT.stat().st_size/1e6:.1f} MB", flush=True)
        except BaseException as e:
            print(f"WARNING: compression skipped: {e}", flush=True)
    if (GIF_AFTER_TAKE or args.gif) and not args.no_gif:
        try:
            run(
                [
                    sys.executable,
                    Path(__file__).parent / "video-to-gif.py",
                    "--silent",
                    str(OUTPUT),
                ],
                timeout=900,
            )
            print(
                f"GIF: {OUTPUT.with_suffix('.gif').stat().st_size/1e6:.1f} MB",
                flush=True,
            )
        except BaseException as e:
            print("WARNING: GIF skipped: " + str(e), flush=True)


def parse_cli(argv):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="verify prerequisites only, mutate nothing",
    )
    ap.add_argument(
        "--setup-only",
        action="store_true",
        help="run setup phase then restore; no recording",
    )
    ap.add_argument(
        "--keep", action="store_true", help="restore nothing; keep demo state"
    )
    ap.add_argument(
        "--raw", action="store_true", help="skip the final mp4 compression pass"
    )
    ap.add_argument(
        "--no-gif", action="store_true", help="skip the final GIF conversion pass"
    )
    ap.add_argument(
        "--gif", action="store_true", help="also produce overview.gif alongside the mp4"
    )
    return ap.parse_args(argv)


def main(argv=None):
    args = parse_cli(argv)
    CACHE.mkdir(parents=True, exist_ok=True)
    # A SIGTERM must run the restores (finally blocks), not exit abruptly —
    # SystemExit is deliberately outside main's except tuple.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(1))
    try:
        with (CACHE / "capture-overview.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            capture_run(args)
        return 0
    except (RuntimeError, ValueError, OSError, KeyboardInterrupt) as e:
        print("ERROR: " + (str(e) or "Interrupted; capture aborted"), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
