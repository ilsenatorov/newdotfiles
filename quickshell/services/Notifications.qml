pragma Singleton

import QtQuick
import Quickshell
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
Singleton {
    id: root

    readonly property alias tracked: server.trackedNotifications

    NotificationServer {
        id: server

        keepOnReload: true
        // mako had persistence off (no notification history/daemon-restart
        // survival beyond the session) -- match that.
        persistenceSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: false

        onNotification: notification => { notification.tracked = true; }
    }
}
