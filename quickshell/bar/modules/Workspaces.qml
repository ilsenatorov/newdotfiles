import QtQuick
import Quickshell.Io
import Quickshell.WindowManager
import "../.."

// Occupied-workspace pills. Deliberately NOT Quickshell.Hyprland's dispatch --
// this Hyprland config is Lua (hypr/hyprland.lua) and its IPC socket wraps
// whatever it receives as `return hl.dispatch(<arg>)`, evaluating it as Lua,
// so a bare `dispatch workspace <id>` string is a syntax error there. Reading
// workspace state over ext-workspace-v1 (this module) is unaffected; only
// *dispatching* needs the Lua-form escape hatch, which is why the scroll
// handler below still shells out to hyprctl instead of calling a dispatch
// method directly. Mirrors waybar's ext/workspaces module exactly: occupied
// only, {name} labels, no persistent/visible state (ext-workspace-v1 doesn't
// expose it), urgent highlighting.
Item {
    id: root

    required property var screen

    // Workspace groups in ext-workspace-v1 map to outputs, so this is how
    // "only this monitor's workspaces" is expressed -- WindowManager.windowsets
    // is the flat, unfiltered list across every output.
    readonly property var projection: {
        for (const p of WindowManager.windowsetProjections) {
            if (p.screens.some(s => s.name === root.screen.name)) return p;
        }
        return null;
    }

    // The protocol makes no ordering guarantee (observed as e.g. 5 7 1 0), so
    // sort explicitly by the numeric workspace name.
    readonly property var sortedWorkspaces: {
        const list = projection ? projection.windowsets.slice() : [];
        list.sort((a, b) => parseInt(a.name) - parseInt(b.name));
        return list;
    }

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
                    onClicked: ws.modelData.activate()
                    onEntered: if (!ws.modelData.active) label.color = Colors.accent
                    onExited: if (!ws.modelData.active) label.color = Theme.fg
                }
            }
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
            scrollProc.command = ["hyprctl", "dispatch", "hl.dsp.focus({workspace='" + dir + "'})"];
            scrollProc.running = true;
        }
    }

    Process {
        id: scrollProc
    }
}
