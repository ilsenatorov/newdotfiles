pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Thin wrapper over the Mpris service. Event-driven over D-Bus -- no playerctl
// subprocess and no polling, so an idle player costs nothing.
Singleton {
    id: root

    readonly property MprisPlayer player: {
        for (const p of Mpris.players.values) {
            if (p.isPlaying) return p;
        }
        return null;
    }

    readonly property bool active: player !== null

    readonly property string text: {
        if (player === null) return "";
        const t = player.trackTitle || "";
        const a = player.trackArtist || "";
        if (t === "" && a === "") return player.identity || "";
        return a === "" ? t : t + "  —  " + a;
    }
}
