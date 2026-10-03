pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import ".."

// Thin wrapper over the Mpris service. Event-driven over D-Bus -- no playerctl
// subprocess and no polling, so an idle player costs nothing. Spotify needs
// nothing special: its desktop client publishes org.mpris.MediaPlayer2.spotify
// like any other player, it is just preferred when several are around.
Singleton {
    id: root

    // The player that was playing most recently. Remembered so pausing keeps
    // the bar pill and panel on the same track instead of dropping to null
    // (or jumping to whichever other player happens to be first).
    property MprisPlayer last: null
    // Set by cyclePlayer(): the user picked this one, so it wins over the
    // "whoever is playing" rule until it goes away.
    property MprisPlayer pinned: null

    readonly property var players: Mpris.players.values

    function isSpotify(p: var): bool {
        if (!p) return false;
        return /spotify/i.test(p.identity || "") || /spotify/i.test(p.desktopEntry || "");
    }

    readonly property MprisPlayer player: {
        const list = root.players;
        if (root.pinned && list.includes(root.pinned)) return root.pinned;
        const playing = list.filter(p => p.isPlaying);
        if (playing.length > 0) return playing.find(p => root.isSpotify(p)) ?? playing[0];
        if (root.last && list.includes(root.last)) return root.last;
        return list.find(p => root.isSpotify(p)) ?? list[0] ?? null;
    }

    // Watches every player, not just the chosen one: `player` itself reads
    // `last`, so updating it from onPlayerChanged would be a binding loop.
    Instantiator {
        model: Mpris.players

        Connections {
            required property MprisPlayer modelData
            target: modelData
            function onIsPlayingChanged() { if (modelData.isPlaying) root.last = modelData; }
        }
    }

    // A player exists (playing or paused) -- what the bar pill and panel key on.
    readonly property bool present: player !== null
    // Something is actually playing -- the dashboard's now-playing row.
    readonly property bool active: player !== null && player.isPlaying
    readonly property bool spotify: root.isSpotify(player)

    readonly property string title: player ? (player.trackTitle || player.identity || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string album: player ? (player.trackAlbum || "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    readonly property real position: player ? player.position : 0
    readonly property real length: player && player.lengthSupported ? player.length : 0

    readonly property string text: {
        if (player === null) return "";
        const t = player.trackTitle || "";
        const a = player.trackArtist || "";
        if (t === "" && a === "") return player.identity || "";
        return a === "" ? t : t + "  —  " + a;
    }

    // MprisPlayer.position is computed locally from the last D-Bus update and
    // only re-emits when told to -- this is that nudge, and it costs no IPC.
    Timer {
        running: root.active && root.player.positionSupported
        repeat: true
        interval: 1000
        onTriggered: root.player.positionChanged()
    }

    function toggle(): void { if (player && player.canTogglePlaying) player.togglePlaying(); }
    function next(): void { if (player && player.canGoNext) player.next(); }
    function previous(): void { if (player && player.canGoPrevious) player.previous(); }

    function seekTo(sec: real): void {
        if (!player || !player.canSeek) return;
        player.position = Math.max(0, root.length > 0 ? Math.min(root.length - 1, sec) : sec);
    }
    function seekBy(sec: real): void { seekTo(root.position + sec); }

    function cyclePlayer(step: int): void {
        const list = root.players;
        if (list.length < 2) return;
        const i = Math.max(0, list.indexOf(root.player));
        root.pinned = list[((i + step) % list.length + list.length) % list.length];
    }

    function formatTime(sec: real): string {
        if (!(sec > 0)) return "0:00";
        const s = Math.floor(sec);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // ---- per-app volume ---------------------------------------------------
    // Spotify's MPRIS Volume is unreliable (often read-only or ignored), so
    // the player's own Pipewire playback stream is the real volume knob.
    // Matched on the stream's application/binary name against the player's
    // identity/desktop entry; MPRIS volume is the fallback.
    readonly property var stream: {
        if (!player) return null;
        const keys = [player.identity, player.desktopEntry].filter(s => s).map(s => s.toLowerCase());
        if (keys.length === 0) return null;
        return Pipewire.nodes.values.find(n => {
            if (!n.isStream) return false;
            const p = n.properties || {};
            // Playback only -- a recording stream (a mic capture) of the same
            // app would otherwise be a match too.
            if (!String(p["media.class"] || "").startsWith("Stream/Output")) return false;
            const hay = [p["application.name"], p["application.process.binary"], p["node.name"]]
                .filter(s => s).map(s => String(s).toLowerCase());
            return hay.some(h => keys.some(k => h.includes(k) || k.includes(h)));
        }) ?? null;
    }

    PwObjectTracker {
        objects: root.stream ? [root.stream] : []
    }

    readonly property bool volumeAvailable: (stream && stream.audio) || (player && player.volumeSupported)
    readonly property real volume: stream && stream.audio ? stream.audio.volume
        : (player && player.volumeSupported ? player.volume : 0)

    function setVolume(v: real): void {
        const c = Math.max(0, Math.min(1, v));
        if (stream && stream.audio) stream.audio.volume = c;
        else if (player && player.volumeSupported) player.volume = c;
    }
    function nudgeVolume(d: real): void { setVolume(root.volume + d); }

    // ---- cover colour -----------------------------------------------------
    // The panel tints its progress bar and play button from the cover, the
    // way the rest of the shell takes its accent from the wallpaper.
    ColorQuantizer {
        id: quant
        source: root.artUrl
        depth: 2
        rescaleSize: 48
    }

    readonly property color artAccent: {
        let best = null, score = -1;
        for (const c of quant.colors) {
            // Saturated and not too dark/light reads best on the dark card.
            const s = c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.55) * 1.6);
            if (s > score) { score = s; best = c; }
        }
        if (!best || score < 0.12) return Colors.accent;
        return Qt.hsla(best.hslHue, Math.max(0.45, best.hslSaturation), Math.max(0.55, Math.min(0.72, best.hslLightness)), 1);
    }

    // qs ipc call media toggle|next|previous|status
    IpcHandler {
        target: "media"

        function toggle(): void { root.toggle(); }
        function next(): void { root.next(); }
        function previous(): void { root.previous(); }
        function status(): string {
            if (!root.player) return "none";
            return (root.active ? "playing" : "paused") + "\t" + (root.player.identity || "") + "\t" + root.text;
        }
    }
}
