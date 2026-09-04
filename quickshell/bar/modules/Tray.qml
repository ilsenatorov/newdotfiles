import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../.."

// System tray -- disabled in waybar/config.jsonc (the module was commented
// out, so nm-applet's icon had nowhere to render). Enabled here for real.
// Left click activates (mirrors a normal tray left-click); right click uses
// the item's secondary action rather than rendering its DBus menu, which
// keeps this module simple -- most tray apps treat secondary-activate as
// "open the same thing a menu's default entry would".
Row {
    spacing: Theme.barModulePad

    Repeater {
        model: SystemTray.items

        Item {
            required property var modelData
            width: 18
            height: Theme.barHeight - 8
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

            Image {
                anchors.centerIn: parent
                width: 16
                height: 16
                source: modelData.icon
                opacity: modelData.status === Status.Passive ? 0.6 : 1.0
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        modelData.secondaryActivate();
                    else
                        modelData.activate();
                }
            }
        }
    }
}
