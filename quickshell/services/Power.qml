pragma Singleton

import QtQuick
import Quickshell

// Session/power commands, shared by the power menu (SUPER+D, p)
// (panels/PowerMenu.qml) and the SUPER+D search. The commands are carried over
// verbatim from the old rofi/powermenu-hypr.sh.
//
// execDetached, not Process: the menu that triggers these is torn down the
// instant the action fires, and a Process owned by a destroyed component goes
// with it. suspend/poweroff must outlive it.
Singleton {
    id: root

    // Nerd-font glyphs rather than XDG icon names, like the bar modules use.
    // `destructive` ends the session -- the search asks twice for those.
    readonly property var items: [
        { key: "lock", label: "Lock", glyph: "󰌾", destructive: false },
        { key: "sleep", label: "Sleep", glyph: "󰒲", destructive: false },
        { key: "logout", label: "Logout", glyph: "󰍃", destructive: true },
        { key: "restart", label: "Restart", glyph: "󰜉", destructive: true },
        { key: "shutdown", label: "Shutdown", glyph: "󰐥", destructive: true }
    ]

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

    function run(key: string): void {
        const cmd = root.actions[key];
        if (cmd) Quickshell.execDetached(cmd);
    }
}
