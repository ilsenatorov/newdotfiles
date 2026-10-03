pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Replaces mako. NotificationServer owns the org.freedesktop.Notifications
// D-Bus name -- only one process can hold it, so mako's autostart had to
// come out of hyprland.lua in the same commit that added this. `tracked`
// mirrors mako's list of currently-visible toasts; popups are rendered by
// ui/NotificationPopup.qml, one per entry, in shell.qml's overlay window.
// expireTimeout is read-only on Notification (server-negotiated, not
// settable from here), so the mako-equivalent per-urgency default timeout
// (see Theme.notifDefaultTimeout/notifLowTimeout) is applied by each popup's
// own dismiss timer instead -- see ui/NotificationPopup.qml.
//
// On top of the toasts: a history for the notification center
// (panels/NotificationCenter.qml) and a Do Not Disturb switch. Both live in
// ~/.local/state/quickshell-notifications/state.json -- matugen hot-reloads
// the whole shell on every wallpaper change, and an in-memory history would
// be wiped each time.
Singleton {
    id: root

    readonly property alias tracked: server.trackedNotifications

    // Newest first. Each entry: { uid, appName, appIcon, image, summary,
    // body, urgency, time } -- plain data, so it survives a reload; the live
    // Notification object (and its actions) does not.
    property var history: []
    property int unread: 0
    property bool dnd: false

    readonly property int maxHistory: 100
    readonly property string path: Quickshell.env("HOME") + "/.local/state/quickshell-notifications/state.json"
    property int seq: 0

    function dismissAll(): void {
        const notifications = Array.from(server.trackedNotifications.values);
        for (const notification of notifications) notification.dismiss();
    }

    function toggleDnd(): void {
        root.dnd = !root.dnd;
        saveTimer.restart();
    }

    function remove(uid: string): void {
        root.history = root.history.filter(e => e.uid !== uid);
        saveTimer.restart();
    }

    function clearHistory(): void {
        root.history = [];
        root.unread = 0;
        saveTimer.restart();
    }

    function markRead(): void {
        if (root.unread === 0) return;
        root.unread = 0;
        saveTimer.restart();
    }

    // Only a real file is worth keeping: image://... URLs point into this
    // process's memory and are dead after a reload.
    function keepablePath(s: string): string {
        if (!s) return "";
        if (s.startsWith("/")) return "file://" + s;
        if (s.startsWith("file://")) return s;
        return "";
    }

    function record(n: var): void {
        root.seq++;
        const entry = {
            uid: Date.now().toString(36) + "-" + root.seq,
            appName: n.appName || "Unknown",
            appIcon: n.appIcon || "",
            image: root.keepablePath(n.image || ""),
            summary: n.summary || "",
            body: n.body || "",
            urgency: n.urgency,
            time: Date.now()
        };
        root.history = [entry].concat(root.history).slice(0, root.maxHistory);
        root.unread++;
        saveTimer.restart();
    }

    IpcHandler {
        target: "notifications"
        function dismiss(): void { root.dismissAll(); }
        function toggleDnd(): void { root.toggleDnd(); }
        function clear(): void { root.clearHistory(); }
        function status(): string { return (root.dnd ? "dnd" : "on") + "\t" + root.unread + " unread\t" + root.history.length + " stored"; }
    }

    NotificationServer {
        id: server

        keepOnReload: true
        // mako had persistence off (no notification history/daemon-restart
        // survival beyond the session) -- match that. History above is ours,
        // not the spec's persistence.
        persistenceSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: false

        onNotification: notification => {
            root.record(notification);
            // DND: still recorded above, just no toast. Critical ones get
            // through anyway -- a low battery warning is not a distraction.
            if (root.dnd && notification.urgency !== NotificationUrgency.Critical) return;
            notification.tracked = true;
        }
    }

    // ---- persistence ------------------------------------------------------
    // Debounced so a burst of notifications is one write. Whole-file rewrite
    // through sh, the same way services/LauncherUsage.qml does it.
    Timer {
        id: saveTimer
        interval: 500
        onTriggered: {
            writer.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")" && printf "%s" "$1" > "$2"', "write",
                JSON.stringify({ dnd: root.dnd, unread: root.unread, history: root.history }), root.path];
            writer.running = true;
        }
    }

    Process { id: writer }

    FileView {
        id: file
        path: root.path
        printErrors: false
        blockLoading: true
    }

    Component.onCompleted: {
        try {
            const t = file.text();
            if (!t) return;
            const d = JSON.parse(t);
            root.dnd = d.dnd === true;
            root.unread = d.unread || 0;
            root.history = Array.isArray(d.history) ? d.history.slice(0, root.maxHistory) : [];
        } catch (e) {
            // Mangled file: start empty, the next save rewrites it.
        }
    }
}
