import QtQuick
import ".."
import "../ui"
import "modules"

// Direct replacement for waybar/config.jsonc + waybar/style.css: three
// floating pills (left/center/right), same module order, same colors
// (Theme's per-module color roles are the ones ported from waybar/style.css).
// One PanelWindow instance of this is created per screen in shell.qml.
Item {
    id: root

    signal panelRequested(string name)

    implicitHeight: Theme.barHeight

    Pill {
        id: left
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        Workspaces {}
        Submap {}
        Sep {}
        ClockModule {
            onCalendarRequested: root.panelRequested("calendar")
        }
    }

    Pill {
        id: center
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        Sys {}
        Battery {}
    }

    Pill {
        id: right
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        Network {
            onClicked: root.panelRequested("network")
        }
        Bluetooth {
            onClicked: root.panelRequested("bluetooth")
        }
        Sep {}
        AudioModule {
            onClicked: root.panelRequested("audio")
        }
        Sep {}
        Language {}
        Tray {}
    }
}
