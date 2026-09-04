import QtQuick

import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "services"
import "dashboard"
import "bar"

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

    // The bar is always on screen now (it wasn't, before this migration --
    // only the dashboard corner was), so there is always something to poll
    // for. Fast stays permanently on rather than gated on state.expanded.
    Binding {
        target: SysMon
        property: "fast"
        value: true
    }

    // One bar per connected screen, replacing waybar (which had no `output`
    // filter and so spawned on every monitor too).
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWin
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            margins {
                top: Theme.barMarginTop
                left: Theme.barMarginSide
                right: Theme.barMarginSide
            }

            implicitHeight: Theme.barHeight
            color: "transparent"
            // Reserve the bar's own height plus its top margin so window
            // gaps (hyprland.lua's gaps_out) don't creep under it.
            exclusiveZone: Theme.barHeight + Theme.barMarginTop

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell-bar"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Bar {
                anchors.fill: parent
                // Panel opening is wired once the panel host lands (see
                // panels/) -- until then this is a documented no-op.
                onPanelRequested: name => console.log("panel requested:", name)
            }
        }
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
