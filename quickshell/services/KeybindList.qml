pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every Hyprland bind, read live from `hyprctl binds -j` so it can never drift
// from hypr/hyprland.lua. With the Lua config, Hyprland only reports binds
// that carry a `description` -- which is why every hl.bind there has one.
// Feeds the cheatsheet (panels/Keybinds.qml, `?` in the SUPER+D hub) and the `?` mode of the
// SUPER+D search.
Singleton {
    id: root

    // [{ label, sublabel, glyph, key }] -- already in ui/Picker.qml's shape.
    property var items: []

    readonly property var mods: [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]]

    function keyName(k: string): string {
        const names = {
            "mouse:272": "Left drag", "mouse:273": "Right drag",
            "mouse_down": "Scroll ↓", "mouse_up": "Scroll ↑",
            "Return": "Enter", "slash": "/", "Print": "PrtSc",
            "left": "←", "right": "→", "up": "↑", "down": "↓"
        };
        return names[k] ?? (k.length === 1 ? k.toUpperCase() : k.replace(/^XF86/, ""));
    }

    function combo(b: var): string {
        const parts = root.mods.filter(m => (b.modmask & m[0]) !== 0).map(m => m[1]);
        parts.push(root.keyName(b.key || ""));
        return parts.join(" + ");
    }

    // Cheap (one hyprctl call); run on every open so a just-reloaded config
    // shows up without restarting the shell.
    function refresh(): void {
        proc.running = false;
        proc.running = true;
    }

    Process {
        id: proc
        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.items = JSON.parse(text).map(b => ({
                        label: b.description || (b.key + " (" + b.dispatcher + ")"),
                        // Picker shows sublabel after the label; the combo
                        // reads best there, and searching matches it too.
                        sublabel: root.combo(b) + (b.submap ? "  [" + b.submap + "]" : ""),
                        glyph: b.mouse ? "󰍽" : "󰌌",
                        key: { type: "keybind" }
                    }));
                } catch (e) {
                    root.items = [];
                }
            }
        }
    }
}
