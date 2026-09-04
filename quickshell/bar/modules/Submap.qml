import QtQuick
import Quickshell.Hyprland
import "../.."

// Shows the active resize/move submap, same as waybar's hyprland/submap
// module. Read-only: listens to Hyprland's socket2 event stream directly
// rather than going through Quickshell.Hyprland's dispatch path, so the
// Lua-config dispatch quirk (see Workspaces.qml) never applies here.
Text {
    id: root

    property string submap: ""

    visible: submap !== ""
    text: "  " + submap
    height: Theme.barHeight
    verticalAlignment: Text.AlignVCenter
    font.family: Theme.font
    font.pixelSize: Theme.fsBar
    color: Theme.yellow

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "submap") root.submap = event.data;
        }
    }
}
