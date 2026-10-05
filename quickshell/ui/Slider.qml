import QtQuick
import ".."

// A horizontal 0..1 track you can click or drag -- the same look as the
// Audio panel's volume bar (8px track, accent fill), pulled out so the media
// scrubber, app volume and the night-light temperature share one widget.
// It holds no state: bind `value`, react to `moved`.
Item {
    id: root

    property real value: 0
    property color fill: Colors.accent
    property bool enabled_: true
    // Show a knob while hovered/dragged (the scrubber); off for plain meters.
    property bool knob: true

    signal moved(real v)

    implicitHeight: Math.round(16 * Theme.s)
    opacity: root.enabled_ ? 1 : 0.5

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Math.round(8 * Theme.s)
        radius: Math.round(4 * Theme.s)
        color: Theme.track

        Rectangle {
            width: track.width * Math.max(0, Math.min(1, root.value))
            height: track.height
            radius: track.radius
            color: root.fill
        }
    }

    Rectangle {
        visible: root.knob && root.enabled_ && (area.containsMouse || area.pressed)
        width: Math.round(14 * Theme.s)
        height: Math.round(14 * Theme.s)
        radius: Math.round(7 * Theme.s)
        color: root.fill
        anchors.verticalCenter: parent.verticalCenter
        x: track.width * Math.max(0, Math.min(1, root.value)) - width / 2
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled_
        cursorShape: Qt.PointingHandCursor
        function emit(x: real): void { root.moved(Math.max(0, Math.min(1, x / track.width))); }
        onPressed: mouse => emit(mouse.x)
        onPositionChanged: mouse => { if (pressed) emit(mouse.x); }
    }
}
