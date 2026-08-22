import QtQuick

// The expanded clock block: oversized time, an accent rule that fades out to the
// right, then the date. Iosevka Light at 62px is the one place in this rice with
// real typographic weight -- everything else stays at bar scale.
Item {
    id: root

    implicitHeight: col.implicitHeight

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6

        Row {
            spacing: 2

            Text {
                text: Time.hh
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fsClock
                font.weight: Font.Light
                font.letterSpacing: 1
            }

            // Deliberately static. A pulsing colon repaints the whole surface at
            // 60fps forever, and Hyprland re-blurs every one of those frames --
            // it cost ~5% CPU at idle on this machine for a blinking dot. All the
            // motion here is event-driven instead, so at rest this costs nothing.
            Text {
                text: ":"
                color: Colors.accent
                font.family: Theme.font
                font.pixelSize: Theme.fsClock
                font.weight: Font.Light
            }

            Text {
                text: Time.mm
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fsClock
                font.weight: Font.Light
                font.letterSpacing: 1
            }
        }

        Rectangle {
            width: 88
            height: 2
            radius: 1

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Colors.accent }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Text {
            text: Time.dateLine
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fsDate
            font.letterSpacing: 2.5
        }
    }
}
