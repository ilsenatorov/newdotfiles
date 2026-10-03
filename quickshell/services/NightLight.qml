pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// On/off + colour temperature for hyprsunset, which hypr/hyprland.lua starts
// at 3000K. This talks to hyprsunset's own IPC (`hyprctl hyprsunset ...`) --
// a plain request, not a dispatch string, so the Lua config's dispatch quirk
// doesn't apply. The last setting is kept in ~/.local/state and reapplied
// whenever the shell starts, so a reboot lands on what you picked rather than
// the autostart's 3000K.
//
// `available` is false when hyprsunset isn't answering (the wlsunset fallback
// in the autostart has no IPC); the Quick page hides the controls then.
Singleton {
    id: root

    readonly property int minK: 2500
    readonly property int maxK: 6500

    property bool available: false
    property bool enabled: true
    property int temperature: 3000

    readonly property string path: Quickshell.env("HOME") + "/.local/state/quickshell-nightlight/state.json"
    property bool loaded: false

    function setEnabled(on: bool): void {
        root.enabled = on;
        applyTimer.restart();
    }
    function toggle(): void { root.setEnabled(!root.enabled); }

    function setTemperature(k: int): void {
        root.temperature = Math.max(root.minK, Math.min(root.maxK, Math.round(k / 50) * 50));
        root.enabled = true;
        applyTimer.restart();
    }
    function nudge(dk: int): void { root.setTemperature(root.temperature + dk); }

    // Debounced so dragging the slider sends a handful of requests, not one
    // per pixel; also the single place state is written back to disk.
    Timer {
        id: applyTimer
        interval: 120
        onTriggered: {
            Quickshell.execDetached(root.enabled
                ? ["hyprctl", "hyprsunset", "temperature", String(root.temperature)]
                : ["hyprctl", "hyprsunset", "identity"]);
            writer.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")" && printf "%s" "$1" > "$2"', "write",
                JSON.stringify({ enabled: root.enabled, temperature: root.temperature }), root.path];
            writer.running = true;
        }
    }

    Process { id: writer }

    // Is hyprsunset there to talk to? It prints the current temperature.
    Process {
        id: probe
        running: true
        command: ["hyprctl", "hyprsunset", "temperature"]
        stdout: StdioCollector {
            onStreamFinished: {
                const k = parseInt(text.trim());
                root.available = !isNaN(k) && k > 0;
                root.restore();
            }
        }
    }

    FileView {
        id: file
        path: root.path
        printErrors: false
        blockLoading: true
    }

    function restore(): void {
        if (root.loaded) return;
        root.loaded = true;
        try {
            const t = file.text();
            if (!t) return;
            const d = JSON.parse(t);
            root.enabled = d.enabled !== false;
            if (d.temperature > 0) root.temperature = d.temperature;
            if (root.available) applyTimer.restart();
        } catch (e) {}
    }

    // qs ipc call nightlight toggle | set <kelvin> | get
    IpcHandler {
        target: "nightlight"

        function toggle(): void { root.toggle(); }
        function set(kelvin: int): void { root.setTemperature(kelvin); }
        function get(): string { return root.enabled ? String(root.temperature) : "off"; }
    }
}
