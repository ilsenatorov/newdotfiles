import QtQuick
import ".."
import "../ui"
import "modules"

// Direct replacement for waybar/config.jsonc + waybar/style.css: three
// floating pills (left/center/right), same colors (Theme's per-module color
// roles are the ones ported from waybar/style.css). Module membership per
// section comes from local.conf's BAR_LEFT/BAR_CENTER/BAR_RIGHT (see
// Local.qml and ModuleRow.qml) -- defaults below match the original
// hardcoded order exactly, so a machine with no local.conf looks identical
// to before this existed. One PanelWindow instance of this is created per
// screen in shell.qml.
Item {
    id: root

    required property var screen
    signal panelRequested(string name)

    implicitHeight: Theme.barHeight

    // name -> component. Workspaces needs `screen`; Network/Bluetooth/Audio
    // forward clicked -> panelRequested. Everything else is parameterless.
    Component { id: workspacesC; Workspaces { screen: root.screen } }
    Component { id: submapC; Submap {} }
    Component { id: clockC; ClockModule { onCalendarRequested: root.panelRequested("calendar") } }
    Component { id: gpuC; Gpu {} }
    Component { id: sysC; Sys {} }
    Component { id: batteryC; Battery {} }
    Component { id: networkC; Network { onClicked: root.panelRequested("network") } }
    Component { id: bluetoothC; Bluetooth { onClicked: root.panelRequested("bluetooth") } }
    Component { id: audioC; AudioModule { onClicked: root.panelRequested("audio") } }
    Component { id: languageC; Language {} }

    readonly property var registry: ({
        workspaces: workspacesC, submap: submapC, clock: clockC,
        gpu: gpuC, sys: sysC, battery: batteryC,
        network: networkC, bluetooth: bluetoothC, audio: audioC, language: languageC,
    })

    Pill {
        id: left
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: Local.barLeft.length > 0

        ModuleRow { names: Local.barLeft; registry: root.registry }
    }

    Pill {
        id: center
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        visible: Local.barCenter.length > 0

        ModuleRow { names: Local.barCenter; registry: root.registry }
    }

    Pill {
        id: right
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: Local.barRight.length > 0

        ModuleRow { names: Local.barRight; registry: root.registry }
    }
}
