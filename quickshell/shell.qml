import QtQuick

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

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
        // SUPER+K layout cheat sheet (ui/KeymapOverlay.qml).
        property bool keymap: false
    }

    // qs ipc call keymap toggle -- bound to SUPER+K in hypr/hyprland.lua.
    IpcHandler {
        target: "keymap"

        function toggle(): void { state.keymap = !state.keymap }
    }

    // qs ipc call dashboard toggle -- bound to SUPER+G in hypr/hyprland.lua.
    IpcHandler {
        target: "dashboard"

        function toggle(): void { state.expanded = !state.expanded }
        function expand(): void { state.expanded = true }
        function collapse(): void { state.expanded = false }
        function status(): string { return state.expanded ? "expanded" : "collapsed" }
    }

    // SUPER+D i ask-a-quick-question overlay -- not persisted, like activePanel
    // below (transient, resets each open; AskService is what actually
    // remembers conversations across opens/closes -- see services/AskService.qml).
    property bool askOpen: false
    // Set when the hub opened Ask, so Esc steps back to the hub like the
    // hub's own pages do. Ask is its own window, not a menu page, so it
    // can't ride menuStack.
    property bool askFromHub: false
    onAskOpenChanged: if (!askOpen) askFromHub = false

    function askBack(): void {
        const back = shell.askFromHub;
        shell.askOpen = false;
        if (!back) return;
        shell.menuStack = [];
        shell.menuForward = false;
        shell.menuStep = true;
        shell.activeMenu = "hub";
    }

    // qs ipc call ask toggle -- opened from the SUPER+D hub (i). Opening
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
    // "bluetooth" | "audio" | "media" | "notifications". Not persisted across reload -- these are
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
    // GTK/rofi tool directly. Unbound now -- the bar and the SUPER+D hub open
    // these -- but kept for scripts.
    // Bluetooth/audio are pages of the SUPER+D hub now (menuWin below).
    IpcHandler {
        target: "panel"

        function toggle(name: string): void { shell.togglePanel(name); }
        function close(): void { shell.activePanel = ""; }
    }

    // qs ipc call audio cycleSink -- not bound to a key (middle-click on the
    // bar's audio module does the same); for scripts that switch output
    // without opening the panel.
    IpcHandler {
        target: "audio"

        function cycleSink(): void { Audio.cycleSink(1); }
        function prevSink(): void { Audio.cycleSink(-1); }
        function toggleMute(): void { Audio.toggleMute(); }
        function sink(): string { return Audio.sinkName; }
    }

    // Which ported rofi menu is open: "" | "launcher" | "clipboard" |
    // "wallpaper" | "power" | "exit" | "monitor" | "keybinds" | "hub", or one
    // of the hub's own pages ("network" | "bluetooth" | "audio" | "wifiqr" |
    // "media" | "quick" | "notifications"). Transient
    // like activePanel.
    property string activeMenu: ""
    // Same latch as shownPanel, for the menu window.
    property string shownMenu: ""
    onActiveMenuChanged: if (activeMenu !== "") shownMenu = activeMenu

    // Pages under the current one, for Esc to step back through: the SUPER+D
    // hub pushes itself before opening a page, so every page it reaches
    // backs out to it instead of closing. Opening a menu by keybind starts
    // a fresh (empty) stack.
    property var menuStack: []
    // Set for one page swap inside an open menu, so menuWin plays the page
    // transition instead of a fresh open; menuForward picks its direction.
    property bool menuStep: false
    property bool menuForward: true
    // The hub tile last opened, restored when a page backs out to the hub.
    property int hubIndex: 0
    // The SUPER+D search's query and cursor, restored when a page it opened
    // backs out to it. Cleared whenever the search is entered fresh.
    property string paletteQuery: ""
    property int paletteIndex: 0
    // Hub's card top in the menu window (both are "tall"), for the search to
    // line its input up with the hub's search pill. -1 until the hub has
    // been shown once; the search then just pins near the top.
    property real hubCardTop: -1

    function openMenu(name: string): void {
        shell.paletteQuery = "";
        shell.paletteIndex = 0;
        shell.menuStack = [];
        shell.menuStep = false;
        shell.activeMenu = name;
    }
    function closeMenu(): void {
        shell.menuStack = [];
        shell.activeMenu = "";
    }
    function menuPush(name: string): void {
        if (name === "launcher") {
            shell.paletteQuery = "";
            shell.paletteIndex = 0;
        }
        shell.menuStack = shell.menuStack.concat([shell.activeMenu]);
        shell.menuForward = true;
        shell.menuStep = true;
        shell.activeMenu = name;
    }
    function menuBack(): void {
        if (shell.menuStack.length === 0) {
            shell.closeMenu();
            return;
        }
        const prev = shell.menuStack[shell.menuStack.length - 1];
        shell.menuStack = shell.menuStack.slice(0, -1);
        shell.menuForward = false;
        shell.menuStep = true;
        shell.activeMenu = prev;
    }

    // What each hub tile does: pages open inside the menu window; the rest
    // are one-shot actions that close it.
    function hubSelect(key: string, index: int): void {
        shell.hubIndex = index;
        switch (key) {
        case "ask":
            shell.closeMenu();
            shell.askOpen = true;
            shell.askFromHub = true;
            AskService.startNewConversation();
            break;
        case "resize":
            shell.closeMenu();
            // Lua expression, not a classic dispatch string -- see the
            // IPC note in hypr/hyprland.lua.
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap('resize')"]);
            break;
        case "reload":
            shell.closeMenu();
            Quickshell.execDetached(["hyprctl", "reload"]);
            break;
        case "dashboard":
            shell.closeMenu();
            state.expanded = true;
            break;
        default:
            shell.menuPush(key);
        }
    }

    // qs ipc call menu toggle <name> -- bound to SUPER+D (hub) and SUPER+V
    // (clipboard) in hypr/hyprland.lua. These six were the last things still shelling out
    // to rofi; see quickshell/ui/Picker.qml. The keybinds use `toggle`, not
    // `open`: every overlay in this file closes on its own keybind the way the
    // panels and the dashboard do (rofi died on a second SUPER+D too, since
    // the bind re-ran a one-shot process). `open` stays for scripts that want
    // an idempotent open.
    IpcHandler {
        target: "menu"

        function open(name: string): void { shell.openMenu(name); }
        // A page reached from the hub counts as the hub being open, so a
        // second SUPER+D closes the whole menu from any depth.
        function toggle(name: string): void {
            const here = shell.activeMenu === name || (shell.activeMenu !== "" && shell.menuStack[0] === name);
            if (here)
                shell.closeMenu();
            else
                shell.openMenu(name);
        }
        // Opens the SUPER+D search with `query` already typed, e.g.
        // `qs ipc call menu search "=2^10"`.
        function search(query: string): void {
            // Already showing: the Loader won't rebuild it, so set it live.
            if (shell.activeMenu === "launcher" && menuLoader.item) {
                menuLoader.item.setQuery(query);
                return;
            }
            shell.menuStack = [];
            shell.menuStep = false;
            shell.paletteQuery = query;
            shell.paletteIndex = 0;
            shell.activeMenu = "launcher";
        }
        function close(): void { shell.closeMenu(); }
    }

    // Singletons are created on first use. These own IpcHandlers (and
    // NightLight reapplies its saved temperature on load), so they have to
    // exist from startup, not from whenever a page first mentions them.
    readonly property var eagerServices: [NightLight, Brightness, Recorder, Caffeine, Media]

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

            // Caffeine (services/Caffeine.qml). An inhibitor has to hang off a
            // mapped surface; the bar always is. One screen's bar is enough.
            IdleInhibitor {
                window: barWin
                enabled: Caffeine.enabled && shell.primaryBar === bar
            }

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

    // The dropdown itself: one popup window, content swapped by name. Modal
    // like every overlay here (see its HyprlandFocusGrab): a click outside
    // the card closes it.
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

        // Modal while open: Hyprland routes all pointer and keyboard input to
        // this window only, and a click anywhere else (other windows, the
        // bar, other monitors, the transparent area outside the card) just
        // clears the grab -- which closes the overlay -- instead of reaching
        // what's underneath.
        HyprlandFocusGrab {
            windows: [panelWin]
            active: shell.activePanel !== ""
            onCleared: shell.activePanel = ""
        }

        // Grabs keyboard focus the instant a panel opens (bar clicks and `qs ipc call panel
        // toggle` route here via shell.togglePanel), so the network/bluetooth panels
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
                        case "media": return mediaPanelC;
                        case "notifications": return notificationsPanelC;
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
    Component {
        id: mediaPanelC
        Panel { title: "Now playing"; MediaPanel {} }
    }
    Component {
        id: notificationsPanelC
        Panel { title: "Notifications"; NotificationCenter {} }
    }

    // Volume / mic / brightness / layout pill (ui/Osd.qml). Bottom-centre on
    // the focused monitor, Overlay layer so it shows over fullscreen video,
    // and an empty input mask: it never takes a click or focus.
    PanelWindow {
        id: osdWin
        visible: osdReveal.live
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? null

        anchors.bottom: true
        margins.bottom: Theme.osdBottom
        implicitWidth: Theme.osdW + Theme.inset * 2
        implicitHeight: Theme.osdH + Theme.inset * 2
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {}

        Reveal {
            id: osdReveal
            anchors.fill: parent
            shown: osd.shown

            Osd {
                id: osd
                anchors.fill: parent
            }
        }
    }

    // SUPER+K keyboard cheat sheet. Like the OSD: Overlay layer, empty input
    // mask, no focus -- it sits there while you type through it.
    PanelWindow {
        visible: keymapReveal.live
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? null

        anchors.bottom: true
        margins.bottom: Theme.inset
        implicitWidth: keymap.implicitWidth
        implicitHeight: keymap.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-keymap"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {}

        Reveal {
            id: keymapReveal
            anchors.fill: parent
            shown: state.keymap

            KeymapOverlay {
                id: keymap
                anchors.fill: parent
                active: state.keymap
            }
        }
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

        // Modal while open, same as panelWin's grab.
        HyprlandFocusGrab {
            windows: [dashboardWin]
            active: state.expanded
            onCleared: state.expanded = false
        }

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

    // SUPER+D i quick-question overlay. Same shape as dashboardWin above:
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

        // Modal while open, same as panelWin's grab.
        HyprlandFocusGrab {
            windows: [askWin]
            active: shell.askOpen
            onCleared: shell.askOpen = false
        }

        FocusScope {
            id: askFocus
            anchors.fill: parent
            focus: shell.askOpen

            Keys.onEscapePressed: shell.askBack()

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
        // The hub's panel pages get the taller window too: Network's join
        // form grows the card well past a menu list.
        readonly property bool tall: ["hub", "launcher", "wallpaper", "network", "bluetooth", "audio", "wifiqr", "media", "quick", "notifications"].includes(shell.shownMenu)
        implicitWidth: (shell.shownMenu === "wallpaper" ? Theme.menuWideW : Theme.menuW) + Theme.inset * 2
        implicitHeight: (menuWin.tall ? Theme.menuWideH : Theme.menuMaxH) + Theme.inset * 2

        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-menu"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        mask: Region { item: menuReveal.shown ? (menuLoader.item ?? null) : null }

        // Modal while open, same as panelWin's grab.
        HyprlandFocusGrab {
            windows: [menuWin]
            active: shell.activeMenu !== ""
            onCleared: shell.closeMenu()
        }

        FocusScope {
            id: menuFocus
            anchors.fill: parent
            focus: shell.activeMenu !== ""

            // Pages leave Esc unaccepted so it lands here: back one page if
            // the hub opened this one, otherwise close.
            Keys.onEscapePressed: shell.menuBack()

            Reveal {
                id: menuReveal
                anchors.fill: parent
                shown: shell.activeMenu !== ""

                Loader {
                    id: menuLoader
                    anchors.fill: parent
                    active: menuReveal.live

                    // A page swap inside the open menu: the new page grows
                    // in going deeper and settles down from larger going
                    // back, so moving through the hub reads as one menu
                    // rather than popups replacing each other.
                    onLoaded: {
                        if (!shell.menuStep)
                            return;
                        shell.menuStep = false;
                        pageIn.restart();
                    }

                    ParallelAnimation {
                        id: pageIn

                        NumberAnimation {
                            target: menuLoader
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Theme.durFade
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.easeOutQuint
                        }
                        NumberAnimation {
                            target: menuLoader
                            property: "scale"
                            from: shell.menuForward ? 0.94 : 1.04
                            to: 1
                            duration: Theme.durRow
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.easeOutQuint
                        }
                    }

                    sourceComponent: {
                        switch (shell.shownMenu) {
                        case "hub": return hubMenu;
                        case "network": return networkPage;
                        case "bluetooth": return bluetoothPage;
                        case "audio": return audioPage;
                        case "wifiqr": return wifiSharePage;
                        case "launcher": return launcherMenu;
                        case "clipboard": return clipboardMenu;
                        case "wallpaper": return wallpaperMenu;
                        case "power": return powerMenu;
                        case "exit": return exitMenu;
                        case "monitor": return monitorMenu;
                        case "keybinds": return keybindsMenu;
                        case "media": return mediaPage;
                        case "quick": return quickPage;
                        case "notifications": return notificationsPage;
                        default: return null;
                        }
                    }
                }
            }
        }
    }

    Component {
        id: launcherMenu
        Launcher {
            topPin: shell.hubCardTop >= 0 ? shell.hubCardTop : Theme.inset * 4
            initialQuery: shell.paletteQuery
            initialIndex: shell.paletteIndex
            onQueryEdited: text => shell.paletteQuery = text
            onCurrentIndexChanged: shell.paletteIndex = currentIndex
            onOpenPage: key => shell.hubSelect(key, shell.hubIndex)
            onCloseRequested: shell.closeMenu()
        }
    }
    Component { id: clipboardMenu; Clipboard    { onCloseRequested: shell.closeMenu() } }
    Component { id: wallpaperMenu; Wallpaper    { onCloseRequested: shell.closeMenu() } }
    Component { id: powerMenu;     PowerMenu    { onCloseRequested: shell.closeMenu() } }
    Component { id: exitMenu;      ExitConfirm  { onCloseRequested: shell.closeMenu() } }
    Component { id: monitorMenu;   MonitorPlace { onCloseRequested: shell.closeMenu() } }
    Component { id: keybindsMenu;  Keybinds     { onCloseRequested: shell.closeMenu() } }

    // SUPER+D and the bar panels it hosts as its own pages (ui/Sheet.qml).
    Component {
        id: hubMenu
        Hub {
            // Assigned once, not bound: menuStep drops back to false right
            // after the page loads, and a binding would snap the cursor home.
            Component.onCompleted: if (shell.menuStep) currentIndex = shell.hubIndex
            onCardTopChanged: if (cardTop > 0) shell.hubCardTop = cardTop
            onSelected: key => shell.hubSelect(key, currentIndex)
            onCloseRequested: shell.closeMenu()
        }
    }
    Component {
        id: networkPage
        Sheet {
            title: "Network"; glyph: "󰖩"; hue: Colors.purple
            onCloseRequested: shell.closeMenu()
            Network { onShareRequested: shell.menuPush("wifiqr") }
        }
    }
    Component {
        id: wifiSharePage
        Sheet {
            title: "Share Wi-Fi"; glyph: "󰐲"; hue: Colors.purple
            trail: ["Menu", "Network"]
            onCloseRequested: shell.closeMenu()
            WifiShare {}
        }
    }
    Component {
        id: bluetoothPage
        Sheet {
            title: "Bluetooth"; glyph: "󰂯"; hue: Colors.blue
            onCloseRequested: shell.closeMenu()
            Bluetooth {}
        }
    }
    Component {
        id: audioPage
        Sheet {
            title: "Audio"; glyph: "󰕾"; hue: Colors.orange
            onCloseRequested: shell.closeMenu()
            AudioPanel {}
        }
    }
    Component {
        id: mediaPage
        Sheet {
            title: "Now playing"; glyph: "󰝚"; hue: Theme.green
            onCloseRequested: shell.closeMenu()
            MediaPanel {}
        }
    }
    Component {
        id: quickPage
        Sheet {
            title: "Quick settings"; glyph: "󰒓"; hue: Theme.yellow
            onCloseRequested: shell.closeMenu()
            QuickSettings { onCloseRequested: shell.closeMenu() }
        }
    }
    Component {
        id: notificationsPage
        Sheet {
            title: "Notifications"; glyph: "󰂚"; hue: Colors.accent
            onCloseRequested: shell.closeMenu()
            NotificationCenter {}
        }
    }
}
