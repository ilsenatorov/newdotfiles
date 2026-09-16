import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../.."

// Active keyboard layout with Caps Lock state, same job as waybar's
// hyprland/language module (shortName is the {short} abbreviation).
//
// Hyprland's activelayout socket2 event only fires when the layout *changes*,
// so on startup the current layout is polled from `hyprctl -j devices` instead
// of waiting for the first switch (the activelayout listener below still
// updates instantly afterwards). The same 1s poll keeps the Caps Lock
// indicator current -- Hyprland emits no event for key states, so a poll is
// the only way in, mirroring how waybar polls its keyboard-state module.
// The us/ru layouts themselves come from Hyprland's input{} block, unchanged
// here -- this only displays what Hyprland reports.
Text {
    id: root

    property string layout: ""
    property bool capsOn: false

    text: "  " + shortName(layout) + (root.capsOn ? " ⇪" : "")
    height: Theme.barHeight
    verticalAlignment: Text.AlignVCenter
    font.family: Theme.font
    font.pixelSize: Theme.fsBar
    color: root.capsOn ? Theme.yellow : Theme.blueGray

    // "English (US)" -> "us", "Russian" -> "ru" -- best-effort short code,
    // same abbreviation waybar's {short} format produced.
    function shortName(name: string): string {
        const m = /\(([^)]+)\)/.exec(name);
        if (m) return m[1].toLowerCase();
        return name.slice(0, 2).toLowerCase();
    }

    Process {
        id: devicesProc
        command: ["hyprctl", "-j", "devices"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.sample(JSON.parse(text));
                } catch (e) {}
            }
        }
    }

    // First tick runs at startup (triggeredOnStart), covering initial layout
    // and Caps Lock before the user touches anything.
    Timer {
        repeat: true
        triggeredOnStart: true
        interval: 1000
        onTriggered: devicesProc.running = true
    }

    function sample(d: var): void {
        const keyboards = d && d.keyboards ? d.keyboards : [];
        if (keyboards.length === 0) return;
        // The keyboard marked `main` is the primary one feeding the bar's
        // input; fall back to the first entry if none is marked (older
        // Hyprland or exotic setups).
        const kb = keyboards.filter(k => k.main === true)[0] ?? keyboards[0];
        if (kb.active_keymap) root.layout = kb.active_keymap;
        root.capsOn = kb.capsLock === true;
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                const parts = event.data.split(",");
                root.layout = parts[parts.length - 1] ?? "";
            }
        }
    }
}
