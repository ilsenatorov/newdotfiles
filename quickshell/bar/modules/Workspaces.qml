import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../.."
import "../../ui"

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

                width: map.implicitWidth + 12
                height: Theme.barHeight - 8
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                radius: 8
                color: modelData.active ? Colors.surface : "transparent"

                WorkspaceMap {
                    id: map
                    anchors.centerIn: parent
                    workspace: ws.modelData
                    active: ws.modelData.active
                    highlighted: hover.containsMouse
                }

                // Number laid over the minimap, faint enough that the
                // windows still read through it. The outline keeps it
                // legible on the solid focused-window cell.
                Text {
                    anchors.centerIn: map
                    text: ws.modelData.name
                    font.family: Theme.font
                    font.pixelSize: Theme.fsBar
                    font.bold: true
                    style: Text.Outline
                    styleColor: Qt.rgba(Theme.windowShadow.r, Theme.windowShadow.g, Theme.windowShadow.b, 0.6)
                    color: ws.modelData.urgent ? Theme.red
                        : ws.modelData.active || hover.containsMouse ? Colors.accent : Theme.fg
                    opacity: ws.modelData.active || hover.containsMouse ? 0.8 : 0.55
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    onClicked: {
                        root.previewPill = null;
                        root.dispatch("hl.dsp.focus({workspace=" + ws.modelData.id + "})");
                    }
                    onEntered: root.hover(ws)
                    onExited: root.unhover(ws)
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

    // ---- hover preview --------------------------------------------------
    // Resting on a pill opens a big WorkspaceMap under it with app icons and
    // window titles. Once open it follows the mouse across pills with no
    // delay; it is click-through (empty mask) so it never steals the hover.
    property Item hoveredPill: null
    property Item previewPill: null
    // Last non-null previewPill, so the closing preview keeps its content
    // while ui/Reveal.qml animates it out (same latch as shell.shownPanel).
    property Item shownPill: null
    // Screen x of shownPill's centre. mapToItem isn't a binding, so it is
    // measured whenever the preview moves to a pill.
    property real previewX: 0
    onPreviewPillChanged: {
        if (!previewPill) return;
        shownPill = previewPill;
        previewX = Theme.barMarginSide + previewPill.mapToItem(null, previewPill.width / 2, 0).x;
    }

    function hover(pill: Item): void {
        hoveredPill = pill;
        closeDelay.stop();
        if (previewPill) previewPill = pill;
        else openDelay.restart();
    }
    function unhover(pill: Item): void {
        if (hoveredPill !== pill) return;
        hoveredPill = null;
        openDelay.stop();
        closeDelay.restart();
    }

    Timer {
        id: openDelay
        interval: 350
        onTriggered: root.previewPill = root.hoveredPill
    }
    // Bridges the 2px gaps between pills so moving along the row doesn't
    // flicker the preview shut.
    Timer {
        id: closeDelay
        interval: 120
        onTriggered: if (!root.hoveredPill) root.previewPill = null
    }

    // A layer-shell window, not a PopupWindow: Hyprland routes the pointer
    // to an open xdg_popup, so the pills stopped seeing hover (the preview
    // could neither follow nor close). An empty-mask layer surface is fully
    // click- and hover-through.
    PanelWindow {
        id: preview

        readonly property var workspace: root.shownPill ? root.shownPill.modelData : null
        readonly property int mapH: Math.round(170 * Theme.s)

        screen: root.screen
        visible: previewReveal.live && root.shownPill !== null
        color: "transparent"
        mask: Region {}
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-panel"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Centred under the pill, with the card one barMarginTop below the
        // bar like the dropdown panels (minus the Surface's shadow headroom).
        anchors { top: true; left: true }
        margins {
            top: Theme.barHeight + Theme.barMarginTop * 2 - Theme.inset
            left: Math.max(0, root.previewX - preview.implicitWidth / 2)
        }

        implicitWidth: previewMap.implicitWidth + 24 + Theme.inset * 2
        implicitHeight: previewCol.implicitHeight + 20 + Theme.inset * 2

        Reveal {
            id: previewReveal
            anchors.fill: parent
            shown: root.previewPill !== null
            style: "drop"
            transformOrigin: Item.Top

            Surface {
                anchors.fill: parent
                anchors.margins: Theme.inset
            }

            Column {
                id: previewCol
                x: Theme.inset + 12
                y: Theme.inset + 10
                spacing: 8

                Row {
                    spacing: 8

                    Text {
                        text: "Workspace " + (preview.workspace ? preview.workspace.name : "")
                        font.family: Theme.font
                        font.pixelSize: Theme.fsLabel
                        font.bold: true
                        color: Colors.accent
                    }
                    Text {
                        readonly property int n: preview.workspace ? preview.workspace.toplevels.values.length : 0
                        anchors.baseline: parent.children[0].baseline
                        text: n === 0 ? "empty" : n + (n === 1 ? " window" : " windows")
                        font.family: Theme.font
                        font.pixelSize: Theme.fsLabel - 2
                        color: Theme.dim
                    }
                }

                WorkspaceMap {
                    id: previewMap
                    workspace: preview.workspace
                    detailed: true
                    implicitHeight: preview.mapH
                }
            }
        }
    }

    // WorkspaceMap reads window geometry from each toplevel's lastIpcObject,
    // which Quickshell only updates on refreshToplevels(). Refresh (debounced)
    // on events that move windows, and poll slowly as well: Hyprland emits no
    // event for a resize.
    readonly property var layoutEvents: [
        "openwindow", "closewindow", "movewindowv2", "changefloatingmode",
        "fullscreen", "activewindowv2", "workspacev2", "moveworkspacev2",
        "togglegroup", "moveintogroup", "moveoutofgroup", "pin", "minimized"
    ]

    Timer {
        id: refreshToplevels
        interval: 60
        onTriggered: Hyprland.refreshToplevels()
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: Hyprland.refreshToplevels()
    }

    Component.onCompleted: {
        Hyprland.refreshMonitors();
        Hyprland.refreshToplevels();
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "submap") root.submap = event.data;
            else if (root.layoutEvents.includes(event.name)) refreshToplevels.restart();
            else if (["monitoraddedv2", "monitorremovedv2", "configreloaded"].includes(event.name))
                Hyprland.refreshMonitors();
        }
    }
}
