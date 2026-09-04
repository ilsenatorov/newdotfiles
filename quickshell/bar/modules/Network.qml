import QtQuick
import "../.."
import "../../services"

// Wired/wifi/disconnected, one glyph -- replaces waybar's network#wired and
// network#wireless modules (which hid/showed each other based on link type)
// with a single module over the Net service. Click opens the Network panel.
Text {
    id: root

    signal clicked

    height: Theme.barHeight
    verticalAlignment: Text.AlignVCenter
    font.family: Theme.font
    font.pixelSize: Theme.fsBar

    text: {
        if (Net.wired) return "  ";
        if (Net.wifiConnected) return Net.signalGlyph(Net.signalStrength) + "  " + Net.ssid;
        if (!Net.wifiHardwareEnabled) return "󰤮 ";
        return "󰖪 ";
    }

    color: Net.connected ? Theme.purple : Theme.orange

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
