pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Per-machine overrides, read from ~/.config/dotfiles/local.conf -- a plain
// KEY=value file living outside this repo (~/.config is a symlink INTO the
// repo for every directory link.sh manages, so anything written there would
// sync verbatim to every machine; see install.sh's 20-va.conf comment for the
// same reasoning). Generated once by install.sh, prefilled from hardware
// probes, and never overwritten after that -- hand-edit freely.
//
// Every property here has a default equal to today's hardcoded value, so a
// missing or partially-filled file changes nothing. hypr/hyprland.lua reads
// the sibling local.lua for its own (structured) knobs; this file is the
// flat subset shared with the shell scripts and QML.
Singleton {
    id: root

    readonly property real uiScale: num("UI_SCALE", 1.0)

    // 0/blank = derive from uiScale (see Theme.qml); set to override outright.
    readonly property int barHeight: num("BAR_HEIGHT", 0)
    readonly property int fsBar: num("FONT_SIZE_BAR", 0)
    readonly property int dashboardW: num("DASHBOARD_W", 0)
    readonly property int dashboardH: num("DASHBOARD_H", 0)

    // Comma-separated module names per bar section; Bar.qml maps them through
    // its registry. A key absent from the file keeps its default below; a key
    // present but empty hides that section's pill entirely.
    readonly property var barLeft: list("BAR_LEFT", ["workspaces", "submap", "clock"])
    readonly property var barCenter: list("BAR_CENTER", ["gpu", "sys", "battery"])
    readonly property var barRight: list("BAR_RIGHT", ["network", "bluetooth", "audio", "language"])

    // Expensive pollers/services -- 0 disables outright on weak hardware.
    readonly property bool svcWeather: bool_("SVC_WEATHER", true)
    readonly property bool svcClaudeUsage: bool_("SVC_CLAUDE_USAGE", true)
    readonly property bool svcGpu: bool_("SVC_GPU", true)
    readonly property int sysmonIntervalFast: num("SYSMON_INTERVAL_FAST", 2000)
    readonly property int sysmonIntervalSlow: num("SYSMON_INTERVAL_SLOW", 10000)

    property var values: ({})

    function num(key: string, def: real): real {
        const v = root.values[key];
        if (v === undefined || v === "") return def;
        const n = Number(v);
        return isNaN(n) ? def : n;
    }

    function bool_(key: string, def: bool): bool {
        const v = root.values[key];
        if (v === undefined || v === "") return def;
        return v !== "0" && v.toLowerCase() !== "false";
    }

    function list(key: string, def: var): var {
        const v = root.values[key];
        if (v === undefined) return def;
        if (v === "") return [];
        return v.split(",").map(s => s.trim()).filter(s => s.length > 0);
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/dotfiles/local.conf"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onLoaded: root.parse()
        onFileChanged: reload()
        onTextChanged: root.parse()
    }

    function parse(): void {
        const out = {};
        const text = file.text();
        if (text) {
            for (const line of text.split("\n")) {
                const t = line.trim();
                if (t === "" || t.startsWith("#")) continue;
                const eq = t.indexOf("=");
                if (eq < 0) continue;
                out[t.slice(0, eq).trim()] = t.slice(eq + 1).trim();
            }
        }
        root.values = out;
    }

    Component.onCompleted: parse()
}
