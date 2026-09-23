import QtQuick
import Quickshell
import ".."
import Quickshell.Io
import "../ui"

// SUPER+V. Replaces rofi/clipboard.sh, which was
// `cliphist list | rofi -dmenu -i -p Clipboard | cliphist decode | wl-copy`.
//
// The pipeline is unchanged -- cliphist is still the store, and the selected
// line still goes back through `cliphist decode`. Only the middle stage
// (rofi) is now this card.
Picker {
    id: root

    placeholder: "Clipboard"
    cardWidth: Theme.menuW
    items: []
    // cliphist is optional (the old script checked `command -v` and
    // notify-send'd). An empty list here IS that message.
    emptyText: "No clipboard history -- is cliphist installed?"

    Process {
        running: true
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                // Each line is "<id>\t<preview>". `cliphist decode` wants the
                // id, which it reads off the front of the line, so the whole
                // line is kept as the key and only the display is trimmed.
                root.items = text.split("\n").filter(l => l.trim() !== "").map(l => ({
                            label: l.replace(/^\s*\d+\s*\t/, ""),
                            key: l
                        }));
            }
        }
    }

    onAccepted: item => {
        root.closeRequested();
        // Passed as an argv entry, not spliced into the shell string: a
        // clipboard entry is arbitrary text and will contain quotes.
        Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | cliphist decode | wl-copy', "sh", item.key]);
    }
}
