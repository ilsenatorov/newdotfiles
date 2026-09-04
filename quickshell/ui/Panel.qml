import QtQuick
import ".."

// Shared popup shell for the bar's dropdown panels (calendar, network,
// bluetooth, audio, power). One instance lives in shell.qml; its content is
// swapped by a Loader based on which bar module was clicked.
Rectangle {
    id: root

    default property alias content: body.children
    property string title: ""

    width: Theme.panelW
    implicitHeight: col.implicitHeight + 24

    radius: Theme.radius
    color: Theme.barPill
    border.width: 1
    border.color: Theme.rule

    Column {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Text {
            id: header
            text: root.title
            visible: root.title !== ""
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
            font.bold: true
            color: Theme.fg
        }

        Column {
            id: body
            width: col.width
            spacing: 8
        }
    }
}
