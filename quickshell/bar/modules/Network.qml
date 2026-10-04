import QtQuick
import "../.."
import "../../services"

// Link glyph + connection name: ethernet plug and the NM profile name when
// wired, signal bars and the SSID on wifi. Replaces waybar's network#wired
// and network#wireless modules with a single module over the Net service.
// Click opens the Network panel.
Text {
    id: root

    signal clicked

    height: Theme.barHeight
    width: Math.min(implicitWidth, Theme.mediaTitleMaxW)
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    font.family: Theme.font
    font.pixelSize: Theme.fsBar

    text: {
        if (Net.wired) return "󰈀 " + Net.wiredDevice.connection;
        if (Net.wifiConnected) return Net.signalGlyph(Net.signalStrength) + " " + Net.ssid;
        if (!Net.wifiHardwareEnabled) return "󰤮";
        return "󰖪";
    }

    color: Net.connected ? Colors.purple : Theme.orange

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
