import QtQuick
import ".."

// A small on/off switch for the Quick page and the notification center's
// DND. Like ui/Slider.qml it holds no state: bind `checked`, react to
// `toggled`.
Rectangle {
    id: root

    property bool checked: false
    property color hue: Colors.accent

    signal toggled

    implicitWidth: Math.round(40 * Theme.s)
    implicitHeight: Math.round(22 * Theme.s)
    radius: height / 2
    color: root.checked ? Qt.rgba(hue.r, hue.g, hue.b, 0.35) : Theme.track
    border.width: 1
    border.color: root.checked ? hue : Theme.rule

    Behavior on color { ColorAnimation { duration: Theme.durHover } }

    Rectangle {
        width: parent.height - 6
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? root.hue : Theme.dim

        Behavior on x { NumberAnimation { duration: Theme.durHover; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
