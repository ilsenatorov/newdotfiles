pragma Singleton

import QtQuick
import Quickshell

// Session/power commands, shared by the power menu (SUPER+T, p)
// (panels/PowerMenu.qml) and the SUPER+T search. The commands are carried over
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

    // Leaving a machine off only works if the homeserver already has its last
    // edits, so wait for Syncthing first. Not synced after 2 min (or the hub is
    // unreachable): ask. Left-click (the "default" action) goes ahead anyway,
    // dismissing cancels. No Syncthing on this machine: --wait passes at once.
    function synced(verb: string, cmd: string): var {
        return ["sh", "-c",
            's="$HOME/dotfiles/sync-setup.sh"\n' +
            '"$s" --status >/dev/null || notify-send -t 4000 "Finishing sync" "Waiting for the homeserver to have everything"\n' +
            'st=$("$s" --wait 120 2>&1) || [ "$(notify-send -u critical -w -A default="' + verb + ' anyway" "Not synced" ' +
            '"$st. Click to ' + verb + ' anyway, dismiss to cancel.")" = default ] || exit 0\n' +
            cmd];
    }

    readonly property var actions: ({
            // Guard against stacking instances if the bind is hit twice --
            // straight from the old script.
            "lock": ["sh", "-c", "pidof hyprlock || hyprlock"],
            // Muting first stops audio blaring on resume.
            "sleep": synced("sleep", "pactl set-sink-mute @DEFAULT_SINK@ 1; systemctl suspend"),
            // Hyprland's Lua config parser has no `exit` keyword dispatcher --
            // the runtime form is a Lua expression. See hypr/hyprland.lua.
            "logout": ["hyprctl", "dispatch", "hl.dsp.exit()"],
            "restart": synced("restart", "systemctl reboot"),
            "shutdown": synced("shut down", "systemctl poweroff")
        })

    function run(key: string): void {
        const cmd = root.actions[key];
        if (cmd) Quickshell.execDetached(cmd);
    }
}
