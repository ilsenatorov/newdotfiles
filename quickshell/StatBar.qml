import QtQuick

// One labelled capsule gauge. The hover treatment -- tinted surface fill plus a
// 3px accent bar on the left edge -- is lifted straight from the selected-element
// rule in rofi/styles/base.rasi so the card feels native to the rest of the rice.
Item {
    id: root

    property string label
    property real value: 0          // 0..1
    property string caption
    property color barColor: Colors.accent
    property int index: 0           // position in the stack, drives the stagger
    property bool shown: false

    implicitHeight: Theme.barRow

    opacity: shown ? 1 : 0

    Behavior on opacity {
        SequentialAnimation {
            // Only stagger on the way in; collapsing should feel immediate.
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

    Rectangle {
        id: rowBg
        anchors.fill: parent
        anchors.leftMargin: -8
        anchors.rightMargin: -8
        radius: Theme.radius
        color: Colors.surface
        opacity: hover.hovered ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }

    Rectangle {
        anchors.left: rowBg.left
        anchors.top: rowBg.top
        anchors.bottom: rowBg.bottom
        width: 3
        radius: 1.5
        color: Colors.accent
        opacity: hover.hovered ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }

    Text {
        id: lbl
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        text: root.label
        color: hover.hovered ? Theme.fg : Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
        font.letterSpacing: 1.5

        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    Text {
        id: cap
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 46
        horizontalAlignment: Text.AlignRight
        text: root.caption
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fsValue
    }

    Rectangle {
        id: track
        anchors.left: lbl.right
        anchors.leftMargin: 10
        anchors.right: cap.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        radius: 2
        color: Theme.track

        Rectangle {
            height: parent.height
            radius: parent.radius
            width: track.width * Math.max(0, Math.min(1, root.value))
            color: root.barColor

            Behavior on width {
                NumberAnimation {
                    duration: Theme.durBar
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.easeOutQuint
                }
            }

            Behavior on color { ColorAnimation { duration: Theme.durHover } }
        }
    }

    HoverHandler { id: hover }
}
