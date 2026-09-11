import QtQuick
import "../.."
import "../../services"

// Ported from waybar's native bluetooth module -- same Material Design glyph
// set (chosen there because MD has a real crossed-out icon FontAwesome
// lacks) and the same state -> color mapping. Click opens the Bluetooth
// panel (replaces rofi-bluetooth).
Text {
    id: root

    signal clicked

    height: Theme.barHeight
    verticalAlignment: Text.AlignVCenter
    font.family: Theme.font
    font.pixelSize: Theme.fsBar
    text: {
        if (!Bt.available) return "󰂲";
        if (!Bt.powered) return "󰂲";
        if (Bt.anyConnected) return "󰂱  " + Bt.primaryConnectedName;
        return "󰂯";
    }

    color: {
        if (!Bt.available || !Bt.powered) return Theme.rule;
        if (Bt.discovering) return Theme.orange;
        if (Bt.anyConnected) return Theme.blue;
        return Theme.blueGray;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
