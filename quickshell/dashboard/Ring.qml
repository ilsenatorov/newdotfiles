import QtQuick
import QtQuick.Shapes
import ".."

// A 270-degree arc gauge, open at the bottom, with the reading in the middle
// and the label sitting in the gap. Drawn with Shapes rather than a Canvas so
// it is retained geometry: the sweep animates only when the value changes and
// costs nothing at rest (the same reason Clock's colon never pulsed).
Item {
    id: root

    property real value: 0              // 0..1
    property color color: Colors.accent
    property string label
    property string valueText: Math.round(root.value * 100) + "%"
    property real thickness: Math.round(8 * Theme.s)

    // Animated copy of `value` that the arc actually follows.
    property real shownValue: Math.max(0, Math.min(1, root.value))
    Behavior on shownValue {
        NumberAnimation {
            duration: Theme.durBar
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOutQuint
        }
    }

    readonly property real size: Math.min(width, height)
    readonly property real radius: (size - thickness) / 2

    implicitWidth: Math.round(108 * Theme.s)
    implicitHeight: implicitWidth

    Shape {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        preferredRendererType: Shape.CurveRenderer

        // Qt angles run clockwise from 3 o'clock: 135 starts bottom-left.
        ShapePath {
            strokeColor: Theme.track
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: 135
                sweepAngle: 270
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: 135
                sweepAngle: 270 * root.shownValue
            }
        }
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Math.round(2 * Theme.s)
        text: root.valueText
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Math.round(root.size * 0.24)
        font.weight: Font.Light
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.size * 0.02)
        text: root.label
        color: root.color
        font.family: Theme.font
        font.pixelSize: Math.round(12 * Theme.s)
        font.letterSpacing: 1.5
    }
}
