import QtQuick
import Quickshell
import ".."
import "../services"
import "../ui"

// SUPER+M. One menu for everything that used to have its own SUPER+<letter>
// before the top row went to workspaces (see hypr/hyprland.lua): a grid of
// tiles, each with a live one-line status. Pages open in the same window
// (shell.qml's menuWin) and Esc steps back here, so it reads as one menu
// rather than a launcher for other popups.
//
// Keys: the tile's letter opens it directly; arrows/hjkl move, ↵/Space open.
// The letters avoid h/j/k/l so navigation and mnemonics never collide.
Item {
    id: root

    signal selected(string key)
    signal closeRequested

    readonly property int cols: 3
    readonly property int tileW: Math.round(148 * Theme.s)
    readonly property int tileH: Math.round(92 * Theme.s)
    readonly property int gap: Math.round(8 * Theme.s)
    // shell.qml hands back the tile a page was opened from, so Esc out of
    // a page lands the cursor where it left.
    property int currentIndex: 0

    readonly property var items: [
        { key: "network",   label: "Network",   glyph: "󰖩", hint: "n" },
        { key: "bluetooth", label: "Bluetooth", glyph: "󰂯", hint: "b" },
        { key: "audio",     label: "Audio",     glyph: "󰕾", hint: "a" },
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
        case "monitor": return Colors.cyan;
        case "wallpaper": return Colors.accent;
        case "ask": return Colors.accentAlt;
        case "resize": return Colors.green;
        case "reload": return Theme.yellow;
        case "power": return Colors.red;
        }
        return Colors.accent;
    }

    function statusFor(key: string): string {
        switch (key) {
        case "network":
            if (Net.wired) return "Ethernet";
            if (Net.wifiConnected) return Net.ssid;
            return Net.wifiEnabled ? "Disconnected" : "Wi-Fi off";
        case "bluetooth":
            if (!Bt.available) return "Unavailable";
            if (!Bt.powered) return "Off";
            return Bt.anyConnected ? Bt.primaryConnectedName : "On";
        case "audio":
            return Audio.muted ? "Muted" : Math.round(Audio.volume * 100) + "%  " + Audio.sinkName;
        case "monitor": {
            const n = Quickshell.screens.length;
            return n + (n === 1 ? " display" : " displays");
        }
        case "wallpaper": return "Pick & recolor";
        case "ask": return "Quick question";
        case "resize": return "Arrows, then Esc";
        case "reload": return "Hyprland config";
        case "power": return "Lock, sleep, off";
        }
        return "";
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
            const hit = root.items.find(it => it.hint === event.text.toLowerCase());
            if (!hit || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
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

            Item {
                width: grid.width
                height: title.implicitHeight

                Text {
                    id: title
                    text: "󰍜  Menu"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel
                    font.bold: true
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "letter or ↵ open   esc close"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel - 2
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
        }
    }
}
