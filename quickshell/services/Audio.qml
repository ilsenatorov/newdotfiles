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
    readonly property string sinkName: sink ? root.nodeLabel(sink) : ""

    // Every real output device, in a stable order (Pipewire.nodes.values is
    // add-order, which shuffles as devices appear). `isStream` filters out
    // per-application playback streams -- those are sinks' *inputs*, not
    // devices, and are what pavucontrol's Playback tab shows.
    readonly property var sinks: Pipewire.nodes.values
        .filter(n => n.isSink && n.audio && !n.isStream)
        .sort((a, b) => root.nodeLabel(a).localeCompare(root.nodeLabel(b)))

    readonly property int sinkIndex: root.sinks.findIndex(n => n === root.sink)

    function nodeLabel(node: var): string {
        if (!node) return "";
        return node.description || node.nickname || node.name;
    }

    // Required for defaultAudioSink/Source's audio properties to populate --
    // undocumented gotcha in Quickshell.Services.Pipewire, this is the fix.
    PwObjectTracker {
        // The candidate sinks are tracked too, not just the active one: an
        // untracked node reports no `audio`, so it would be filtered straight
        // out of `sinks` above and never show up as something to switch to.
        objects: [root.sink, root.source].concat(Pipewire.nodes.values.filter(n => n.isSink && !n.isStream))
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

    // Writing preferredDefaultAudioSink is what `wpctl set-default` does:
    // it sets the *configured* default, so it survives the device dropping
    // out and coming back, unlike moving streams one by one.
    function setSink(node: var): void {
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }

    // For a one-keystroke "send it to the other thing" bind, no panel open.
    function cycleSink(step: int): void {
        const list = root.sinks;
        if (list.length < 2) return;
        const i = root.sinkIndex;
        root.setSink(list[((i < 0 ? 0 : i + step) % list.length + list.length) % list.length]);
    }

    function volumeGlyph(): string {
        if (muted || volume === 0) return "";
        if (volume < 0.5) return "";
        return "";
    }
}
