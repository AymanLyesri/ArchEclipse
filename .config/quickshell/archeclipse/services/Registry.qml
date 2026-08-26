pragma Singleton
import QtQuick

// Name -> window registry so `qs ipc` binds can toggle windows by AGS-style
// names (user-panel-<mon>, left-panel-<mon>, wallpaper-switcher-<mon>, …).
QtObject {
    property var windows: ({})
    function register(name, win) { const n = Object.assign({}, windows); n[name] = win; windows = n; }
    function unregister(name) { const n = Object.assign({}, windows); delete n[name]; windows = n; }
}
