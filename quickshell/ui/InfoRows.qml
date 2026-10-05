import QtQuick
import ".."

// Label / value rows for a details block: rows = [["IP", "10.0.0.2"], ...].
Column {
    id: root

    property var rows: []

    spacing: Math.round(2 * Theme.s)

    Repeater {
        model: root.rows

        Row {
            width: root.width
            spacing: Math.round(8 * Theme.s)

            required property var modelData

            Text {
                width: Math.round(56 * Theme.s)
                text: modelData[0]
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
            }
            Text {
                width: parent.width - Math.round(64 * Theme.s)
                text: modelData[1]
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
                elide: Text.ElideRight
            }
        }
    }
}
