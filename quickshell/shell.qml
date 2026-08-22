import QtQuick

import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: shell

    // Survives the hot reload matugen triggers when it rewrites Colors.qml.
    // Without this the card would snap shut on every wallpaper change.
    PersistentProperties {
        id: state
        reloadableId: "dashboardState"

        property bool expanded: false
    }

    // qs ipc call dashboard toggle -- bound to SUPER+G in hypr/hyprland.lua.
    IpcHandler {
        target: "dashboard"

        function toggle(): void { state.expanded = !state.expanded }
        function expand(): void { state.expanded = true }
        function collapse(): void { state.expanded = false }
        function status(): string { return state.expanded ? "expanded" : "collapsed" }
    }

    // Poll fast only while the gauges are actually on screen. This has to be a
    // binding rather than an onExpandedChanged handler, or a session that starts
    // expanded never leaves the slow interval.
    Binding {
        target: SysMon
        property: "fast"
        value: state.expanded
    }

    PanelWindow {
        id: win

        anchors {
            left: true
            bottom: true
        }

        margins {
            left: 8
            bottom: 8
        }

        // Deliberately fixed. A layer-shell surface renegotiates geometry with the
        // compositor on every size change, so animating this would mean a round
        // trip per frame -- the card inside animates instead, and the inset gives
        // its overshoot and shadow room to render.
        implicitWidth: Theme.cardW + Theme.inset * 2
        // Sized for the card at its tallest (now-playing row present) so the
        // surface never has to renegotiate geometry when a track starts.
        implicitHeight: Theme.cardH + Theme.npRow + Theme.inset * 2

        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell-dashboard"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Only the card takes clicks; the rest of the corner stays click-through.
        mask: Region { item: card }

        Card {
            id: card

            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Theme.inset

            expanded: state.expanded
            onToggleRequested: state.expanded = !state.expanded
        }
    }
}
