import QtQuick
import ".."

// A labelled horizontal bar: label, track, caption. Either one `value` in
// `barColor`, or `segments` ([{v, color}], fractions of the whole) drawn as
// separate pills for a stacked reading (memory used / cache / free). Hover
// treatment (tinted row plus a 3px accent edge) is the old StatBar's, shared
// with the menu cards so it feels native to the rest of the rice.
Item {
    id: root

    property string label
    property color labelColor: Theme.dim
    property real value: 0              // 0..1
    property color barColor: Colors.accent
    property var segments: []
    property string caption
    property color captionColor: Theme.fg

    property int labelWidth: Math.round(46 * Theme.s)
    property int captionWidth: Math.round(54 * Theme.s)
    property real thickness: Math.round(6 * Theme.s)

    readonly property var parts: root.segments.length > 0
        ? root.segments
        : [{ v: root.value, color: root.barColor }]

    implicitHeight: Math.round(22 * Theme.s)

    Rectangle {
        id: rowBg
        anchors.fill: parent
        anchors.leftMargin: -6
        anchors.rightMargin: -6
        radius: 6
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
        width: root.labelWidth
        text: root.label
        color: hover.hovered ? Theme.fg : root.labelColor
        font.family: Theme.font
        font.pixelSize: Math.round(13 * Theme.s)
        elide: Text.ElideRight

        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    Text {
        id: cap
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.captionWidth
        horizontalAlignment: Text.AlignRight
        text: root.caption
        color: root.captionColor
        font.family: Theme.font
        font.pixelSize: Math.round(13 * Theme.s)
    }

    Rectangle {
        id: track
        anchors.left: lbl.right
        anchors.leftMargin: Math.round(6 * Theme.s)
        anchors.right: cap.left
        anchors.rightMargin: Math.round(8 * Theme.s)
        anchors.verticalCenter: parent.verticalCenter
        height: root.thickness
        radius: height / 2
        color: Theme.track

        Row {
            anchors.fill: parent
            spacing: 2

            Repeater {
                model: root.parts

                Rectangle {
                    required property var modelData
                    readonly property real gaps: (root.parts.length - 1) * 2

                    height: track.height
                    radius: height / 2
                    width: Math.max(0, (track.width - gaps) * Math.max(0, Math.min(1, modelData.v)))
                    visible: width > 0.5
                    color: modelData.color

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
        }
    }

    HoverHandler { id: hover }
}
