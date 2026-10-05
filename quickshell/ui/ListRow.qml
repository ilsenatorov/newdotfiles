import QtQuick
import ".."

// One row of the Network / Bluetooth lists: glyph, title + subtitle, and
// optional trailing battery, lock, forget and check marks.
Rectangle {
    id: row

    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property bool subtitleIsError: false
    property bool active: false      // connected -- accent colouring + check
    property bool selected: false
    property bool locked: false
    property bool forgettable: false
    property string battery: ""

    signal activated
    signal secondary
    signal forgetRequested

    height: Math.round(42 * Theme.s)
    radius: Math.round(8 * Theme.s)
    color: (rowArea.containsMouse || selected) ? Colors.surface : "transparent"
    border.width: selected ? 1 : 0
    border.color: Colors.accent

    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => mouse.button === Qt.RightButton ? row.secondary() : row.activated()
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Math.round(8 * Theme.s)
        anchors.rightMargin: Math.round(8 * Theme.s)
        spacing: Math.round(8 * Theme.s)

        Text {
            id: glyphText
            width: Math.round(Theme.fsValue * 1.4)
            text: row.glyph
            font.family: Theme.font
            font.pixelSize: Theme.fsValue
            color: row.active ? Colors.accent : Theme.fg
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            width: parent.width - glyphText.width - trailing.width - parent.spacing * 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: row.title
                font.family: Theme.font
                font.pixelSize: Theme.fsValue
                color: row.active ? Colors.accent : Theme.fg
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: row.subtitle
                font.family: Theme.font
                font.pixelSize: Math.round(Theme.fsLabel * 0.85)
                color: row.subtitleIsError ? Colors.urgent : Theme.dim
                elide: Text.ElideRight
            }
        }

        Row {
            id: trailing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(8 * Theme.s)

            Text {
                visible: row.battery !== ""
                text: row.battery
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
                color: Theme.dim
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                visible: row.locked
                text: "󰌾"
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
                color: Theme.dim
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                visible: row.forgettable
                text: "󰆴"
                font.family: Theme.font
                font.pixelSize: Theme.fsValue
                color: forgetArea.containsMouse ? Colors.urgent : Theme.dim
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    id: forgetArea
                    anchors.fill: parent
                    anchors.margins: Math.round(-4 * Theme.s)
                    hoverEnabled: true
                    onClicked: row.forgetRequested()
                }
            }

            Text {
                visible: row.active
                text: "✓"
                color: Colors.accent
                font.pixelSize: Theme.fsValue
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
