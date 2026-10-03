import QtQuick
import Quickshell
import ".."
import "../services"
import "../ui"

// SUPER+D. One menu for everything that used to have its own SUPER+<letter>
// before the top row went to workspaces (see hypr/hyprland.lua): a grid of
// tiles, each with a live one-line status, your most-used apps under it, and
// a search (d) over apps, pages, toggles and power (panels/Launcher.qml).
// Pages open in the same window (shell.qml's menuWin) and Esc steps back
// here, so it reads as one menu rather than a launcher for other popups.
//
// Keys: the tile's letter opens it directly; d searches; 1-9, 0 launch the
// apps grid; arrows/hjkl move, ↵/Space open. The letters avoid h/j/k/l so
// navigation and mnemonics never collide.
Item {
    id: root

    signal selected(string key)
    signal closeRequested

    // Where the card's top edge sits in the window -- the search pins its
    // input there, so `d` reads as the pill turning into the search box.
    readonly property real cardTop: card.y

    readonly property int cols: 3
    readonly property int tileW: Math.round(148 * Theme.s)
    readonly property int tileH: Math.round(92 * Theme.s)
    readonly property int gap: Math.round(8 * Theme.s)
    // shell.qml hands back the tile a page was opened from, so Esc out of
    // a page lands the cursor where it left.
    property int currentIndex: homeIndex
    // Where the cursor starts on a fresh open: the grid's middle tile
    // (upper-middle when the row count is even).
    readonly property int homeIndex: Math.floor((Math.ceil(items.length / cols) - 1) / 2) * cols + Math.floor(cols / 2)
    readonly property int appCols: 5
    readonly property int appMax: 10

    readonly property var items: [
        { key: "network",   label: "Network",   glyph: "󰖩", hint: "n" },
        { key: "bluetooth", label: "Bluetooth", glyph: "󰂯", hint: "b" },
        { key: "audio",     label: "Audio",     glyph: "󰕾", hint: "a" },
        { key: "media",     label: "Media",     glyph: "󰝚", hint: "s" },
        { key: "notifications", label: "Notifications", glyph: "󰂚", hint: "o" },
        { key: "quick",     label: "Quick",     glyph: "󰒓", hint: "q" },
        { key: "monitor",   label: "Displays",  glyph: "󰍹", hint: "m" },
        { key: "wallpaper", label: "Wallpaper", glyph: "󰸉", hint: "w" },
        { key: "ask",       label: "Ask",       glyph: "󰚩", hint: "i" },
        { key: "resize",    label: "Resize",    glyph: "󰩨", hint: "r" },
        { key: "reload",    label: "Reload",    glyph: "󰑓", hint: "c" },
        { key: "power",     label: "Power",     glyph: "󰐥", hint: "p" }
    ]

    // Looked up per tile rather than stored in `items`: a binding inside
    // that array would rebuild every delegate whenever the volume moved.
    function hueFor(key: string): color {
        switch (key) {
        case "network": return Colors.purple;
        case "bluetooth": return Colors.blue;
        case "audio": return Colors.orange;
        case "media": return Theme.green;
        case "notifications": return Colors.accent;
        case "quick": return Theme.yellow;
        case "monitor": return Colors.cyan;
        case "wallpaper": return Colors.accent;
        case "ask": return Colors.accentAlt;
        case "resize": return Colors.green;
        case "reload": return Theme.yellow;
        case "power": return Colors.red;
        }
        return Colors.accent;
    }

    // Shared with the search palette -- see services/HubStatus.qml.
    function statusFor(key: string): string {
        return HubStatus.statusFor(key);
    }

    // The ten apps launched most from the search, most-used first. Hub pages
    // and toggles are counted too ("palette:..." ids) but aren't apps.
    readonly property var recent: {
        const apps = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        const byId = {};
        for (const a of apps)
            if (!a.noDisplay) byId[a.id] = a;
        return Object.keys(LauncherUsage.entries)
            .filter(id => !id.startsWith("palette:") && byId[id])
            .sort((a, b) => (LauncherUsage.countFor(b) - LauncherUsage.countFor(a)) || (LauncherUsage.lastFor(b) - LauncherUsage.lastFor(a)))
            .slice(0, root.appMax)
            .map(id => byId[id]);
    }

    function launch(entry: var): void {
        LauncherUsage.record(entry.id);
        entry.execute();
        root.closeRequested();
    }

    function move(delta: int): void {
        const n = root.items.length;
        root.currentIndex = (root.currentIndex + delta + n) % n;
    }

    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Tab) root.move(1);
        else if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Backtab) root.move(-1);
        else if (k === Qt.Key_Down || k === Qt.Key_J) root.move(root.cols);
        else if (k === Qt.Key_Up || k === Qt.Key_K) root.move(-root.cols);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.selected(root.items[root.currentIndex].key);
        else {
            // Esc and anything unbound fall through to shell.qml.
            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                return;
            // ? isn't a tile (the grid is full) -- it opens the keybind list.
            if (event.text === "?") {
                root.selected("keybinds");
                event.accepted = true;
                return;
            }
            // d: the search -- so launching a program is SUPER+D, d, type.
            if (event.text.toLowerCase() === "d") {
                root.selected("launcher");
                event.accepted = true;
                return;
            }
            // 1-9 then 0, in keyboard order.
            const digit = /^[0-9]$/.test(event.text) ? (Number(event.text) + 9) % 10 : -1;
            if (digit >= 0) {
                if (digit < root.recent.length)
                    root.launch(root.recent[digit]);
                event.accepted = true;
                return;
            }
            const hit = root.items.find(it => it.hint === event.text.toLowerCase());
            if (!hit)
                return;
            root.currentIndex = root.items.indexOf(hit);
            root.selected(hit.key);
        }
        event.accepted = true;
    }

    focus: true
    // Same Loader focus race ui/Picker.qml works around.
    Component.onCompleted: root.forceActiveFocus()

    // True for the opening moment only, so the tile cascade plays once.
    property bool intro: true
    Timer {
        running: true
        interval: 250
        onTriggered: root.intro = false
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    Surface {
        anchors.fill: card
    }

    Item {
        id: card

        anchors.centerIn: parent
        width: grid.width + Theme.pad * 1.5
        height: col.implicitHeight + Theme.pad * 1.5

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: col

            anchors.centerIn: parent
            spacing: 12

            // Looks like the search box it opens, so the way in is visible.
            Rectangle {
                width: grid.width
                height: searchLabel.implicitHeight + 16
                radius: Theme.radius / 2
                color: searchArea.containsMouse ? Colors.surface : Theme.surface
                border.width: 1
                border.color: Theme.rule

                Text {
                    id: searchLabel
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍉  Search apps, settings, actions"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(20 * Theme.s)
                    height: width
                    radius: 5
                    color: Theme.track

                    Text {
                        anchors.centerIn: parent
                        text: "d"
                        color: Colors.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.fsLabel - 2
                    }
                }

                MouseArea {
                    id: searchArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected("launcher")
                }
            }

            Grid {
                id: grid

                columns: root.cols
                spacing: root.gap

                Repeater {
                    model: root.items

                    Rectangle {
                        id: tile

                        required property int index
                        required property var modelData
                        readonly property bool current: index === root.currentIndex
                        readonly property color hue: root.hueFor(modelData.key)

                        width: root.tileW
                        height: root.tileH
                        radius: Theme.radius * 0.75
                        color: current ? Colors.surface : "transparent"
                        border.width: 1
                        border.color: current ? Qt.rgba(hue.r, hue.g, hue.b, 0.7) : Theme.divider

                        Behavior on color { ColorAnimation { duration: Theme.durHover } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durHover } }

                        // Cascade in behind ui/Reveal.qml's pop, like the
                        // rows in ui/Picker.qml.
                        transform: Translate { id: shift }
                        Component.onCompleted: if (root.intro) tileIn.start()

                        SequentialAnimation {
                            id: tileIn

                            ScriptAction {
                                script: {
                                    tile.opacity = 0;
                                    shift.y = 6;
                                }
                            }
                            PauseAnimation { duration: tile.index * 22 }
                            ParallelAnimation {
                                NumberAnimation {
                                    target: tile
                                    property: "opacity"
                                    to: 1
                                    duration: Theme.durRow
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.easeOutQuint
                                }
                                NumberAnimation {
                                    target: shift
                                    property: "y"
                                    to: 0
                                    duration: Theme.durRow
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.easeOutQuint
                                }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.leftMargin: 12
                            anchors.topMargin: 10
                            text: tile.modelData.glyph
                            color: tile.hue
                            opacity: tile.current ? 1 : 0.75
                            font.family: Theme.font
                            font.pixelSize: Math.round(26 * Theme.s)

                            Behavior on opacity { NumberAnimation { duration: Theme.durHover } }
                        }

                        // Mnemonic badge.
                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            width: Math.round(20 * Theme.s)
                            height: width
                            radius: 5
                            color: tile.current ? Qt.rgba(tile.hue.r, tile.hue.g, tile.hue.b, 0.2) : Theme.track

                            Text {
                                anchors.centerIn: parent
                                text: tile.modelData.hint
                                color: tile.current ? tile.hue : Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fsLabel - 2
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            anchors.bottomMargin: 10
                            spacing: 1

                            Text {
                                width: parent.width
                                text: tile.modelData.label
                                color: tile.current ? Theme.fg : Qt.lighter(Theme.dim, 1.15)
                                elide: Text.ElideRight
                                font.family: Theme.font
                                font.pixelSize: Theme.fsValue
                            }

                            Text {
                                width: parent.width
                                text: root.statusFor(tile.modelData.key)
                                color: Theme.dim
                                elide: Text.ElideRight
                                font.family: Theme.font
                                font.pixelSize: Theme.fsLabel - 2
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.currentIndex = tile.index
                            onClicked: root.selected(tile.modelData.key)
                        }
                    }
                }
            }

            // Most-used apps, 1-9 then 0, two rows of five. Hidden until
            // something has been launched from the search at least once.
            Grid {
                visible: root.recent.length > 0
                columns: root.appCols
                spacing: root.gap

                Repeater {
                    model: root.recent

                    Rectangle {
                        id: app

                        required property var modelData
                        required property int index

                        width: (grid.width - root.gap * (root.appCols - 1)) / root.appCols
                        height: Math.round(64 * Theme.s)
                        radius: Theme.radius * 0.75
                        color: appArea.containsMouse ? Colors.surface : "transparent"
                        border.width: 1
                        border.color: Theme.divider

                        // Apps whose .desktop names an icon this theme
                        // lacks get a generic glyph instead of a hole.
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 8
                            visible: appIcon.status !== Image.Ready
                            text: "󰀻"
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Math.round(24 * Theme.s)
                        }

                        Image {
                            id: appIcon
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 8
                            width: Math.round(28 * Theme.s)
                            height: width
                            sourceSize.width: width * 2
                            sourceSize.height: height * 2
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            source: Quickshell.iconPath(app.modelData.icon ?? "", true)
                        }

                        Text {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 8
                            horizontalAlignment: Text.AlignHCenter
                            text: app.modelData.name
                            elide: Text.ElideRight
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fsLabel - 3
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 5
                            text: String((app.index + 1) % 10)
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fsLabel - 3
                        }

                        MouseArea {
                            id: appArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launch(app.modelData)
                        }
                    }
                }
            }

            Text {
                width: grid.width
                horizontalAlignment: Text.AlignHCenter
                text: "letter open · d search" + (root.recent.length > 0 ? " · 1–" + root.recent.length % 10 + " apps" : "") + " · ? keys · esc close"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel - 2
            }
        }
    }
}
