import QtQuick
import ".."

// One floating bar pill -- the direct replacement for waybar's
// .modules-left/-center/-right. Background, radius and padding match
// waybar/style.css exactly so the bar is visually a no-op switch.
Row {
    id: root

    default property alias content: inner.children
    property int spacing_: Theme.barPillGap

    height: Theme.barHeight

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: inner.implicitWidth + Theme.barPillPadH * 2
        height: parent.height
        radius: Theme.radius
        color: Theme.barPill

        Row {
            id: inner
            anchors.centerIn: parent
            spacing: root.spacing_
        }
    }
}
