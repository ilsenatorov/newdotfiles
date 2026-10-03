import QtQuick
import ".."
import "../services"

// htop-style top processes: name, a CPU bar (scaled to one full core, so a
// process pinning a core reads full whatever the core count), the percentage,
// and resident memory.
Column {
    id: root

    spacing: Math.round(3 * Theme.s)

    readonly property int rowH: Math.round(22 * Theme.s)
    readonly property int nameW: Math.round(width * 0.36)
    readonly property int pctW: Math.round(52 * Theme.s)
    readonly property int memW: Math.round(54 * Theme.s)

    Repeater {
        model: SysMon.topProcesses

        Item {
            required property var modelData
            readonly property real frac: Math.min(1, modelData.cpu / 100)
            readonly property color hue: Theme.level(frac, 0.5, 0.9, Colors.green)

            width: root.width
            height: root.rowH

            Text {
                id: name
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: root.nameW
                text: modelData.name
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Math.round(13 * Theme.s)
                elide: Text.ElideRight
            }

            Rectangle {
                id: track
                anchors.left: name.right
                anchors.leftMargin: Math.round(6 * Theme.s)
                anchors.right: pct.left
                anchors.rightMargin: Math.round(8 * Theme.s)
                anchors.verticalCenter: parent.verticalCenter
                height: Math.round(6 * Theme.s)
                radius: height / 2
                color: Theme.track

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: Math.max(height, parent.width * frac)
                    color: hue

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.durBar
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.easeOutQuint
                        }
                    }
                }
            }

            Text {
                id: pct
                anchors.right: mem.left
                anchors.verticalCenter: parent.verticalCenter
                width: root.pctW
                horizontalAlignment: Text.AlignRight
                text: (modelData.cpu < 10 ? modelData.cpu.toFixed(1) : Math.round(modelData.cpu)) + "%"
                color: hue
                font.family: Theme.font
                font.pixelSize: Math.round(13 * Theme.s)
            }

            Text {
                id: mem
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: root.memW
                horizontalAlignment: Text.AlignRight
                text: SysMon.fmtBytes(modelData.rssBytes)
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Math.round(13 * Theme.s)
            }
        }
    }
}
