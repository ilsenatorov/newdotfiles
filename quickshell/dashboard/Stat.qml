import QtQuick
import ".."

// A footer cell: small dim label, value beside it. Same fade-and-rise entrance
// as StatBar so the whole card assembles as one motion.
Item {
    id: root

    property string label
    property string value
    property color valueColor: Theme.fg
    property int index: 0
    property bool shown: false
    property bool dimmed: false

    implicitHeight: Theme.footerRow

    opacity: shown ? (dimmed ? 0.45 : 1) : 0

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: root.shown ? root.index * Theme.durStagger : 0 }
            NumberAnimation {
                duration: Theme.durRow
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeOutQuint
            }
        }
    }

    transform: Translate {
        y: root.shown ? 0 : 10

        Behavior on y {
            SequentialAnimation {
                PauseAnimation { duration: root.shown ? root.index * Theme.durStagger : 0 }
                NumberAnimation {
                    duration: Theme.durRow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.easeOutQuint
                }
            }
        }
    }

    Text {
        id: lbl
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 42
        text: root.label
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
        font.letterSpacing: 1.5
    }

    Text {
        anchors.left: lbl.right
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        color: root.valueColor
        font.family: Theme.font
        font.pixelSize: Theme.fsValue
        elide: Text.ElideRight
    }
}
