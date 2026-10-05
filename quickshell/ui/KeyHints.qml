import QtQuick
import ".."

// Panel footer: a rule, then the keys the current state responds to.
// hints = [["↵", "connect"], ["esc", "close"], ...].
Column {
    id: root

    property var hints: []

    spacing: Math.round(8 * Theme.s)

    Rectangle {
        width: root.width
        height: 1
        color: Theme.rule
    }

    Flow {
        width: root.width
        spacing: Math.round(10 * Theme.s)

        Repeater {
            model: root.hints

            Row {
                required property var modelData
                spacing: Math.round(4 * Theme.s)

                Text {
                    text: modelData[0]
                    color: Colors.accent
                    font.family: Theme.font
                    font.pixelSize: Math.round(Theme.fsLabel * 0.85)
                }
                Text {
                    text: modelData[1]
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Math.round(Theme.fsLabel * 0.85)
                }
            }
        }
    }
}
