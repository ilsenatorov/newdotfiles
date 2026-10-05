import QtQuick
import ".."

// Pill-shaped toggle/action button with an optional key hint in front.
Rectangle {
    id: chip

    property string label: ""
    property string key: ""
    property bool active: false
    signal clicked

    width: chipRow.implicitWidth + Math.round(20 * Theme.s)
    height: Math.round(26 * Theme.s)
    radius: height / 2
    color: active ? Colors.accent : "transparent"
    border.width: 1
    border.color: active ? Colors.accent : Theme.rule

    Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: Math.round(5 * Theme.s)

        Text {
            visible: chip.key !== ""
            text: chip.key
            color: chip.active ? Theme.surface : Colors.accent
            opacity: 0.7
            font.family: Theme.font
            font.pixelSize: Math.round(Theme.fsLabel * 0.85)
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: chip.label
            color: chip.active ? Theme.surface : Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea { anchors.fill: parent; onClicked: chip.clicked() }
}
