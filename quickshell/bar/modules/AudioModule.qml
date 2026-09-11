import QtQuick
import "../.."
import "../../services"

// Ported from waybar's pulseaudio module. Scroll to nudge volume (was
// scroll-step: 2 there); click opens the Audio panel instead of launching
// pavucontrol.
Text {
    id: root

    signal clicked

    height: Theme.barHeight
    verticalAlignment: Text.AlignVCenter
    font.family: Theme.font
    font.pixelSize: Theme.fsBar
    text: Audio.muted ? "  Muted" : Audio.volumeGlyph() + "  " + Math.round(Audio.volume * 100) + "%"

    color: {
        if (Audio.muted || Audio.volume >= 1.0) return Theme.red;
        if (Audio.volume >= 0.5) return Theme.yellow;
        return Theme.green;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
        onWheel: wheel => Audio.nudgeVolume(wheel.angleDelta.y > 0 ? 0.02 : -0.02)
    }
}
