pragma Singleton

import QtQuick
import Quickshell

// The one-line live status under each SUPER+D hub tile, shared with the
// search palette (panels/Launcher.qml) so a page reads the same in both.
// Plain bindings over the other services: whatever calls statusFor() inside
// a binding re-evaluates when the underlying state moves.
Singleton {
    id: root

    function statusFor(key: string): string {
        switch (key) {
        case "network":
            if (Net.wired) return "Ethernet";
            if (Net.wifiConnected) return Net.ssid;
            return Net.wifiEnabled ? "Disconnected" : "Wi-Fi off";
        case "bluetooth":
            if (!Bt.available) return "Unavailable";
            if (!Bt.powered) return "Off";
            return Bt.anyConnected ? Bt.primaryConnectedName : "On";
        case "audio":
            return Audio.muted ? "Muted" : Math.round(Audio.volume * 100) + "%  " + Audio.sinkName;
        case "media":
            if (!Media.present) return "Nothing playing";
            return (Media.active ? "" : "󰏤 ") + Media.title;
        case "notifications":
            if (Notifications.dnd) return "Do not disturb";
            return Notifications.unread > 0 ? Notifications.unread + " unread" : Notifications.history.length + " stored";
        case "quick": {
            if (Recorder.recording) return "● Recording " + Recorder.elapsedText();
            const on = [];
            if (NightLight.available && NightLight.enabled) on.push(NightLight.temperature + "K");
            if (Caffeine.enabled) on.push("caffeine");
            return on.length > 0 ? on.join(" · ") : "Night light, caffeine, rec";
        }
        case "monitor": {
            const n = Quickshell.screens.length;
            return n + (n === 1 ? " display" : " displays");
        }
        case "wallpaper": return "Pick & recolor";
        case "ask": return "Quick question";
        case "resize": return "Arrows, then Esc";
        case "reload": return "Hyprland config";
        case "power": return "Lock, sleep, off";
        case "clipboard": return "History";
        case "keybinds": return "Every bind";
        case "dashboard": return "System info";
        }
        return "";
    }
}
