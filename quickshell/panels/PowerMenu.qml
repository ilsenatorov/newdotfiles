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

    items: [
        {
            label: "Lock",
            key: "lock"
        },
        {
            label: "Sleep",
            key: "sleep"
        },
        {
            label: "Logout",
            key: "logout"
        },
        {
            label: "Restart",
            key: "restart"
        },
        {
            label: "Shutdown",
            key: "shutdown"
        }
    ]

    onAccepted: item => {
        root.closeRequested();
        Quickshell.execDetached(root.actions[item.key]);
    }
}
