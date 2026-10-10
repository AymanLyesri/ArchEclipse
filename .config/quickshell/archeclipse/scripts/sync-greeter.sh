#!/usr/bin/env bash
# Mirror greeter config to the world-readable XDG path. Redacts secrets.
#
# Source (~/.config/quickshell/archeclipse-greeter/) contains SYMLINKS
# (theme, services, widgets/{greeter,lock,shared} -> ../archeclipse/...).
# rsync MUST dereference them (-L/--copy-links): $HOME is mode-700 so a
# preserved symlink would dangle for the greeter user. The old flat
# `cp AuthCard.qml` step is superseded by the dereferenced widgets/lock/
# tree (which also carries its qmldir, needed for `qs.widgets.lock`).
#
# Secret redaction: the only secret-shaped keys in the archeclipse
# Settings/config are under the top-level `apiKeys` object
# (theme/Settings.qml defaultApiKeys()/mergeApiKeys(): per-API user/key
# credential values for openrouter/danbooru/gelbooru/safebooru/wallhaven,
# merged with the user's saved values from settings.json). No
# *apiKey*/*secret* files exist in the source tree today (verified
# 2026-10-10); the --exclude patterns below are preventive (written with
# per-letter case classes because rsync matches case-sensitively) so a
# secret file can never leak into the world-readable mirror. settings.json /
# settings-*.json are excluded for the same reason. Supabase keys are NOT
# in Settings (read from env at runtime) — nothing to redact there.
set -u

SRC="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/archeclipse-greeter"
DST="${GREETER_DST:-/etc/xdg/quickshell/archeclipse-greeter}"
SESSION_DIR="/usr/share/wayland-sessions"
SUDO="${SYNC_GREETER_SUDO-sudo}"

# NOTE: plain `#` comments cannot go inside the backslash-continued rsync
# below (they would comment out the continuation), so the --exclude lines
# carry their rationale here: *apiKey*/*secret*/*token*/*credential* and
# settings*.json are secret-shaped names that must never leak into the
# world-readable mirror; /greeter-wallpaper is panel-installed user data
# (pkexec cp, see commandFor "greeter") that --delete must never remove.
$SUDO mkdir -p "$DST"
$SUDO rsync -aL --delete --chmod=Du+rX,go+rX,Fu+r,go+r \
    --exclude='*[Aa][Pp][Ii][Kk]ey*' --exclude='*[Ss][Ee][Cc][Rr][Ee][Tt]*' \
    --exclude='*[Tt][Oo][Kk][Ee][Nn]*' --exclude='*[Cc][Rr][Ee][Dd][Ee][Nn][Tt][Ii][Aa][Ll]*' \
    --exclude='settings.json' --exclude='settings-*.json' \
    --exclude='/greeter-wallpaper' \
    "$SRC/" "$DST/"
$SUDO chmod -R a+rX "$DST"

# sessions.json from live wayland-sessions .desktop files (real Exec=
# parsing per the desktop-entry spec: shell-like quoting, escapes, and %
# field codes dropped). Overwrites the stub rsync just copied ONLY when
# parsing yields at least one session; otherwise the checked-in stub
# (offline fallback) stays in place.
if [ -d "$SESSION_DIR" ]; then
    SESSIONS="$(python3 - "$SESSION_DIR" <<'EOF'
import configparser, json, os, shlex, sys
d = sys.argv[1]
out = []
for f in sorted(os.listdir(d)):
    if not f.endswith('.desktop'):
        continue
    p = configparser.ConfigParser(interpolation=None)
    p.optionxform = str
    try:
        with open(os.path.join(d, f), encoding='utf-8') as fh:
            p.read_file(fh, source=f)
        entry = p['Desktop Entry']
        name = entry.get('Name', '')
        raw_exec = entry.get('Exec', '')
        try:
            argv = shlex.split(raw_exec, posix=True)
        except ValueError:
            argv = raw_exec.split()
        argv = [a for a in argv if not (len(a) == 2 and a.startswith('%'))]
        if not name or not argv:
            continue
        out.append({'key': f[:-8], 'name': name, 'exec': argv})
    except (KeyError, OSError, configparser.Error):
        continue
print(json.dumps(out))
EOF
)"
    if [ "$SESSIONS" != "[]" ] && [ -n "$SESSIONS" ]; then
        printf '%s' "$SESSIONS" | $SUDO tee "$DST/sessions.json" >/dev/null
    fi
fi

# keyboard-input.lua: keymap for the greeter Hyprland, from SYSTEM-WIDE
# config only — first live source wins: systemd's 00-keyboard.conf, then
# /etc/vconsole.conf XKB* vars, then legacy /etc/default/keyboard, then a
# KEYMAP→xkb best-effort map, then plain us. The greeter runs pre-login as
# another user: it must never depend on any one user's private config (same
# contract as noctalia, SDDM, GDM — one system layout at login, per-user
# layouts apply after). To change the login layout:
# localectl set-x11-keymap — then reload the bar to re-sync.
# Emitted as Lua (hyprland.lua dofiles it); only non-empty values included.
KBD_LUA="$(python3 <<'EOF'
import re

vals = {}
# Console KEYMAP names are not xkb names: map the known ones, strip
# -latin suffixes, pass through bare two-letter codes, ignore the rest
# (a wrong layout silently mistypes passwords — worse than no map).
KEYMAP_FALLBACK = {
    'dvorak': ('us', 'dvorak'),
    'dvorak-r': ('us', 'dvorak'),
    'dvorak-l': ('us', 'dvorak'),
    'colemak': ('us', 'colemak'),
}

def pull(pattern, text, group=2):
    for m in re.finditer(pattern, text, re.MULTILINE):
        vals.setdefault(m.group(1).lower(), m.group(2))

def read(path):
    try:
        with open(path, encoding='utf-8') as fh:
            return fh.read()
    except OSError:
        return ''

pull(r'''^XKB(LAYOUT|VARIANT|MODEL|OPTIONS)\s*=\s*["']?([^"'\n]*)["']?''',
     read('/etc/X11/xorg.conf.d/00-keyboard.conf'))
vcon = read('/etc/vconsole.conf')
pull(r'''^XKB(LAYOUT|VARIANT|MODEL)\s*=\s*["']?([^"'\n]*)["']?''', vcon)
pull(r'''^XKB(LAYOUT|VARIANT|MODEL|OPTIONS)\s*=\s*["']?([^"'\n]*)["']?''',
     read('/etc/default/keyboard'))
m = re.search(r'''^KEYMAP\s*=\s*["']?([^"'\n]*)["']?''', vcon, re.MULTILINE)
if m and not vals.get('layout'):
    km = m.group(1).strip()
    if km in KEYMAP_FALLBACK:
        vals.setdefault('layout', KEYMAP_FALLBACK[km][0])
        vals.setdefault('variant', KEYMAP_FALLBACK[km][1])
    elif re.fullmatch(r'[a-z]{2}(-latin[19])?', km):
        vals.setdefault('layout', km[:2])
vals.setdefault('layout', 'us')
lines = ['-- Generated by sync-greeter.sh - do not edit.', 'hl.config({', '    input = {']
for k in ('layout', 'variant', 'model', 'options'):
    if vals.get(k):
        lines.append(f'        kb_{k} = "{vals[k]}",')
lines.append('    },')
lines.append('})')
print('\n'.join(lines))
EOF
)"
printf '%s\n' "$KBD_LUA" | $SUDO tee "$DST/keyboard-input.lua" >/dev/null

echo "greeter synced -> $DST"
