pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Which player the shell speaks for. Pausing must not hand the UI to an idle player, so the
// one that last actually played keeps the spotlight until another starts.
Singleton {
    id: root

    // Explicit chip pin, stored by object: the playing-first order reshuffles indexes.
    property var pinned: null
    property var lastPlaying: null

    // Presentable players, playing first; the last played one leads its group so a pause
    // cannot visibly reorder the switcher.
    readonly property var players: {
        Mpris.players.values;
        const playing = [];
        const paused = [];
        for (const p of Mpris.players.values) {
            if (!p || !root.usable(p))
                continue;
            (p.isPlaying === true ? playing : paused).push(p);
        }
        root._hoist(playing);
        root._hoist(paused);
        return playing.concat(paused);
    }

    readonly property var current: {
        const list = root.players;
        if (list.length === 0)
            return null;
        const pin = root.pinned;
        if (pin !== null && list.indexOf(pin) !== -1)
            return pin;
        const last = root.lastPlaying;
        if (last !== null && list.indexOf(last) !== -1 && last.isPlaying === true)
            return last;
        for (const p of list) {
            if (p.isPlaying === true)
                return p;
        }
        if (last !== null && list.indexOf(last) !== -1)
            return last;
        return list[0];
    }

    // Deferred: writing a dependency of `players` from inside its own update is a loop.
    onCurrentChanged: Qt.callLater(root._remember)
    onPlayersChanged: Qt.callLater(root._forgetDeadPin)

    function togglePin(p) {
        root.pinned = root.pinned === p ? null : p;
    }

    function usable(p) {
        // Touch the reactive props so title and state changes re-run the binding.
        const title = String(p.trackTitle ?? "").trim();
        const identity = String(p.identity ?? "").trim();
        p.isPlaying;
        return title !== "" || identity !== "";
    }

    function _hoist(list) {
        const last = root.lastPlaying;
        const i = last === null ? -1 : list.indexOf(last);
        if (i > 0)
            list.unshift(list.splice(i, 1)[0]);
    }

    function _remember() {
        const p = root.current;
        if (p !== null && p.isPlaying === true && root.lastPlaying !== p)
            root.lastPlaying = p;
    }

    function _forgetDeadPin() {
        if (root.pinned !== null && root.players.indexOf(root.pinned) === -1)
            root.pinned = null;
    }
}
