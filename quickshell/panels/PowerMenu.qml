import QtQuick
import Quickshell
import ".."
import "../ui"

// SUPER+SHIFT+S. Replaces rofi/powermenu-hypr.sh, which was
// `rofi -theme powermenu.rasi -dmenu -selected-row 0` over five lines plus a
// case statement. The option order and every command are carried over
// verbatim from that script -- this is a re-skin, not a redesign.
//
// Not searchable: five fixed choices, so an input box would only add a
// keystroke between the bind and the action. Enter on the pre-selected first
// row is exactly what `-selected-row 0` gave.
Picker {
    id: root

    searchable: false
    cardWidth: Theme.menuNarrowW

    // execDetached, not Process: this popup is torn down by shell.qml's
    // Loader the instant the action fires, and a Process owned by a
    // destroyed component goes with it. suspend/poweroff must outlive it.
    readonly property var actions: ({
            // Guard against stacking instances if the bind is hit twice --
            // straight from the old script.
            "lock": ["sh", "-c", "pidof hyprlock || hyprlock"],
            // Muting first stops audio blaring on resume.
            "sleep": ["sh", "-c", "amixer set Master mute; systemctl suspend"],
            // Hyprland's Lua config parser has no `exit` keyword dispatcher --
            // the runtime form is a Lua expression. See hypr/hyprland.lua.
            "logout": ["hyprctl", "dispatch", "hl.dsp.exit()"],
            "restart": ["systemctl", "reboot"],
            "shutdown": ["systemctl", "poweroff"]
        })

    // Nerd-font glyphs rather than XDG icon names, like the bar modules use:
    // these five actions are fixed, so there is no icon theme to be missing
    // and nothing to load. Theme.font (MesloLGS NF) carries all five.
    items: [
        {
            label: "Lock",
            glyph: "󰌾",
            key: "lock"
        },
        {
            label: "Sleep",
            glyph: "󰒲",
            key: "sleep"
        },
        {
            label: "Logout",
            glyph: "󰍃",
            key: "logout"
        },
        {
            label: "Restart",
            glyph: "󰜉",
            key: "restart"
        },
        {
            label: "Shutdown",
            glyph: "󰐥",
            key: "shutdown"
        }
    ]

    onAccepted: item => {
        root.closeRequested();
        Quickshell.execDetached(root.actions[item.key]);
    }
}
