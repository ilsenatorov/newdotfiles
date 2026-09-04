import QtQuick

import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "services"
import "dashboard"
import "bar"
import "ui"
import "panels"

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

    // Which bar dropdown (if any) is open: "" | "calendar" | "network" |
    // "bluetooth" | "audio". Not persisted across reload -- these are
    // transient, unlike the dashboard corner.
    property string activePanel: ""

    function togglePanel(name: string): void {
        shell.activePanel = shell.activePanel === name ? "" : name;
    }

    // qs ipc call panel toggle <name> -- for keybinds that used to launch a
    // GTK/rofi tool directly (SUPER+N network, SUPER+Y bluetooth, SUPER+A
    // audio -- see hypr/hyprland.lua).
    IpcHandler {
        target: "panel"

        function toggle(name: string): void { shell.togglePanel(name); }
        function close(): void { shell.activePanel = ""; }
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
                onPanelRequested: name => shell.togglePanel(name)
            }
        }
    }

    // The dropdown itself: one popup window, content swapped by name. No
    // click-outside-to-dismiss yet -- close via the bar module that opened
    // it, or `qs ipc call panel close`.
    PanelWindow {
        id: panelWin
        visible: shell.activePanel !== ""

        anchors {
            top: true
            right: true
        }

        margins {
            top: Theme.barHeight + Theme.barMarginTop * 2
            right: Theme.barMarginSide
        }

        implicitWidth: Theme.panelW
        implicitHeight: Math.max(1, panelLoader.item ? panelLoader.item.implicitHeight : 1)
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-panel"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        mask: Region { item: panelLoader.item ?? null }

        Loader {
            id: panelLoader
            active: shell.activePanel !== ""

            sourceComponent: {
                switch (shell.activePanel) {
                case "calendar": return calendarPanel;
                case "network": return networkPanel;
                case "bluetooth": return bluetoothPanel;
                case "audio": return audioPanelC;
                default: return null;
                }
            }
        }
    }

    Component {
        id: calendarPanel
        Panel { title: "Calendar"; Calendar {} }
    }
    Component {
        id: networkPanel
        Panel { title: "Wi-Fi"; Network {} }
    }
    Component {
        id: bluetoothPanel
        Panel { title: "Bluetooth"; Bluetooth {} }
    }
    Component {
        id: audioPanelC
        Panel { title: "Audio"; AudioPanel {} }
    }

    // Notification overlay -- replaces mako. Single instance on the primary
    // screen (mako shows on the focused output only, not every monitor, so
    // this deliberately isn't a per-screen Variants like the bar). mako ran
    // layer=overlay, anchor=top-right, margin=6; mirrored below. Only the
    // toasts themselves take clicks (mask), same click-through-elsewhere
    // behaviour the bar and dashboard already have.
    PanelWindow {
        id: notifWin

        anchors {
            top: true
            right: true
        }

        margins {
            top: Theme.notifMargin
            right: Theme.notifMargin
        }

        implicitWidth: Theme.notifWidth
        implicitHeight: Math.max(1, stack.implicitHeight)
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-notifications"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region { item: stack }

        NotificationStack {
            id: stack
            anchors.top: parent.top
            anchors.right: parent.right
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
