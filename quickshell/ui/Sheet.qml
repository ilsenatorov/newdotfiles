import QtQuick
import ".."

// A bar panel's content (Network, Bluetooth, Audio, Share Wi-Fi) hosted as a
// page of the SUPER+D hub instead of hanging from the bar. Same card width
// and body column as ui/Panel.qml, so the content lays out exactly as it
// does in its droplet -- only the frame and the header differ.
//
// The header is a breadcrumb back to the hub. Esc is not handled here: the
// content lets it fall through to shell.qml, which steps back one page.
Item {
    id: root

    default property alias content: body.children
    property string title: ""
    property string glyph: ""
    property color hue: Colors.accent
    // Pages above this one, outermost first.
    property var trail: ["Menu"]

    signal closeRequested

    // Same click-away contract as the other menus (see ui/Picker.qml).
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    Surface {
        anchors.fill: card
    }

    Item {
        id: card

        anchors.centerIn: parent
        width: Theme.panelW
        height: Math.min(col.implicitHeight + Math.round(24 * Theme.s), root.height - Theme.inset * 2)
        clip: true

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: col

            x: Math.round(12 * Theme.s)
            y: Math.round(12 * Theme.s)
            width: card.width - Math.round(24 * Theme.s)
            spacing: Math.round(10 * Theme.s)

            Item {
                width: col.width
                height: crumbs.implicitHeight

                Row {
                    id: crumbs
                    spacing: Math.round(6 * Theme.s)

                    Repeater {
                        model: root.trail

                        Text {
                            required property string modelData
                            text: modelData + " ›"
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fsLabel
                        }
                    }

                    Text {
                        text: root.glyph
                        visible: root.glyph !== ""
                        color: root.hue
                        font.family: Theme.font
                        font.pixelSize: Theme.fsLabel
                    }

                    Text {
                        text: root.title
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fsLabel
                        font.bold: true
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "esc back"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel - Math.round(2 * Theme.s)
                }
            }

            Column {
                id: body
                width: col.width
                spacing: Math.round(8 * Theme.s)
            }
        }
    }
}
