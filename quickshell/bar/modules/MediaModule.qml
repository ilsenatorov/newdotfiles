import QtQuick
import "../.."
import "../../services"

// Now playing: player glyph + title, elided so a long track name can't shove
// the rest of the pill around, then previous / play-pause / next buttons.
// Hidden while no MPRIS player exists; dimmed while paused (it stays, so the
// panel is one click away to resume). Click the title to open the media
// panel, middle-click play/pause, right-click next, scroll the player's own
// volume (its Pipewire stream, not the sink).
Item {
    id: root

    signal clicked

    // Read by bar/ModuleRow.qml to hide the whole entry.
    readonly property bool shown: Media.present
    height: Theme.barHeight
    implicitWidth: row.implicitWidth
    width: implicitWidth

    readonly property color hue: Media.active ? (Media.spotify ? Theme.green : Colors.accent) : Theme.dim

    component Btn: Text {
        id: btn
        property bool enabled_: true
        signal pressed_
        height: Theme.barHeight
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font
        font.pixelSize: Theme.fsBar
        color: !enabled_ ? Theme.dim : (hover.containsMouse ? Colors.accent : Theme.fg)
        opacity: enabled_ ? 1 : 0.5

        MouseArea {
            id: hover
            anchors.fill: parent
            anchors.margins: -Math.round(3 * Theme.s)
            hoverEnabled: true
            enabled: btn.enabled_
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.pressed_()
        }
    }

    // Under the row, so the buttons' own areas win; this one is the title.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) Media.toggle();
            else if (mouse.button === Qt.RightButton) Media.next();
            else root.clicked();
        }
        onWheel: wheel => Media.nudgeVolume(wheel.angleDelta.y > 0 ? 0.03 : -0.03)
    }

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
            text: Media.title
            color: Media.active ? Theme.fg : Theme.dim
        }

        Item { width: Math.round(2 * Theme.s); height: 1 }

        Btn {
            text: "󰒮"
            enabled_: Media.player !== null && Media.player.canGoPrevious
            onPressed_: Media.previous()
        }
        Btn {
            text: Media.active ? "󰏤" : "󰐊"
            onPressed_: Media.toggle()
        }
        Btn {
            text: "󰒭"
            enabled_: Media.player !== null && Media.player.canGoNext
            onPressed_: Media.next()
        }
    }
}
