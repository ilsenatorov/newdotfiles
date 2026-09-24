import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "../.."

// Workspace pills for this bar's monitor, read from Quickshell.Hyprland.
// ext-workspace-v1 (Quickshell.WindowManager) was used before, but its
// per-output groups never picked up the external monitor, so that bar stayed
// empty. Dispatching still shells out to hyprctl in Lua form: this Hyprland
// config is Lua and its IPC evaluates dispatch arguments as Lua. The active
// submap indicator lives here so it shares the workspaces pill.
Item {
    id: root

    required property var screen

    // Active submap (e.g. "resize" from hypr/hyprland.lua), updated from Hyprland's
    // socket2 "submap" events below. Hyprland emits "submap global" when the submap
    // is exited, so a genuinely active mode is any non-empty data other than
    // "global" -- that is what the indicator's visible guard checks.
    property string submap: ""

    // Special workspaces have negative ids; only numbered ones get a pill.
    readonly property var sortedWorkspaces: Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.monitor && w.monitor.name === root.screen.name)
        .sort((a, b) => a.id - b.id)

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            model: root.sortedWorkspaces

            Rectangle {
                id: ws
                required property var modelData

                width: label.implicitWidth + 12
                height: Theme.barHeight - 8
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                radius: 8
                color: modelData.active ? Colors.surface : "transparent"

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: ws.modelData.name
                    font.family: Theme.font
                    font.pixelSize: Theme.fsBar
                    color: ws.modelData.urgent ? Theme.red
                        : ws.modelData.active ? Colors.accent : Theme.fg
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    onClicked: root.dispatch("hl.dsp.focus({workspace=" + ws.modelData.id + "})")
                    onEntered: if (!ws.modelData.active) label.color = Colors.accent
                    onExited: if (!ws.modelData.active) label.color = Theme.fg
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.submap !== "" && root.submap !== "global"
            text: "  " + root.submap
            height: Theme.barHeight - 8
            verticalAlignment: Text.AlignVCenter
            font.family: Theme.font
            font.pixelSize: Theme.fsBar
            color: Theme.yellow
        }
    }

    // Scroll anywhere on the workspace pill to switch, same Lua-dispatch form
    // as the SUPER+wheel keybind in hypr/hyprland.lua and the old
    // waybar/config.jsonc on-scroll handlers. Sits above the Repeater so it
    // catches wheel events the per-workspace MouseAreas don't claim.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const dir = wheel.angleDelta.y > 0 ? "e+1" : "e-1";
            root.dispatch("hl.dsp.focus({workspace='" + dir + "'})");
        }
    }

    function dispatch(call: string): void {
        dispatchProc.command = ["hyprctl", "dispatch", call];
        dispatchProc.running = true;
    }

    Process {
        id: dispatchProc
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "submap") root.submap = event.data;
        }
    }
}
