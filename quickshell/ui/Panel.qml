import QtQuick
import ".."

// Shared popup shell for the bar's dropdown panels (calendar, network,
// bluetooth, audio, power). One instance lives in shell.qml; its content is
// swapped by a Loader based on which bar module was clicked.
//
// The visible card sits inside shadow headroom (Theme.inset on the top, left
// and bottom; the right edge stays flush with the bar's side margin, which is
// all the room there is before the screen edge). shell.qml masks input to
// `card`, so the headroom never eats clicks meant for windows beneath.
Item {
    id: root

    default property alias content: body.children
    property string title: ""
    readonly property alias card: card

    implicitWidth: Theme.panelW + Theme.inset + Theme.barMarginSide
    implicitHeight: col.implicitHeight + 24 + Theme.inset * 2

    Item {
        id: card

        anchors.fill: parent
        anchors.topMargin: Theme.inset
        anchors.leftMargin: Theme.inset
        anchors.bottomMargin: Theme.inset
        anchors.rightMargin: Theme.barMarginSide

        Surface {
            anchors.fill: parent
        }

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
}
