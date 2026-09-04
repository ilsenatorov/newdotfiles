import QtQuick
import ".."
import "../services"

// Replaces pavucontrol's default-sink slider. Output volume/mute only --
// pavucontrol's per-app stream routing has no equivalent here; it stays
// installed for that.
Column {
    id: root
    width: parent ? parent.width : Theme.panelW
    spacing: 10

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
}
