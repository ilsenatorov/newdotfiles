import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../.."

// Active keyboard layout, same job as waybar's hyprland/language module
// (shortName is the {short} abbreviation).
//
// Hyprland's activelayout socket2 event only fires when the layout *changes*,
// so the current layout is read once at startup from `hyprctl -j devices`;
// after that the activelayout listener below keeps it current. No polling --
// which is also why there is no Caps Lock indicator: Hyprland emits no event
// for key states, and a 1s `hyprctl` poll for it was not worth the spawns.
// The us/ru/graphite layouts themselves come from Hyprland's input{} block, unchanged
// here -- this only displays what Hyprland reports.
Text {
    id: root

    property string layout: ""

    text: " " + shortName(layout)
    height: Theme.barHeight
    verticalAlignment: Text.AlignVCenter
    font.family: Theme.font
    font.pixelSize: Theme.fsBar
    color: Theme.blueGray

    // "English (US)" -> "us", "Russian" -> "ru", "English (Graphite)" -> "gr"
    // -- best-effort two-letter code.
    function shortName(name: string): string {
        const m = /\(([^)]+)\)/.exec(name);
        return (m ? m[1] : name).slice(0, 2).toLowerCase();
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

    Component.onCompleted: devicesProc.running = true

    function sample(d: var): void {
        const keyboards = d && d.keyboards ? d.keyboards : [];
        if (keyboards.length === 0) return;
        // The keyboard marked `main` is the primary one feeding the bar's
        // input; fall back to the first entry if none is marked (older
        // Hyprland or exotic setups).
        const kb = keyboards.filter(k => k.main === true)[0] ?? keyboards[0];
        if (kb.active_keymap) root.layout = kb.active_keymap;
    }

    // Left click: next layout, right click: previous. switchxkblayout is a
    // plain hyprctl request, not a dispatcher, so the Lua config doesn't
    // mangle it; the activelayout event below updates the label.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => Quickshell.execDetached(["hyprctl", "switchxkblayout", "current",
            mouse.button === Qt.RightButton ? "prev" : "next"])
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
