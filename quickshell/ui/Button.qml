import QtQuick
import ".."

// Form button; `primary` is the filled accent one (Save / Join).
Rectangle {
    id: root

    property string label: ""
    property bool primary: false
    signal clicked

    width: Math.round(70 * Theme.s)
    height: Math.round(30 * Theme.s)
    radius: Math.round(6 * Theme.s)
    color: primary ? Colors.accent : "transparent"
    border.width: primary ? 0 : 1
    border.color: Theme.rule

    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.primary ? Theme.surface : Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
    }
    MouseArea { anchors.fill: parent; onClicked: root.clicked() }
}
