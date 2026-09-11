pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Claude subscription limit utilisation, via scripts/claude-usage.sh.
//
// The OAuth token Claude Code stores expires every few hours and only Claude Code
// itself can refresh it. So a failure here is normal and expected, not an error:
// keep the last good numbers and let the UI dim them via `stale`.
Singleton {
    id: root

    property real fiveHour: -1   // percent, -1 = never fetched
    property real sevenDay: -1
    property bool stale: false

    readonly property bool valid: fiveHour >= 0

    readonly property string text: valid
        ? "5H " + Math.round(fiveHour) + "%  ·  7D " + Math.round(sevenDay) + "%"
        : "--"

    Process {
        id: proc
        command: [Qt.resolvedUrl("scripts/claude-usage.sh").toString().replace("file://", "")]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (d.five_hour === undefined) { root.stale = true; return; }
                    root.fiveHour = d.five_hour.utilization;
                    root.sevenDay = d.seven_day ? d.seven_day.utilization : 0;
                    root.stale = false;
                } catch (e) {
                    root.stale = true;
                }
            }
        }
    }

    // local.conf's SVC_CLAUDE_USAGE=0 stops this timer outright.
    Timer {
        running: Local.svcClaudeUsage
        repeat: true
        triggeredOnStart: true
        interval: 300000 // 5 min
        onTriggered: proc.running = true
    }
}
