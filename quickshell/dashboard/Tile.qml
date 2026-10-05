import QtQuick
import ".."

// One cell of the dashboard grid: a faint surface, a glyph + title header,
// an optional caption at the header's right, and a content slot below. Owns
// the fade-and-rise entrance so the grid assembles tile by tile (staggered
// via `index`), the motion StatBar/Stat used to do per row.
Item {
    id: root

    property string icon
    property string title
    property string caption
    property color captionColor: Theme.fg
    property color iconColor: Colors.accent
    property int index: 0
    property bool shown: false

    // Children land in the body, below the header.
    default property alias content: body.data
    readonly property alias body: body

    readonly property int padding: Math.round(14 * Theme.s)

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
        anchors.fill: parent
        radius: Theme.radius - Math.round(2 * Theme.s)
        color: Qt.alpha(Colors.surface, 0.55)
        border.width: 1
        border.color: Theme.divider
    }

    Row {
        id: header
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: root.padding
        anchors.topMargin: root.padding - Math.round(2 * Theme.s)
        spacing: Math.round(8 * Theme.s)
        visible: root.title !== ""

        Text {
            text: root.icon
            color: root.iconColor
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.title.toUpperCase()
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Math.round(12 * Theme.s)
            font.letterSpacing: 1.5
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: root.padding
        anchors.verticalCenter: header.verticalCenter
        text: root.caption
        textFormat: Text.StyledText
        color: root.captionColor
        font.family: Theme.font
        font.pixelSize: Math.round(13 * Theme.s)
        visible: root.title !== ""
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: root.padding
        anchors.topMargin: root.title !== "" ? header.y + header.height + Math.round(10 * Theme.s) : root.padding
    }
}
