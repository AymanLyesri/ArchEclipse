pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Port of AGS globalTheme (variables.ts):
//   - reads current theme from `system-theme.sh get` on startup
//   - setGlobalTheme(light|dark) runs `system-theme.sh switch` then updates state
// This drives the ControlPanel Theme toggle and any themed widgets.
QtObject {
    id: root

    property bool currentTheme: false   // false = dark, true = light

    // ---- get theme on startup ----
    property Component getThemeProcComp: Component {
        Process {
            id: _getProc
            command: ["bash", "-c", "$HOME/.config/hypr/theme/scripts/system-theme.sh get"]
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
            command: ["bash", "-c", `$HOME/.config/hypr/theme/scripts/system-theme.sh switch ${targetTheme ? "light" : "dark"}`]
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