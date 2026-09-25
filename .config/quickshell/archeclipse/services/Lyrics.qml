pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lyrics service — LRCLIB lookup for the active MPRIS track.
// Contract (verified 2026-09-25 via curl):
//   GET https://lrclib.net/api/get?artist_name=&track_name=&album_name=&duration=
//   200 -> {syncedLyrics, plainLyrics, instrumental}; 404 -> no match.
// MediaWidget feeds track identity via fetchFor() and position via
// positionSec; consumers read status/lines/plainText/currentIndex.
QtObject {
    id: root

    // idle|loading|no-track|ready-synced|ready-plain|instrumental|not-found|error
    property string status: "idle"
    property var lines: []          // [{t: seconds, text}] sorted, synced only
    property string plainText: ""
    property real positionSec: 0
    readonly property int currentIndex: root._indexOf(root.lines, root.positionSec)
    property string activeKey: ""

    // Last-N track cache so toggling tracks doesn't refetch.
    property var _cache: ({})
    property var _order: []
    property string _pendingKey: ""

    function _norm(x) {
        return String(x || "").trim().toLowerCase();
    }
    function trackKey(artist, title, album) {
        return root._norm(artist) + "|" + root._norm(title) + "|" + root._norm(album);
    }

    function buildUrl(artist, track, album, durationSec) {
        const a = String(artist || "").trim();
        const t = String(track || "").trim();
        if (a === "" || t === "")
            return "";
        let u = "https://lrclib.net/api/get?artist_name=" + encodeURIComponent(a)
            + "&track_name=" + encodeURIComponent(t);
        const al = String(album || "").trim();
        if (al !== "")
            u += "&album_name=" + encodeURIComponent(al);
        const d = Math.round(Number(durationSec) || 0);
        if (d > 0)
            u += "&duration=" + d;
        return u;
    }

    // Parse LRC: [mm:ss.xx] stamps (multi-stamp per line allowed),
    // metadata tags ([ar:], [al:], ...) and stamp-less lines skipped,
    // blank bodies skipped (they'd steal the highlight), sorted by time.
    function parseLrc(text) {
        const out = [];
        const src = String(text || "").replace(/\r/g, "").split("\n");
        for (let i = 0; i < src.length; i++) {
            const line = src[i];
            const stamps = line.match(/\[(\d{1,3}):(\d{2}(?:\.\d{1,3})?)\]/g);
            if (!stamps)
                continue;
            const body = line.replace(/\[.*?\]/g, "").trim();
            if (body === "")
                continue;
            for (let s = 0; s < stamps.length; s++) {
                const m = stamps[s].match(/\[(\d{1,3}):(\d{2}(?:\.\d{1,3})?)\]/);
                if (!m)
                    continue;
                const t = parseInt(m[1], 10) * 60 + parseFloat(m[2]);
                if (isFinite(t))
                    out.push({ t: t, text: body });
            }
        }
        out.sort(function (x, y) { return x.t - y.t; });
        return out;
    }

    function _indexOf(lines, posSec) {
        const p = Number(posSec);
        if (!isFinite(p))
            return -1;
        let idx = -1;
        const arr = lines || [];
        for (let i = 0; i < arr.length; i++) {
            if (Number(arr[i].t) <= p + 0.0001)
                idx = i;
            else
                break;
        }
        return idx;
    }

    function _store(key, state) {
        root._cache[key] = state;
        root._order.push(key);
        while (root._order.length > 20) {
            const old = root._order.shift();
            if (old !== key)
                delete root._cache[old];
        }
    }

    function _apply(state) {
        root.status = state.status;
        root.lines = state.lines || [];
        root.plainText = state.plainText || "";
    }

    function fetchFor(artist, title, album, durationSec) {
        const key = root.trackKey(artist, title, album);
        if (key === root.activeKey && root.status !== "idle")
            return;
        root.activeKey = key;
        if (String(artist || "").trim() === "" || String(title || "").trim() === "") {
            root._apply({ status: "no-track", lines: [], plainText: "" });
            return;
        }
        const hit = root._cache[key];
        if (hit) {
            root._apply(hit);
            return;
        }
        const url = root.buildUrl(artist, title, album, durationSec);
        if (url === "") {
            root._apply({ status: "no-track", lines: [], plainText: "" });
            return;
        }
        root.status = "loading";
        root.lines = [];
        root.plainText = "";
        root._pendingKey = key;
        fetchProc.command = ["curl", "-fsSL", "--retry", "2", "--retry-all-errors",
            "--connect-timeout", "8", "--max-time", "15", url];
        fetchProc.running = true;
    }

    function _onResponse(raw) {
        // Stale guard: a newer track raced ahead while curl was in flight.
        if (root._pendingKey !== root.activeKey)
            return;
        const key = root.activeKey;
        const payload = String(raw || "").trim();
        if (payload === "") {
            // curl -f on 404 yields no stdout -> no match.
            const s = { status: "not-found", lines: [], plainText: "" };
            root._store(key, s);
            root._apply(s);
            return;
        }
        let d = null;
        try {
            d = JSON.parse(payload);
        } catch (e) {
            root._apply({ status: "error", lines: [], plainText: "" });
            return;
        }
        if (d && d.instrumental) {
            const s = { status: "instrumental", lines: [], plainText: "" };
            root._store(key, s);
            root._apply(s);
            return;
        }
        const parsed = root.parseLrc(d && d.syncedLyrics ? String(d.syncedLyrics) : "");
        if (parsed.length > 0) {
            const s = { status: "ready-synced", lines: parsed, plainText: "" };
            root._store(key, s);
            root._apply(s);
            return;
        }
        const plain = d && d.plainLyrics ? String(d.plainLyrics).trim() : "";
        if (plain !== "") {
            const s = { status: "ready-plain", lines: [], plainText: plain };
            root._store(key, s);
            root._apply(s);
            return;
        }
        const s = { status: "not-found", lines: [], plainText: "" };
        root._store(key, s);
        root._apply(s);
    }

    property Process fetchProc: Process {
        command: ["curl", "-fsSL", "--connect-timeout", "8", "--max-time", "15", ""]
        stdout: StdioCollector {
            onStreamFinished: root._onResponse(text)
        }
    }
}
