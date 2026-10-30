pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Global light/dark state: read `coloreclipse get` at startup, switch via
// `coloreclipse switch`, so the ControlPanel toggle and themed widgets agree.
QtObject {
    id: root

    property bool currentTheme: false   // false = dark, true = light

    // ---- get theme on startup ----
    property Component getThemeProcComp: Component {
        Process {
            id: _getProc
            command: ["coloreclipse", "get"]
            stdout: StdioCollector {
                onStreamFinished: {
                    root.currentTheme = text.includes("light")
                    _getProc.destroy()
                }
            }
        }
    }

    // ---- switch theme ----
    property Component setThemeProcComp: Component {
        Process {
            id: _setProc
            property bool targetTheme: false
            command: ["coloreclipse", "switch", _setProc.targetTheme ? "light" : "dark"]
            stdout: StdioCollector {
                onStreamFinished: {
                    root.currentTheme = _setProc.targetTheme
                    // refresh to ensure state is correct
                    const p = root.getThemeProcComp.createObject(root)
                    p.running = true
                    _setProc.destroy()
                }
            }
        }
    }

    function refresh() {
        const proc = getThemeProcComp.createObject(root)
        proc.running = true
    }

    function setTheme(light) {
        const proc = setThemeProcComp.createObject(root)
        proc.targetTheme = light
        proc.running = true
    }

    Component.onCompleted: refresh()
}