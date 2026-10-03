import QtQuick
import Quickshell
import ".."
import "../services"
import "../ui"

// SUPER+D, d. The search half of the SUPER+D menu: apps, every hub page,
// toggles that flip in place, recording, power, plus two prefix modes --
// `=` is a calculator, `?` searches the keybind list.
//
// Apps come from Quickshell's own XDG index (DesktopEntries), as before; the
// rest is a fixed catalogue below. Everything accepted here is counted in
// LauncherUsage (apps by desktop id, the rest as "palette:<id>"), so the
// things you actually use float up -- for an empty query, and as the
// tie-breaker when typing.
//
// Esc layering is Picker's: clears a typed query, then falls through to
// shell.qml (back to the hub, or close). A page opened from here returns to
// this search with the query and cursor restored (shell.paletteQuery).
Picker {
    id: root

    // A hub page (or ask/resize/reload/dashboard) -- shell.hubSelect does it.
    signal openPage(string key)

    placeholder: "Search apps, settings, actions  ·  = calc  ·  ? keys"
    showIcons: true
    cardWidth: Theme.menuW
    filterFn: root.rank

    Component.onCompleted: KeybindList.refresh()

    // ---- catalogue ----------------------------------------------------------
    // `words` are extra search terms that don't belong in the visible label.

    readonly property var pages: [
        { id: "network", label: "Network", glyph: "󰖩", words: "wifi wi-fi internet ethernet" },
        { id: "bluetooth", label: "Bluetooth", glyph: "󰂯", words: "headphones pair" },
        { id: "audio", label: "Audio", glyph: "󰕾", words: "sound volume output speaker" },
        { id: "media", label: "Now playing", glyph: "󰝚", words: "music spotify player lyrics" },
        { id: "notifications", label: "Notifications", glyph: "󰂚", words: "history dnd" },
        { id: "quick", label: "Quick settings", glyph: "󰒓", words: "toggles" },
        { id: "monitor", label: "Displays", glyph: "󰍹", words: "monitor screen layout" },
        { id: "wallpaper", label: "Wallpaper", glyph: "󰸉", words: "background theme colors" },
        { id: "ask", label: "Ask", glyph: "󰚩", words: "claude question ai" },
        { id: "clipboard", label: "Clipboard", glyph: "󰅌", words: "paste history copy" },
        { id: "keybinds", label: "Keybinds", glyph: "󰌌", words: "shortcuts keys cheatsheet" },
        { id: "dashboard", label: "System info", glyph: "󰍛", words: "dashboard cpu memory processes" },
        { id: "resize", label: "Resize window", glyph: "󰩨", words: "" },
        { id: "reload", label: "Reload Hyprland", glyph: "󰑓", words: "config" }
    ]

    // Each toggle flips in place; `on` drives the sublabel.
    readonly property var toggles: [
        { id: "nightlight", label: "Night light", glyph: "󰖔", words: "redshift blue light warm temperature",
            show: NightLight.available, on: NightLight.enabled,
            state: NightLight.enabled ? NightLight.temperature + " K" : "off" },
        { id: "dnd", label: "Do not disturb", glyph: "󰂛", words: "dnd notifications silence",
            show: true, on: Notifications.dnd },
        { id: "caffeine", label: "Caffeine", glyph: "󰅶", words: "awake idle inhibit sleep",
            show: true, on: Caffeine.enabled },
        { id: "mute", label: "Mute audio", glyph: "󰝟", words: "sound volume silence",
            show: true, on: Audio.muted },
        { id: "micmute", label: "Mute microphone", glyph: "󰍭", words: "mic",
            show: true, on: Audio.micMuted },
        { id: "recaudio", label: "Record desktop audio", glyph: "󰕾", words: "recording sound",
            show: true, on: Recorder.withAudio }
    ]

    readonly property var actions: Recorder.recording
        ? [{ id: "recstop", label: "Stop recording", glyph: "󰓛", words: "record video", state: "● " + Recorder.elapsedText() }]
        : [
            { id: "recregion", label: "Record a region", glyph: "󰩭", words: "video screencast capture", state: "drag a rectangle" },
            { id: "recscreen", label: "Record the screen", glyph: "󰍹", words: "video screencast capture", state: "focused monitor" }
        ]

    // Destructive power rows ask twice: the first Enter only arms them.
    property string armed: ""
    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }
    onQueryEdited: root.armed = ""

    // Flipping a toggle or arming a power row rebuilds `items` (their
    // sublabels change); put the cursor back where it was in case the list
    // view reset it.
    function keepCursor(fn: var): void {
        const i = root.currentIndex;
        fn();
        Qt.callLater(() => root.currentIndex = i);
    }

    function confirmText(id: string): string {
        return { logout: "Enter again to log out", restart: "Enter again to restart", shutdown: "Enter again to shut down" }[id] ?? "";
    }

    items: {
        const out = [];
        const apps = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        for (const a of apps) {
            if (a.noDisplay) continue;
            out.push({
                label: a.name,
                // genericName/comment are what make "browser" find Firefox.
                sublabel: a.genericName || a.comment || "",
                icon: a.icon,
                key: { type: "app", id: a.id, entry: a }
            });
        }
        for (const p of root.pages)
            out.push({ label: p.label, sublabel: HubStatus.statusFor(p.id), glyph: p.glyph,
                key: { type: "page", id: p.id, words: p.words } });
        for (const t of root.toggles) {
            if (!t.show) continue;
            out.push({ label: t.label, sublabel: t.state ?? (t.on ? "on" : "off"), glyph: t.glyph,
                key: { type: "toggle", id: t.id, words: t.words } });
        }
        for (const a of root.actions)
            out.push({ label: a.label, sublabel: a.state, glyph: a.glyph,
                key: { type: "action", id: a.id, words: a.words } });
        for (const p of Power.items) {
            const armed = root.armed === p.key;
            out.push({ label: armed ? root.confirmText(p.key) : p.label, sublabel: armed ? "" : "power",
                glyph: p.glyph, key: { type: "power", id: p.key, destructive: p.destructive, words: "power session" } });
        }
        return out;
    }

    // ---- ranking --------------------------------------------------------------
    function usageId(k: var): string {
        return k.type === "app" ? k.id : "palette:" + k.id;
    }

    // Groups for an empty query: apps first (this is the app launcher).
    // Once typing, an equally good match prefers the shell's own pages and
    // toggles -- "net" means the Network page, not some leftover
    // NetworkManager .desktop file.
    readonly property var typeOrder: ({ app: 0, page: 1, toggle: 2, action: 3, power: 4 })
    readonly property var typedOrder: ({ page: 0, toggle: 1, action: 2, app: 3, power: 4 })

    function rank(list: var, query: string): var {
        const raw = query.trim();
        if (raw.startsWith("=")) return root.calcRows(raw.slice(1));
        if (raw.startsWith("?")) {
            const q = raw.slice(1).trim().toLowerCase();
            const all = KeybindList.items;
            return q === "" ? all : all.filter(it => (it.label + " " + it.sublabel).toLowerCase().includes(q));
        }

        const q = raw.toLowerCase();
        const scored = [];
        for (let i = 0; i < list.length; i++) {
            const it = list[i];
            const label = String(it.label).toLowerCase();
            let s = 0;
            if (q === "") s = 1;
            else if (label.startsWith(q)) s = 400;
            else if (label.split(/[\s\-_.]+/).some(w => w.startsWith(q))) s = 300;
            else if (label.includes(q)) s = 200;
            else if ((it.key.words ?? "").split(" ").some(w => w !== "" && w.startsWith(q))) s = 150;
            else if (String(it.sublabel ?? "").toLowerCase().includes(q)) s = 100;
            if (s === 0) continue;
            const id = root.usageId(it.key);
            scored.push({ it: it, s: s, n: LauncherUsage.countFor(id), last: LauncherUsage.lastFor(id), i: i });
        }
        scored.sort((a, b) => {
            // Anything used at all beats anything never used for an empty
            // query; while typing, match quality comes first.
            if (q === "" && (a.n > 0) !== (b.n > 0)) return a.n > 0 ? -1 : 1;
            if (a.s !== b.s) return b.s - a.s;
            if (a.n !== b.n) return b.n - a.n;
            if (a.last !== b.last) return b.last - a.last;
            const order = q === "" ? root.typeOrder : root.typedOrder;
            const ta = order[a.it.key.type], tb = order[b.it.key.type];
            if (ta !== tb) return ta - tb;
            return a.it.key.type === "app" ? String(a.it.label).localeCompare(String(b.it.label)) : a.i - b.i;
        });
        return scored.map(x => x.it);
    }

    // `=2^10*3` -> 3072. Only digits, operators and parentheses get through
    // the check, so the evaluation can't reach anything but arithmetic.
    function calcRows(expr: string): var {
        const e = expr.trim().replace(/,/g, ".");
        if (e === "")
            return [{ label: "Type an expression", sublabel: "e.g. =2^10*3", glyph: "󰃬", key: { type: "noop" } }];
        if (!/^[0-9+\-*/%^().\s]+$/.test(e))
            return [{ label: "Only numbers and + - * / % ^ ( )", sublabel: "", glyph: "󰃬", key: { type: "noop" } }];
        let v;
        try {
            v = Function('"use strict"; return (' + e.replace(/\^/g, "**") + ");")();
        } catch (err) {
            return [{ label: "…", sublabel: "incomplete expression", glyph: "󰃬", key: { type: "noop" } }];
        }
        if (typeof v !== "number" || !isFinite(v))
            return [{ label: "Not a number", sublabel: "", glyph: "󰃬", key: { type: "noop" } }];
        const out = String(parseFloat(v.toPrecision(12)));
        return [{ label: "= " + out, sublabel: "Enter copies", glyph: "󰃬", key: { type: "calc", value: out } }];
    }

    // ---- accept -----------------------------------------------------------------
    onAccepted: item => {
        const k = item.key;
        switch (k.type) {
        case "app":
            LauncherUsage.record(k.id);
            // execute() re-parses the entry's own Exec field codes (%U, %f,
            // terminal handling) -- why the DesktopEntry is handed back
            // rather than a command string to re-implement.
            k.entry.execute();
            root.closeRequested();
            break;
        case "page":
            LauncherUsage.record(root.usageId(k));
            root.openPage(k.id);
            break;
        case "toggle":
            LauncherUsage.record(root.usageId(k));
            root.keepCursor(() => root.flip(k.id));
            break;
        case "action":
            LauncherUsage.record(root.usageId(k));
            if (k.id === "recstop") {
                Recorder.stop();
            } else {
                // Let the menu's close motion clear the screen before slurp
                // (or the first recorded frame) sees it.
                Recorder.startDelayed(k.id === "recscreen" ? "screen" : "region", Theme.durFast + 120);
            }
            root.closeRequested();
            break;
        case "power":
            if (k.destructive && root.armed !== k.id) {
                root.keepCursor(() => root.armed = k.id);
                disarm.restart();
                break;
            }
            LauncherUsage.record(root.usageId(k));
            root.closeRequested();
            Power.run(k.id);
            break;
        case "calc":
            Quickshell.execDetached(["wl-copy", "--", k.value]);
            root.closeRequested();
            break;
        case "keybind":
            root.closeRequested();
            break;
        }
    }

    function flip(id: string): void {
        switch (id) {
        case "nightlight": NightLight.toggle(); break;
        case "dnd": Notifications.toggleDnd(); break;
        case "caffeine": Caffeine.toggle(); break;
        case "mute": Audio.toggleMute(); break;
        case "micmute": Audio.toggleMicMute(); break;
        case "recaudio": Recorder.withAudio = !Recorder.withAudio; break;
        }
    }
}
