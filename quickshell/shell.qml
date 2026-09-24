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

    // SUPER+I ask-a-quick-question overlay -- not persisted, like activePanel
    // below (transient, resets each open; AskService is what actually
    // remembers conversations across opens/closes -- see services/AskService.qml).
    property bool askOpen: false

    // qs ipc call ask toggle -- bound to SUPER+I in hypr/hyprland.lua. Opening
    // always starts a brand-new conversation -- AskService.switchTo lets you
    // get back to an old one (Tab/Shift+Tab inside the overlay) once it's open.
    IpcHandler {
        target: "ask"

        function toggle(): void {
            shell.askOpen = !shell.askOpen;
            if (shell.askOpen) AskService.startNewConversation();
        }
        function close(): void { shell.askOpen = false; }
    }

    // Which bar dropdown (if any) is open: "" | "calendar" | "network" |
    // "bluetooth" | "audio". Not persisted across reload -- these are
    // transient, unlike the dashboard corner.
    property string activePanel: ""
    // The last non-empty activePanel: what the Loader shows, so a closing
    // panel keeps its content on screen while ui/Reveal.qml animates it out.
    property string shownPanel: ""
    // Where the open panel's droplet hangs from -- see Bar.originFromRight.
    // Looked up on every open (click or keybind alike) from the first bar;
    // every screen's bar has the same layout, so any one will do.
    property real panelOrigin: -1
    property Item primaryBar: null
    onActivePanelChanged: {
        if (activePanel === "")
            return;
        shownPanel = activePanel;
        panelOrigin = primaryBar ? primaryBar.originFromRight(activePanel) : -1;
    }

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

    // qs ipc call audio cycleSink -- bound to SUPER+SHIFT+M in hypr/hyprland.lua,
    // for switching output without opening the panel at all (SUPER+M does that,
    // and is where the full list with arrow-key picking lives).
    IpcHandler {
        target: "audio"

        function cycleSink(): void { Audio.cycleSink(1); }
        function prevSink(): void { Audio.cycleSink(-1); }
        function toggleMute(): void { Audio.toggleMute(); }
        function sink(): string { return Audio.sinkName; }
    }

    // Which ported rofi menu is open: "" | "launcher" | "clipboard" |
    // "wallpaper" | "power" | "exit" | "monitor". Transient like activePanel.
    property string activeMenu: ""
    // Same latch as shownPanel, for the menu window.
    property string shownMenu: ""
    onActiveMenuChanged: if (activeMenu !== "") shownMenu = activeMenu

    // qs ipc call menu toggle <name> -- bound to SUPER+D/V/W and SUPER+SHIFT+S/E/M
    // in hypr/hyprland.lua. These six were the last things still shelling out
    // to rofi; see quickshell/ui/Picker.qml. The keybinds use `toggle`, not
    // `open`: every overlay in this file closes on its own keybind the way the
    // panels and the dashboard do (rofi died on a second SUPER+D too, since
    // the bind re-ran a one-shot process). `open` stays for scripts that want
    // an idempotent open.
    IpcHandler {
        target: "menu"

        function open(name: string): void { shell.activeMenu = name; }
        function toggle(name: string): void { shell.activeMenu = shell.activeMenu === name ? "" : name; }
        function close(): void { shell.activeMenu = ""; }
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
                id: bar
                anchors.fill: parent
                Component.onCompleted: if (!shell.primaryBar) shell.primaryBar = bar
                Component.onDestruction: if (shell.primaryBar === bar) shell.primaryBar = null
                screen: barWin.screen
                onPanelRequested: name => shell.togglePanel(name)
            }
        }
    }

    // The dropdown itself: one popup window, content swapped by name. No
    // click-outside-to-dismiss yet -- close via the bar module that opened
    // it, or `qs ipc call panel close`.
    PanelWindow {
        id: panelWin
        visible: panelReveal.live

        anchors {
            top: true
            right: true
        }

        // Flush to the screen edge on the right and pulled up by the shadow
        // headroom on top: ui/Panel.qml pads its card back into the same
        // spot the panel always sat in.
        margins {
            top: Theme.barHeight + Theme.barMarginTop * 2 - Theme.inset
            right: 0
        }

        implicitWidth: Theme.panelW + Theme.inset + Theme.barMarginSide
        implicitHeight: Math.max(1, panelLoader.item ? panelLoader.item.implicitHeight : 1)
        color: "transparent"
        // Measured from the screen edge, not from below the bar's exclusive
        // zone: with the default mode the compositor first pushes the window
        // under the bar and the margin above then counts the bar a second
        // time, leaving the card ~a bar-height adrift. ui/Panel.qml's droplet
        // needs the card exactly barMarginTop under the pill it hangs from.
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-panel"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        // Empty while closing, so a click during the exit motion goes to
        // whatever is underneath instead of the panel on its way out.
        mask: Region { item: panelReveal.shown && panelLoader.item ? panelLoader.item.card : null }

        // Grabs keyboard focus the instant a panel opens (SUPER+N/Y/M all
        // route here via shell.togglePanel), so the network/bluetooth panels
        // are drivable with no mouse click first -- Network.qml and
        // Bluetooth.qml declare `focus: true` on their root, which this
        // scope's `focus: true` binding then activates. Escape closes
        // whatever's open -- individual panel content may intercept it first
        // (e.g. Network's password prompt cancels itself instead).
        FocusScope {
            id: panelFocus
            anchors.fill: parent
            focus: shell.activePanel !== ""

            Keys.onEscapePressed: shell.activePanel = ""

            Reveal {
                id: panelReveal
                anchors.fill: parent
                shown: shell.activePanel !== ""
                style: "morph"

                Loader {
                    id: panelLoader
                    anchors.fill: parent
                    active: panelReveal.live

                    Binding {
                        target: panelLoader.item
                        property: "reveal"
                        value: panelReveal.progress
                        when: panelLoader.item !== null
                    }
                    Binding {
                        target: panelLoader.item
                        property: "originFromRight"
                        value: shell.panelOrigin
                        when: panelLoader.item !== null
                    }

                    sourceComponent: {
                        switch (shell.shownPanel) {
                        case "calendar": return calendarPanel;
                        case "network": return networkPanel;
                        case "wifiqr": return wifiSharePanel;
                        case "bluetooth": return bluetoothPanel;
                        case "audio": return audioPanelC;
                        default: return null;
                        }
                    }
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
        Panel { title: "Network"; Network { onShareRequested: shell.activePanel = "wifiqr" } }
    }
    Component {
        id: wifiSharePanel
        Panel { title: "Share Wi-Fi"; WifiShare {} }
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

    // SUPER+G system-info overlay. Unlike the old bottom-left corner pill,
    // this is on-demand only (nothing shown at rest) and sits on the Overlay
    // layer so it draws above normal windows, not just the desktop -- a
    // fastfetch+htop-style glance at the machine from inside anything.
    PanelWindow {
        id: dashboardWin
        visible: dashReveal.live

        implicitWidth: Theme.cardW + Theme.inset * 2
        implicitHeight: Theme.cardH + Theme.inset * 2

        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-dashboard"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        mask: Region { item: dashReveal.shown ? (dashLoader.item ?? null) : null }

        // Same FocusScope + Loader + forceActiveFocus pattern as panelWin
        // above -- Escape closes it, no click needed first.
        FocusScope {
            id: dashFocus
            anchors.fill: parent
            focus: state.expanded

            Keys.onEscapePressed: state.expanded = false

            Reveal {
                id: dashReveal
                anchors.fill: parent
                shown: state.expanded

                Loader {
                    id: dashLoader
                    anchors.fill: parent
                    active: dashReveal.live
                    sourceComponent: Card {}
                }
            }
        }
    }

    // SUPER+I quick-question overlay. Same shape as dashboardWin above:
    // centered (no anchors), Overlay layer, OnDemand focus, Escape closes.
    PanelWindow {
        id: askWin
        visible: askReveal.live

        implicitWidth: Theme.askW + Theme.inset * 2
        implicitHeight: Theme.askH + Theme.inset * 2

        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-ask"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        mask: Region { item: askReveal.shown ? (askLoader.item ?? null) : null }

        FocusScope {
            id: askFocus
            anchors.fill: parent
            focus: shell.askOpen

            Keys.onEscapePressed: shell.askOpen = false

            Reveal {
                id: askReveal
                anchors.fill: parent
                shown: shell.askOpen

                Loader {
                    id: askLoader
                    anchors.fill: parent
                    active: askReveal.live
                    sourceComponent: Ask { onCloseRequested: shell.askOpen = false }
                }
            }
        }
    }

    // The six ported rofi menus. Same shape as askWin above: centered (no
    // anchors), Overlay layer, OnDemand focus, Escape closes.
    //
    // Fixed at the largest a menu can be rather than sized to its content:
    // the launcher's list changes length on every keystroke, and resizing a
    // layer-shell surface that often makes it visibly jump. The card inside
    // is what resizes; the leftover space is a click-away dismiss target.
    PanelWindow {
        id: menuWin
        visible: menuReveal.live

        // The wallpaper carousel is wider than the row-list menus; every
        // other menu keeps the old width. This changes on open, not on
        // keystrokes, which is the case the fixed sizing above guards.
        implicitWidth: (shell.shownMenu === "wallpaper" ? Theme.menuWideW : Theme.menuW) + Theme.inset * 2
        implicitHeight: (shell.shownMenu === "wallpaper" ? Theme.menuWideH : Theme.menuMaxH) + Theme.inset * 2

        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-menu"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        mask: Region { item: menuReveal.shown ? (menuLoader.item ?? null) : null }

        FocusScope {
            id: menuFocus
            anchors.fill: parent
            focus: shell.activeMenu !== ""

            Keys.onEscapePressed: shell.activeMenu = ""

            Reveal {
                id: menuReveal
                anchors.fill: parent
                shown: shell.activeMenu !== ""

                Loader {
                    id: menuLoader
                    anchors.fill: parent
                    active: menuReveal.live
                    sourceComponent: {
                        switch (shell.shownMenu) {
                        case "launcher": return launcherMenu;
                        case "clipboard": return clipboardMenu;
                        case "wallpaper": return wallpaperMenu;
                        case "power": return powerMenu;
                        case "exit": return exitMenu;
                        case "monitor": return monitorMenu;
                        default: return null;
                        }
                    }
                }
            }
        }
    }

    Component { id: launcherMenu;  Launcher     { onCloseRequested: shell.activeMenu = "" } }
    Component { id: clipboardMenu; Clipboard    { onCloseRequested: shell.activeMenu = "" } }
    Component { id: wallpaperMenu; Wallpaper    { onCloseRequested: shell.activeMenu = "" } }
    Component { id: powerMenu;     PowerMenu    { onCloseRequested: shell.activeMenu = "" } }
    Component { id: exitMenu;      ExitConfirm  { onCloseRequested: shell.activeMenu = "" } }
    Component { id: monitorMenu;   MonitorPlace { onCloseRequested: shell.activeMenu = "" } }
}
