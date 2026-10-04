pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Backlight level for the OSD, driven through brightnessctl. The brightness
// keys call `qs ipc call brightness up|down` (hypr/hyprland.lua) rather than
// brightnessctl directly: sysfs sends no inotify event when the backlight
// changes, so the only way to learn the new level without polling is to be
// the one who changed it -- `-m` prints it back in the same call.
//
// `-c backlight` everywhere: without it brightnessctl falls back to the first
// LED it finds on a desktop with no panel, and "brightness up" would toggle
// Scroll Lock instead.
Singleton {
    id: root

    property bool available: false
    property real percent: 0

    // Emitted only for a change made through up()/down(), so the OSD never
    // pops for the startup probe.
    signal changed

    function up(): void { root.run("5%+"); }
    function down(): void { root.run("5%-"); }

    // A held key repeats faster than brightnessctl returns; a step that
    // lands mid-run is queued (latest wins) instead of silently dropped.
    property string pendingStep: ""

    function run(step: string): void {
        if (!root.available) return;
        if (setProc.running) {
            root.pendingStep = step;
            return;
        }
        setProc.command = ["brightnessctl", "-c", "backlight", "-m", "set", step];
        setProc.running = true;
    }

    // "intel_backlight,backlight,384,30%,1280" -> 0.3
    function parse(text: string, notify: bool): void {
        const f = text.trim().split("\n")[0]?.split(",") ?? [];
        if (f.length < 5) return;
        const cur = Number(f[2]), max = Number(f[4]);
        if (!(max > 0)) return;
        root.available = true;
        root.percent = cur / max;
        if (notify) root.changed();
    }

    Process {
        id: probe
        running: true
        command: ["brightnessctl", "-c", "backlight", "-m", "info"]
        stdout: StdioCollector { onStreamFinished: root.parse(text, false) }
    }

    Process {
        id: setProc
        stdout: StdioCollector { onStreamFinished: root.parse(text, true) }
        onExited: {
            const step = root.pendingStep;
            root.pendingStep = "";
            if (step !== "") root.run(step);
        }
    }

    IpcHandler {
        target: "brightness"

        function up(): void { root.up(); }
        function down(): void { root.down(); }
        function get(): string { return root.available ? String(Math.round(root.percent * 100)) : "none"; }
    }
}
