pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether the homeserver has everything this machine has, from
// `sync-setup.sh --status`: synced | syncing N | offline | off (no Syncthing).
// Always shown in the bar where Syncthing runs: green 0 means safe to turn off.
Singleton {
    id: root

    property string state: "off"

    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/dotfiles/sync-setup.sh", "--status"]
        stdout: StdioCollector {
            onStreamFinished: root.state = text.trim() || "off"
        }
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 10000
        onTriggered: if (!proc.running) proc.running = true
    }
}
