pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether the homeserver has everything this machine has, from
// `sync-setup.sh --status`: synced | syncing N | paused | offline | off (no Syncthing).
// Always shown in the bar where Syncthing runs: green 0 means safe to turn off.
Singleton {
    id: root

    property string state: "off"
    // Per folder, from --info: { id, state, downItems, downBytes, upItems, upBytes }.
    property var folders: []
    // Panel open: poll faster, and also fetch the folder breakdown.
    property bool detailed: false

    readonly property bool paused: state === "paused"
    readonly property real upBytes: folders.reduce((a, f) => a + f.upBytes, 0)
    readonly property real downBytes: folders.reduce((a, f) => a + f.downBytes, 0)
    // The folder with the most bytes still moving, or null when nothing is.
    readonly property var busiest: folders.reduce((best, f) => {
        const b = f.upBytes + f.downBytes;
        return b > 0 && (!best || b > best.upBytes + best.downBytes) ? f : best;
    }, null)

    function toggle(): void {
        act.command = [script, paused ? "--resume" : "--pause"];
        act.running = true;
    }

    function fmtBytes(b: real): string {
        if (b < 1024) return Math.round(b) + " B";
        const u = ["KB", "MB", "GB", "TB"];
        let i = -1;
        do { b /= 1024; i++; } while (b >= 1024 && i < u.length - 1);
        return b.toFixed(b < 10 ? 1 : 0) + " " + u[i];
    }

    readonly property string script: Quickshell.env("HOME") + "/dotfiles/sync-setup.sh"

    Process {
        id: act
        onRunningChanged: if (!running) { proc.running = true; info.running = true; }
    }

    Process {
        id: info
        command: [root.script, "--info"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.folders = JSON.parse(text); } catch (e) { root.folders = []; }
            }
        }
    }

    Process {
        id: proc
        command: [root.script, "--status"]
        stdout: StdioCollector {
            onStreamFinished: root.state = text.trim() || "off"
        }
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: root.detailed ? 3000 : 10000
        onTriggered: {
            if (!proc.running) proc.running = true;
            if (root.detailed && !info.running) info.running = true;
        }
    }
}
