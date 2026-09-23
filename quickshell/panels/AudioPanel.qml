import QtQuick
import ".."
import "../services"

// Replaces pavucontrol's default-sink slider and its Output Devices tab.
// Volume/mute plus output switching -- pavucontrol's *per-app* stream
// routing still has no equivalent here; it stays installed for that.
//
// Fully keyboard-drivable, same contract as Bluetooth.qml: Up/Down move the
// selection through the output devices, Enter makes the selected one the
// default sink, Left/Right nudge the volume, M toggles mute. shell.qml grabs
// keyboard focus onto this root the moment the panel is toggled open.
Column {
    id: root
    width: parent ? parent.width : Theme.panelW
    spacing: 10
    focus: true

    // Starts on the *active* output rather than at -1, so Enter is never a
    // surprise and Down from a fresh open steps to the next real candidate.
    property int currentIndex: Audio.sinkIndex

    // Devices come and go (a headset unplugs); keep the cursor on something.
    onCurrentIndexChanged: {
        if (root.currentIndex >= Audio.sinks.length)
            root.currentIndex = Audio.sinks.length - 1;
    }

    // See Network.qml's Component.onCompleted for why this is needed on top
    // of `focus: true` -- without it the keys silently do nothing.
    Component.onCompleted: root.forceActiveFocus()

    Keys.onDownPressed: {
        const count = Audio.sinks.length;
        if (count > 0) root.currentIndex = (root.currentIndex + 1) % count;
    }
    Keys.onUpPressed: {
        const count = Audio.sinks.length;
        if (count > 0) root.currentIndex = (root.currentIndex - 1 + count) % count;
    }
    Keys.onReturnPressed: root.activateCurrent()
    Keys.onEnterPressed: root.activateCurrent()
    Keys.onLeftPressed: Audio.nudgeVolume(-0.02)
    Keys.onRightPressed: Audio.nudgeVolume(0.02)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_M) {
            Audio.toggleMute();
            event.accepted = true;
        }
    }

    function activateCurrent(): void {
        if (root.currentIndex < 0 || root.currentIndex >= Audio.sinks.length) return;
        Audio.setSink(Audio.sinks[root.currentIndex]);
    }

    Text {
        text: Audio.sinkName !== "" ? Audio.sinkName : "No output device"
        font.family: Theme.font
        font.pixelSize: Theme.fsValue
        color: Theme.fg
        elide: Text.ElideRight
        width: parent.width
    }

    Row {
        width: parent.width
        spacing: 8

        Text {
            text: Audio.volumeGlyph()
            font.family: Theme.font
            font.pixelSize: Theme.fsValue
            color: Colors.accent
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            id: track
            width: parent.width - 70
            height: 8
            radius: 4
            color: Theme.track
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: track.width * Math.min(1, Audio.volume)
                height: track.height
                radius: track.radius
                color: Audio.muted ? Theme.dim : Colors.accent
            }

            MouseArea {
                anchors.fill: parent
                onPressed: mouse => Audio.setVolume(mouse.x / track.width)
                onPositionChanged: mouse => { if (pressed) Audio.setVolume(mouse.x / track.width); }
            }
        }

        Text {
            text: Math.round(Math.min(1, Audio.volume) * 100) + "%"
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
            color: Theme.dim
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Rectangle {
        width: 80
        height: 26
        radius: 8
        color: Audio.muted ? Colors.accent : "transparent"
        border.width: 1
        border.color: Theme.rule

        Text {
            anchors.centerIn: parent
            text: Audio.muted ? "Unmute" : "Mute"
            color: Audio.muted ? Theme.surface : Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
        }

        MouseArea { anchors.fill: parent; onClicked: Audio.toggleMute() }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.rule
    }

    Text {
        text: "Output"
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
        font.bold: true
        color: Theme.dim
    }

    // A Repeater in a Column, like the other bar panels -- the device count
    // is small and fixed by hardware, so there is nothing here to scroll.
    Repeater {
        model: Audio.sinks

        Rectangle {
            id: sinkRow
            required property var modelData
            required property int index

            readonly property bool active: sinkRow.modelData === Audio.sink

            width: root.width
            height: 34
            radius: 8
            color: (sinkArea.containsMouse || sinkRow.index === root.currentIndex) ? Colors.surface : "transparent"
            border.width: sinkRow.index === root.currentIndex ? 1 : 0
            border.color: Colors.accent

            Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                Text {
                    text: sinkRow.active ? "󰓃" : "󰕿"
                    color: sinkRow.active ? Colors.accent : Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    width: parent.width - 60
                    text: Audio.nodeLabel(sinkRow.modelData)
                    color: sinkRow.active ? Colors.accent : Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: sinkArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    root.currentIndex = sinkRow.index;
                    root.activateCurrent();
                }
            }
        }
    }

    Text {
        visible: Audio.sinks.length === 0
        text: "No output devices"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
    }

    Text {
        visible: Audio.sinks.length > 0
        text: "↑↓ pick output · Enter switch · ←→ volume · M mute"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel - 1
    }
}
