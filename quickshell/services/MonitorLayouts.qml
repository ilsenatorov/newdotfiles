pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Applying a layout must survive the monitor panel being closed or moved.
Singleton {
    id: root

    readonly property bool busy: process.running
    property string error: ""
    property string status: ""
    signal applied

    function run(command: var, message: string): void {
        if (root.busy) return;
        root.error = "";
        root.status = "";
        process.message = message;
        process.command = command;
        process.running = true;
    }

    Process {
        id: process
        property string message: ""
        stderr: StdioCollector { id: errors; waitForEnd: true }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.error = errors.text.trim() || "Display operation failed.";
                return;
            }
            root.status = message;
            root.applied();
        }
    }
}
