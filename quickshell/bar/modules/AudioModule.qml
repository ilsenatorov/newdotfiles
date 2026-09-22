import QtQuick
import "../.."
import "../../services"

// Ported from waybar's pulseaudio module. Scroll to nudge volume (was
// scroll-step: 2 there); click opens the Audio panel instead of launching
// pavucontrol; middle-click cycles to the next output device without
// opening anything (waybar had no equivalent -- that was a pavucontrol trip).
Text {
    id: root

    signal clicked

    height: Theme.barHeight
    verticalAlignment: Text.AlignVCenter
    font.family: Theme.font
    font.pixelSize: Theme.fsBar
    text: Audio.muted ? "  Muted" : Audio.volumeGlyph() + "  " + Math.round(Audio.volume * 100) + "%"

    color: {
        if (Audio.muted) return Theme.dim;
        if (Audio.volume >= 1.0) return Theme.red;
        return Colors.cyan;
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) Audio.cycleSink(1);
            else root.clicked();
        }
        onWheel: wheel => Audio.nudgeVolume(wheel.angleDelta.y > 0 ? 0.02 : -0.02)
    }
}
