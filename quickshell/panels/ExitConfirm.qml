import QtQuick
import Quickshell
import ".."
import "../ui"

// SUPER+SHIFT+E. Replaces hypr/scripts/exit-confirm.sh, which piped two
// lines into `rofi -dmenu -selected-row 0` purely to ask "are you sure".
// The script had nothing else in it, so it is deleted rather than ported --
// this component is the whole thing.
//
// Cancel is first, and first is pre-selected, so a stray Enter after the
// bind does NOT end the session. That ordering is load-bearing.
Picker {
    id: root

    searchable: false
    cardWidth: Theme.menuNarrowW

    items: [
        {
            label: "Cancel",
            key: "cancel"
        },
        {
            label: "Exit Hyprland",
            key: "exit"
        }
    ]

    onAccepted: item => {
        root.closeRequested();
        // Lua expression, not the classic `hyprctl dispatch exit` keyword --
        // see hypr/hyprland.lua's Lua config parser.
        if (item.key === "exit")
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"]);
    }
}
