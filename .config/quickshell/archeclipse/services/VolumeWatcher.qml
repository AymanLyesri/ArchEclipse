pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire

// Shared default-sink tracking: used by the volume widget and by BarState's
// volume-pulse watcher so only one PwObjectTracker exists.
QtObject {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    property PwObjectTracker tracker: PwObjectTracker { objects: [root.sink] }

    readonly property real volume: {
        if (!sink?.audio) return 0;
        const v = sink.audio.volume;
        return isNaN(v) || v < 0 ? 0 : (v > 1 ? 1 : v);
    }
}
