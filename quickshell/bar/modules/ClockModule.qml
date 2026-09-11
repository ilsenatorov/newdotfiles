import QtQuick
import "../.."
import "../../services"

// Ported from waybar's clock module. waybar's format-alt added seconds on
// click, but services/Time.qml (shared with the dashboard) samples at
// minute precision, so there is nothing to toggle to here -- one format.
// The {calendar} tooltip becomes a real Calendar panel: click opens it.
Text {
    id: root

    signal calendarRequested

    height: Theme.barHeight
    verticalAlignment: Text.AlignVCenter
    font.family: Theme.font
    font.pixelSize: Theme.fsBar
    color: Colors.accent
    text: "  " + Qt.formatDateTime(Time.now, "dddd, dd MMMM HH:mm")

    MouseArea {
        anchors.fill: parent
        onClicked: root.calendarRequested()
    }
}
