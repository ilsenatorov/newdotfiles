import QtQuick
import "../.."
import "../../services"

// Bell + unread count; a crossed-out bell while Do Not Disturb is on.
// Click opens the notification center, right-click flips DND.
Text {
    id: root

    signal clicked

    height: Theme.barHeight
    verticalAlignment: Text.AlignVCenter
    font.family: Theme.font
    font.pixelSize: Theme.fsBar
    text: {
        if (Notifications.dnd) return "󰂛";
        return Notifications.unread > 0 ? "󰂚 " + Notifications.unread : "󰂜";
    }
    color: {
        if (Notifications.dnd) return Theme.dim;
        return Notifications.unread > 0 ? Colors.accent : Theme.blueGray;
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) Notifications.toggleDnd();
            else root.clicked();
        }
    }
}
