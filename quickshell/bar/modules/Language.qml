import QtQuick
import Quickshell.Hyprland
import "../.."

// Active keyboard layout, same as waybar's hyprland/language module. The us/ru
// layouts themselves come from Hyprland's input{} block, unchanged here --
// this only displays what Hyprland reports.
Text {
    id: root

    property string layout: ""

    text: "  " + shortName(layout)
    height: Theme.barHeight
    verticalAlignment: Text.AlignVCenter
    font.family: Theme.font
    font.pixelSize: Theme.fsBar
    color: Theme.blueGray

    // "English (US)" -> "us", "Russian" -> "ru" -- best-effort short code,
    // same abbreviation waybar's {short} format produced.
    function shortName(name: string): string {
        const m = /\(([^)]+)\)/.exec(name);
        if (m) return m[1].toLowerCase();
        return name.slice(0, 2).toLowerCase();
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
