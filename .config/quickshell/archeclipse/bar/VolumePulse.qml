import QtQuick
import Quickshell.Services.Pipewire
import qs.theme
import "."

// Transient volume pulse page — the bar shows this for ~2s on any external
// volume change (fn keys, pavucontrol), mirroring Bar.tsx watchTransient.
Volume {
    pulse: true
}
