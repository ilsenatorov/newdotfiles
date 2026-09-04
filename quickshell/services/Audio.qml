pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Thin summary over Quickshell.Services.Pipewire for the bar module and the
// Audio panel. Replaces pavucontrol's default-sink readout and waybar's
// pulseaudio module -- volume/mute are live bindings, no `pactl` polling.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // PwNodeAudioIface isn't bound until it's tracked -- see PwObjectTracker
    // below. volume/muted read 0/false before that, which is a safe default.
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property string sinkName: sink ? (sink.description || sink.name) : ""

    // Required for defaultAudioSink/Source's audio properties to populate --
    // undocumented gotcha in Quickshell.Services.Pipewire, this is the fix.
    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    function setVolume(v: real): void {
        if (sink && sink.audio) sink.audio.volume = Math.max(0, Math.min(1.5, v));
    }

    function nudgeVolume(delta: real): void {
        setVolume(volume + delta);
    }

    function toggleMute(): void {
        if (sink && sink.audio) sink.audio.muted = !sink.audio.muted;
    }

    function volumeGlyph(): string {
        if (muted || volume === 0) return "";
        if (volume < 0.5) return "";
        return "";
    }
}
