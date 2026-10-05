import QtQuick
import Quickshell.Hyprland
import ".."
import "../services"

// The volume / mic / brightness / keyboard-layout pill. The hardware keys
// still run pactl/brightnessctl themselves (or the brightness IPC); this only
// watches the result, so it shows for changes from any source -- the bar's
// scroll wheel, the Audio panel, another app.
//
// shell.qml hosts it in a click-through bottom-centre window and binds that
// window's Reveal to `shown`.
Item {
    id: root

    property bool shown: false

    // "volume" | "mic" | "brightness" | "layout"
    property string kind: "volume"
    property real value: 0
    property string glyph: ""
    property string label: ""
    property bool showBar: true
    property color hue: Colors.accent

    // Pipewire fills in volume/mute a beat after load (and again on every
    // hot reload); without this the OSD would flash on each one.
    property bool armed: false
    Timer {
        running: true
        interval: 1500
        onTriggered: root.armed = true
    }

    Timer {
        id: hide
        interval: Theme.osdTimeout
        onTriggered: root.shown = false
    }

    function show(kind: string): void {
        if (!root.armed) return;
        root.kind = kind;
        switch (kind) {
        case "volume":
            root.value = Math.min(1, Audio.volume);
            root.glyph = Audio.muted ? "󰝟" : (Audio.volume < 0.34 ? "󰕿" : (Audio.volume < 0.67 ? "󰖀" : "󰕾"));
            root.label = Audio.muted ? "Muted" : Math.round(Audio.volume * 100) + "%";
            root.showBar = !Audio.muted;
            root.hue = Audio.muted ? Theme.dim : (Audio.volume > 1 ? Theme.red : Colors.cyan);
            break;
        case "mic":
            root.glyph = Audio.micMuted ? "󰍭" : "󰍬";
            root.label = Audio.micMuted ? "Microphone muted" : "Microphone on";
            root.showBar = false;
            root.hue = Audio.micMuted ? Theme.red : Theme.green;
            break;
        case "brightness":
            root.value = Brightness.percent;
            root.glyph = "󰃠";
            root.label = Math.round(Brightness.percent * 100) + "%";
            root.showBar = true;
            root.hue = Theme.yellow;
            break;
        }
        root.shown = true;
        hide.restart();
    }

    function showLayout(name: string): void {
        if (!root.armed) return;
        const m = /\(([^)]+)\)/.exec(name);
        root.kind = "layout";
        root.glyph = "";
        root.label = name + "  ·  " + (m ? m[1].toLowerCase() : name.slice(0, 2).toLowerCase());
        root.showBar = false;
        root.hue = Theme.blueGray;
        root.shown = true;
        hide.restart();
    }

    Connections {
        target: Audio
        function onVolumeChanged() { root.show("volume"); }
        function onMutedChanged() { root.show("volume"); }
        function onMicMutedChanged() { root.show("mic"); }
    }
    Connections {
        target: Brightness
        function onChanged() { root.show("brightness"); }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return;
            const parts = event.data.split(",");
            root.showLayout(parts[parts.length - 1] ?? "");
        }
    }

    Surface {
        anchors.fill: pill
        topRadius: pill.height / 2
        bottomRadius: pill.height / 2
    }

    Item {
        id: pill
        anchors.centerIn: parent
        width: Theme.osdW
        height: Theme.osdH

        Row {
            anchors.fill: parent
            anchors.leftMargin: Math.round(18 * Theme.s)
            anchors.rightMargin: Math.round(18 * Theme.s)
            spacing: Math.round(12 * Theme.s)

            Text {
                id: g
                anchors.verticalCenter: parent.verticalCenter
                text: root.glyph
                color: root.hue
                font.family: Theme.font
                font.pixelSize: Math.round(22 * Theme.s)
            }

            Rectangle {
                id: track
                visible: root.showBar
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - g.implicitWidth - pct.width - parent.spacing * 2
                height: Math.round(6 * Theme.s)
                radius: Math.round(3 * Theme.s)
                color: Theme.track

                Rectangle {
                    width: track.width * Math.max(0, Math.min(1, root.value))
                    height: parent.height
                    radius: parent.radius
                    color: root.hue
                    Behavior on width { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
                }
            }

            Text {
                id: pct
                anchors.verticalCenter: parent.verticalCenter
                width: root.showBar ? Math.round(48 * Theme.s) : parent.width - g.implicitWidth - parent.spacing
                horizontalAlignment: root.showBar ? Text.AlignRight : Text.AlignLeft
                text: root.label
                color: Theme.fg
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: Theme.fsValue
            }
        }
    }
}
