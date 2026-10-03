pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Screen recording through wf-recorder -- the video sibling of
// hypr/scripts/screenshot.sh. A singleton so the recording Process outlives
// whatever menu started it (shell.qml tears menus down on close).
//
// Stopping sends SIGINT, which is how wf-recorder wants to be told to finish:
// it flushes the encoder and writes the mp4 index. A SIGTERM'd recording is
// often unplayable.
Singleton {
    id: root

    readonly property bool recording: proc.running && root.started
    // Whether the next recording also captures what's playing (the default
    // sink's monitor). Off by default: most screen captures are UI demos.
    property bool withAudio: false

    property bool started: false
    property real startedAt: 0
    property int elapsed: 0
    property string file: ""
    property string lastFile: ""

    readonly property string dir: Quickshell.env("HOME") + "/Videos/Recordings"

    function stamp(): string {
        const d = new Date();
        const p = n => String(n).padStart(2, "0");
        return d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) + "-" + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds());
    }

    // mode: "region" (slurp a rectangle) | "screen" (the focused monitor)
    function start(mode: string): void {
        if (proc.running) return;
        root.file = root.dir + "/recording-" + root.stamp() + ".mp4";
        const audio = root.withAudio && Audio.sink ? "--audio=" + Audio.sink.name + ".monitor" : "";
        const output = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        // slurp runs first and its cancel (Esc) exits 130 -- reported as
        // nothing at all. `exec` makes wf-recorder *be* this process, so the
        // SIGINT from stop() reaches it rather than the shell.
        const script = 'command -v wf-recorder >/dev/null || exit 127; mkdir -p "$(dirname "$1")"; '
            + 'if [ "$2" = region ]; then g=$(slurp) || exit 130; set -- "$1" "$2" "$3" "$4" -g "$g"; '
            + 'elif [ -n "$4" ]; then set -- "$1" "$2" "$3" "$4" -o "$4"; fi; '
            + 'f=$1; a=$3; shift 4; exec wf-recorder ${a:+"$a"} "$@" -f "$f"';
        proc.command = ["sh", "-c", script, "rec", root.file, mode, audio, output];
        root.started = false;
        proc.running = true;
    }

    // For callers that are about to close a menu: the timer lives here, so it
    // survives the caller being destroyed.
    function startDelayed(mode: string, ms: int): void {
        delay.mode = mode;
        delay.interval = Math.max(1, ms);
        delay.restart();
    }

    Timer {
        id: delay
        property string mode: "region"
        onTriggered: root.start(mode)
    }

    function stop(): void {
        if (proc.running) proc.signal(2);
    }

    function toggle(mode: string): void {
        if (proc.running) root.stop();
        else root.start(mode);
    }

    Process {
        id: proc

        // wf-recorder logs to stderr once it is actually capturing; until
        // then we may still be in slurp, which shouldn't show the red dot.
        stderr: SplitParser {
            onRead: line => {
                if (!root.started) {
                    root.started = true;
                    root.startedAt = Date.now();
                    root.elapsed = 0;
                }
            }
        }

        onExited: exitCode => {
            const wasStarted = root.started;
            root.started = false;
            if (exitCode === 127) {
                Quickshell.execDetached(["notify-send", "Recorder: wf-recorder not installed", "pacman -S wf-recorder"]);
            } else if (exitCode === 130 && !wasStarted) {
                // region pick cancelled
            } else if (wasStarted) {
                root.lastFile = root.file;
                Quickshell.execDetached(["notify-send", "-i", "video-x-generic", "Recording saved", root.file]);
            } else {
                Quickshell.execDetached(["notify-send", "-u", "critical", "Recording failed", "wf-recorder exited with " + exitCode]);
            }
        }
    }

    Timer {
        running: root.recording
        repeat: true
        interval: 1000
        onTriggered: root.elapsed = Math.floor((Date.now() - root.startedAt) / 1000)
    }

    function elapsedText(): string {
        const s = root.elapsed;
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // qs ipc call recorder toggle region|screen | stop | status
    IpcHandler {
        target: "recorder"

        function toggle(mode: string): void { root.toggle(mode === "screen" ? "screen" : "region"); }
        function stop(): void { root.stop(); }
        function status(): string { return root.recording ? "recording\t" + root.elapsedText() + "\t" + root.file : "idle"; }
    }
}
