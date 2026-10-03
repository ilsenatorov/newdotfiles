import QtQuick
import ".."
import "../services"
import "../ui"

// SUPER+D q. The switches that don't deserve a page each: night light (with
// its temperature), caffeine, Do Not Disturb, and screen recording.
//
// Keys: ↑/↓ pick a row, Space/Enter toggle or start, ←/→ move the night-light
// temperature (on that row). Esc falls through to shell.qml.
Column {
    id: root
    width: parent ? parent.width : Theme.panelW
    spacing: 6
    focus: true

    // Recording needs the menu gone first: slurp draws its own overlay and
    // the region shouldn't have this card in it.
    signal closeRequested

    property int currentIndex: 0

    // While recording, "region" becomes Stop and "screen" goes away.
    readonly property var rows: (NightLight.available ? ["night"] : [])
        .concat(["caffeine", "dnd", "audio", "region"])
        .concat(Recorder.recording ? [] : ["screen"])

    onRowsChanged: root.currentIndex = Math.min(root.currentIndex, root.rows.length - 1)

    Component.onCompleted: root.forceActiveFocus()

    function activate(key: string): void {
        switch (key) {
        case "night": NightLight.toggle(); break;
        case "caffeine": Caffeine.toggle(); break;
        case "dnd": Notifications.toggleDnd(); break;
        case "audio": Recorder.withAudio = !Recorder.withAudio; break;
        case "region":
        case "screen":
            if (Recorder.recording) {
                Recorder.stop();
            } else {
                // Let the menu's close motion clear the screen before slurp
                // (or the first recorded frame) sees it.
                Recorder.startDelayed(key, Theme.durFast + 120);
                root.closeRequested();
            }
            break;
        }
    }

    Keys.onPressed: event => {
        const k = event.key;
        const n = root.rows.length;
        if (k === Qt.Key_Down || k === Qt.Key_J) root.currentIndex = (root.currentIndex + 1) % n;
        else if (k === Qt.Key_Up || k === Qt.Key_K) root.currentIndex = (root.currentIndex - 1 + n) % n;
        else if (k === Qt.Key_Space || k === Qt.Key_Return || k === Qt.Key_Enter) root.activate(root.rows[root.currentIndex]);
        else if ((k === Qt.Key_Left || k === Qt.Key_H) && root.rows[root.currentIndex] === "night") NightLight.nudge(-250);
        else if ((k === Qt.Key_Right || k === Qt.Key_L) && root.rows[root.currentIndex] === "night") NightLight.nudge(250);
        else return;
        event.accepted = true;
    }

    component Row_: Rectangle {
        id: r
        property string key: ""
        property string glyph: ""
        property color hue: Colors.accent
        property string label: ""
        property string sub: ""
        property bool isToggle: true
        property bool checked: false
        default property alias extra: extraCol.children
        readonly property bool current: root.rows[root.currentIndex] === key

        visible: root.rows.includes(key)
        width: root.width
        height: col.implicitHeight + 16
        radius: 8
        color: current || area.containsMouse ? Colors.surface : "transparent"
        border.width: current ? 1 : 0
        border.color: Qt.rgba(hue.r, hue.g, hue.b, 0.7)

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.currentIndex = root.rows.indexOf(r.key)
            onClicked: root.activate(r.key)
        }

        Column {
            id: col
            x: 10
            y: 8
            width: parent.width - 20
            spacing: 8

            Item {
                width: parent.width
                height: Math.max(labelCol.implicitHeight, sw.height)

                Text {
                    id: g
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(24 * Theme.s)
                    text: r.glyph
                    color: r.checked || !r.isToggle ? r.hue : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Math.round(18 * Theme.s)
                }

                Column {
                    id: labelCol
                    anchors.left: g.right
                    anchors.leftMargin: 6
                    anchors.right: sw.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        width: parent.width
                        text: r.label
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fsValue
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: text !== ""
                        width: parent.width
                        text: r.sub
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fsLabel - 2
                        elide: Text.ElideRight
                    }
                }

                Toggle {
                    id: sw
                    visible: r.isToggle
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: r.checked
                    hue: r.hue
                    onToggled: root.activate(r.key)
                }
            }

            Column {
                id: extraCol
                width: parent.width
                visible: children.length > 0
            }
        }
    }

    Row_ {
        key: "night"
        glyph: "󰖔"
        hue: Theme.orange
        label: "Night light"
        sub: NightLight.enabled ? NightLight.temperature + " K" : "Off"
        checked: NightLight.enabled

        Slider {
            width: parent.width
            value: (NightLight.temperature - NightLight.minK) / (NightLight.maxK - NightLight.minK)
            fill: NightLight.enabled ? Theme.orange : Theme.dim
            onMoved: v => NightLight.setTemperature(NightLight.minK + v * (NightLight.maxK - NightLight.minK))
        }
    }

    Row_ {
        key: "caffeine"
        glyph: "󰅶"
        hue: Theme.yellow
        label: "Caffeine"
        sub: Caffeine.enabled ? "Screen stays awake" : "Screen may sleep"
        checked: Caffeine.enabled
    }

    Row_ {
        key: "dnd"
        glyph: "󰂛"
        hue: Theme.red
        label: "Do not disturb"
        sub: Notifications.dnd ? "Only critical notifications pop up" : "Notifications pop up"
        checked: Notifications.dnd
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.rule
    }

    Row_ {
        key: "audio"
        glyph: "󰕾"
        hue: Colors.cyan
        label: "Record desktop audio"
        sub: Audio.sinkName
        checked: Recorder.withAudio
    }

    Row_ {
        key: "region"
        glyph: Recorder.recording ? "󰓛" : "󰩭"
        hue: Theme.red
        isToggle: false
        label: Recorder.recording ? "Stop recording" : "Record a region"
        sub: Recorder.recording ? "● " + Recorder.elapsedText() : "Drag a rectangle"
    }

    Row_ {
        key: "screen"
        glyph: "󰍹"
        hue: Theme.red
        isToggle: false
        label: "Record the screen"
        sub: "Focused monitor"
    }

    Text {
        width: parent.width
        topPadding: 4
        text: "↑↓ pick · space toggle" + (NightLight.available ? " · ←→ temperature" : "")
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel - 1
    }
}
