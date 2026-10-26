import QtQuick
import "../services"
import ".."

// The notification list itself: mako's max-visible=5, margin=6, anchored
// top-right. `tracked` appends, so the newest is at the bottom and overflow
// hides the oldest, as mako does.
Column {
    id: root

    spacing: Theme.notifMargin

    Repeater {
        model: Notifications.tracked

        NotificationPopup {
            required property var modelData
            required property int index
            notification: modelData
            visible: index >= Notifications.tracked.values.length - Theme.notifMaxVisible
            onDismissAll: Notifications.dismissAll()
        }
    }
}
