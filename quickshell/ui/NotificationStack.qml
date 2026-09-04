import QtQuick
import "../services"
import ".."

// The notification list itself: mako's max-visible=5, margin=6, anchored
// top-right. Newest on top, same as mako's default stacking order.
Column {
    id: root

    spacing: Theme.notifMargin

    Repeater {
        model: Notifications.tracked

        NotificationPopup {
            required property var modelData
            required property int index
            notification: modelData
            visible: index < Theme.notifMaxVisible
            onDismissAll: {
                const list = Notifications.tracked.values;
                for (const n of list) n.dismiss();
            }
        }
    }
}
