pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Launch counts for the SUPER+D launcher, so the list opens on what you
// actually run instead of whatever sorts first alphabetically. rofi had this
// built in (its drun history file); this is the replacement for it.
//
// State lives outside the repo, in ~/.local/state/quickshell-launcher/, for
// the same reason AskService's conversations do: ~/.config is symlinked INTO
// the repo, so anything written there would sync to every machine. Launch
// counts are per-machine by nature.
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.local/state/quickshell-launcher/usage.json"

    // { "<desktop id>": { count: <int>, last: <epoch ms> } }. DesktopEntry.id
    // is constant, so it survives the app being renamed or re-themed.
    property var entries: ({})

    function countFor(id: string): int {
        const e = root.entries[id];
        return e ? (e.count ?? 0) : 0;
    }

    function lastFor(id: string): real {
        const e = root.entries[id];
        return e ? (e.last ?? 0) : 0;
    }

    function record(id: string): void {
        if (!id)
            return;
        // Rebuild the map rather than mutating in place: QML only re-evaluates
        // bindings on `entries` when the property itself is reassigned, and
        // the launcher's sort is one of those bindings.
        const next = Object.assign({}, root.entries);
        next[id] = {
            count: root.countFor(id) + 1,
            last: Date.now()
        };
        root.entries = next;

        // Whole-file rewrite through sh, the same way AskService appends its
        // history -- FileView here is read-only and watching.
        writer.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")" && printf "%s" "$1" > "$2"', "write", JSON.stringify(next), root.path];
        writer.running = true;
    }

    Process {
        id: writer
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        // Absent until the first launch is recorded; that is not an error.
        printErrors: false

        onLoaded: root.parse()
        onFileChanged: reload()
        onTextChanged: root.parse()
    }

    function parse(): void {
        try {
            const text = file.text();
            root.entries = text ? JSON.parse(text) : ({});
        } catch (e) {
            // A truncated or hand-mangled file just means no history yet --
            // the next launch rewrites it whole.
            root.entries = ({});
        }
    }

    Component.onCompleted: root.parse()
}
