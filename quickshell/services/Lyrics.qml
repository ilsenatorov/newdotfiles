pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Synced lyrics for whatever Media is showing, from lrclib.net -- free, no
// key, no account. Lazy: nothing is fetched until a panel sets `wanted`, so a
// closed media panel never sends track names anywhere. A track change while
// the panel is open fetches again; results are cached in memory so flipping
// back and forth between two songs (or reopening the panel) is instant.
Singleton {
    id: root

    // Set while a panel showing lyrics is open.
    property bool wanted: false

    // [{ t: seconds, text }] -- sorted by t. Unsynced lyrics get t = -1.
    property var lines: []
    property bool synced: false
    // "idle" | "loading" | "ok" | "none"
    property string state: "idle"

    readonly property string trackKey: Media.present
        ? [Media.artist, Media.title, Math.round(Media.length)].join("\u0001")
        : ""

    // Index of the line being sung right now, or -1 before the first.
    readonly property int index: {
        if (!root.synced || root.lines.length === 0) return -1;
        const pos = Media.position + 0.3; // land on a line a beat early, like karaoke
        let lo = 0, hi = root.lines.length - 1, ans = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (root.lines[mid].t <= pos) { ans = mid; lo = mid + 1; }
            else hi = mid - 1;
        }
        return ans;
    }

    property var cache: ({})
    property var cacheOrder: []
    property string pendingKey: ""

    onWantedChanged: refresh()
    onTrackKeyChanged: refresh()

    function refresh(): void {
        // No artist = a browser tab or a video, not a song -- don't ask.
        if (!root.wanted || root.trackKey === "" || Media.title === "" || Media.artist === "") {
            root.lines = [];
            root.state = root.trackKey === "" ? "idle" : "none";
            return;
        }
        const hit = root.cache[root.trackKey];
        if (hit) {
            root.apply(hit);
            return;
        }
        if (root.pendingKey === root.trackKey && proc.running) return;
        root.lines = [];
        root.synced = false;
        root.state = "loading";
        root.pendingKey = root.trackKey;
        const args = ["curl", "-sG", "--max-time", "8",
            "-H", "User-Agent: dotfiles-quickshell",
            "https://lrclib.net/api/get",
            "--data-urlencode", "artist_name=" + Media.artist,
            "--data-urlencode", "track_name=" + Media.title];
        if (Media.album !== "") args.push("--data-urlencode", "album_name=" + Media.album);
        if (Media.length > 0) args.push("--data-urlencode", "duration=" + Math.round(Media.length));
        proc.running = false;
        proc.command = args;
        proc.running = true;
    }

    function apply(entry: var): void {
        root.lines = entry.lines;
        root.synced = entry.synced;
        root.state = entry.lines.length > 0 ? "ok" : "none";
    }

    function remember(key: string, entry: var): void {
        const c = Object.assign({}, root.cache);
        c[key] = entry;
        let order = root.cacheOrder.filter(k => k !== key).concat([key]);
        while (order.length > 30) delete c[order.shift()];
        root.cache = c;
        root.cacheOrder = order;
    }

    // "[01:23.45] words" -> { t: 83.45, text: "words" }. A line can carry
    // several stamps ("[00:10.00][01:10.00] chorus"); each becomes a line.
    function parseLrc(text: string): var {
        const out = [];
        const stamp = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
        for (const raw of text.split("\n")) {
            const times = [];
            let m;
            stamp.lastIndex = 0;
            while ((m = stamp.exec(raw)) !== null) times.push(Number(m[1]) * 60 + Number(m[2]));
            if (times.length === 0) continue;
            const words = raw.replace(stamp, "").trim();
            for (const t of times) out.push({ t: t, text: words });
        }
        return out.sort((a, b) => a.t - b.t);
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                const key = root.pendingKey;
                let entry = { lines: [], synced: false };
                try {
                    const d = JSON.parse(text);
                    if (d.syncedLyrics) entry = { lines: root.parseLrc(d.syncedLyrics), synced: true };
                    else if (d.plainLyrics) entry = { lines: d.plainLyrics.split("\n").map(l => ({ t: -1, text: l.trim() })), synced: false };
                } catch (e) {
                    // 404 bodies are JSON too; anything else (offline, HTML
                    // error page) just means "no lyrics" for this track.
                }
                root.remember(key, entry);
                if (key === root.trackKey) root.apply(entry);
            }
        }
    }
}
