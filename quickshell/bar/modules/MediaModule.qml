import QtQuick
import "../.."
import "../../services"

// Now playing: player glyph + title, elided so a long track name can't shove
// the rest of the pill around. Hidden while no MPRIS player exists; dimmed
// while paused (it stays, so the panel is one click away to resume).
// Click opens the media panel, middle-click play/pause, right-click next,
// scroll the player's own volume (its Pipewire stream, not the sink).
Item {
    id: root

    signal clicked

    // Read by bar/ModuleRow.qml to hide the whole entry.
    readonly property bool shown: Media.present
    height: Theme.barHeight
    implicitWidth: row.implicitWidth
    width: implicitWidth

    readonly property color hue: Media.active ? (Media.spotify ? Theme.green : Colors.accent) : Theme.dim

    Row {
        id: row
        height: parent.height
        spacing: Math.round(6 * Theme.s)

        Text {
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            font.family: Theme.font
            font.pixelSize: Theme.fsBar
            text: Media.spotify ? "󰓇" : "󰝚"
            color: root.hue
        }

        Text {
            height: parent.height
            width: Math.min(implicitWidth, Theme.mediaTitleMaxW)
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: Theme.fsBar
            text: (Media.active ? "" : "󰏤 ") + Media.title
            color: Media.active ? Theme.fg : Theme.dim
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) Media.toggle();
            else if (mouse.button === Qt.RightButton) Media.next();
            else root.clicked();
        }
        onWheel: wheel => Media.nudgeVolume(wheel.angleDelta.y > 0 ? 0.03 : -0.03)
    }
}
