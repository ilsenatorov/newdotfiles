import QtQuick
import QtQuick.Shapes
import ".."

// Shared popup shell for the bar's dropdown panels (calendar, network,
// bluetooth, audio, power). One instance lives in shell.qml; its content is
// swapped by a Loader based on which bar module was clicked.
//
// The visible card sits inside shadow headroom (Theme.inset on the top, left
// and bottom; the right edge stays flush with the bar's side margin, which is
// all the room there is before the screen edge). shell.qml masks input to
// `card`, so the headroom never eats clicks meant for windows beneath.
//
// Opening is a droplet: a drop of the card's surface forms under the bar
// module that owns the panel, hangs and stretches, then lets go of the bar
// and spreads into the card with a small liquid wobble. Closing runs the
// same shape backwards, so the card is drawn back up into the bar. It is
// all driven by `reveal` (ui/Reveal.qml's "morph" progress, linear in
// time); the easing lives in the phase maths below.
Item {
    id: root

    default property alias content: body.children
    property string title: ""
    readonly property alias card: card

    // 0..1, linear in time. 1 when not animated, so a Panel used on its own
    // just shows up as a card.
    property real reveal: 1
    // Screen-right-edge distance to the owning bar module's centre (see
    // Bar.originFromRight); -1 hangs the drop near the card's right end.
    property real originFromRight: -1

    implicitWidth: Theme.panelW + Theme.inset + Theme.barMarginSide
    implicitHeight: col.implicitHeight + 24 + Theme.inset * 2

    Item {
        id: card

        anchors.fill: parent
        anchors.topMargin: Theme.inset
        anchors.leftMargin: Theme.inset
        anchors.bottomMargin: Theme.inset
        anchors.rightMargin: Theme.barMarginSide

        // ---- droplet geometry, in card coordinates -----------------------
        // The bar pill's bottom edge sits barMarginTop above the card.
        readonly property real barY: -Theme.barMarginTop
        readonly property real dropW: 38
        readonly property real dropH: 54
        readonly property real neckHalf: 7

        // Where the drop hangs from: under the module, kept far enough in
        // from the card's corners that the neck always lands on its flat top.
        readonly property real ox: {
            const want = root.originFromRight >= 0
                ? card.width - (root.originFromRight - Theme.barMarginSide)
                : card.width - 48;
            const edge = Theme.radius + card.dropW / 2 + 2;
            return Math.max(edge, Math.min(card.width - edge, want));
        }

        // Phase 1 (0..0.3): the drop forms and stretches down off the bar.
        // Phase 2 (0.3..1): it lets go and spreads into the card.
        readonly property real split: 0.3
        readonly property real a: Math.min(1, root.reveal / split)
        readonly property real b: Math.max(0, (root.reveal - split) / (1 - split))

        function easeOutCubic(t: real): real { return 1 - Math.pow(1 - t, 3); }
        // Damped spring settling on 1: the overshoot is the liquid wobble.
        function spring(t: real, k: real, w: real): real {
            return t >= 1 ? 1 : 1 - Math.exp(-k * t) * Math.cos(w * t);
        }
        function lerp(x: real, y: real, t: real): real { return x + (y - x) * t; }

        readonly property real ea: easeOutCubic(a)
        // Width spreads with a gentle wobble, height with a livelier one;
        // both are capped below so the overshoot stays inside the shadow
        // headroom the window has around the card.
        readonly property real sw: spring(b, 7, 6)
        readonly property real sh: spring(b, 6, 8.5)

        readonly property real curW: b > 0 ? 0 : lerp(12, dropW, ea)
        readonly property real blobLeft: b > 0 ? Math.max(-Theme.inset + 2, lerp(ox - dropW / 2, 0, sw)) : ox - curW / 2
        readonly property real blobRight: b > 0 ? Math.min(card.width + 3, lerp(ox + dropW / 2, card.width, sw)) : ox + curW / 2
        readonly property real blobTop: b > 0 ? lerp(barY, 0, easeOutCubic(Math.min(1, b * 1.6))) : barY
        readonly property real blobBottom: b > 0
            ? Math.min(card.height + Theme.inset - 2, lerp(barY + dropH, card.height, sh))
            : barY + lerp(2, dropH, ea)

        // Hanging drop: flat top stuck to the bar, fully round bottom. It
        // rounds off to a normal card as it detaches.
        readonly property real topR: b > 0 ? lerp(0, Theme.radius, Math.min(1, b * 2)) : 0
        readonly property real botR: b > 0 ? lerp(dropW / 2, Theme.radius, Math.min(1, b * 1.5)) : Math.min(curW / 2, (blobBottom - blobTop) / 2)

        // The neck: flares into the bar like a meniscus while the drop
        // hangs, then pinches off as the card pulls away.
        readonly property real pinch: easeOutCubic(Math.min(1, b / 0.45))
        readonly property real flare: 7 * ea * (1 - pinch)
        readonly property real waist: neckHalf * (1 - pinch)
        readonly property real neckOpacity: b < 0.35 ? 1 : Math.max(0, 1 - (b - 0.35) / 0.15)

        // Content fades in only once the card is nearly its full size, and
        // is clipped to the blob so nothing shows outside the liquid.
        readonly property real contentOpacity: Math.max(0, Math.min(1, (root.reveal - 0.62) / 0.3))

        Surface {
            x: card.blobLeft
            y: card.blobTop
            width: Math.max(0, card.blobRight - card.blobLeft)
            height: Math.max(0, card.blobBottom - card.blobTop)
            topRadius: card.topR
            bottomRadius: card.botR
            visible: root.reveal > 0
        }

        // Drawn over the blob's top edge (2px overlap) so its border doesn't
        // cut a line through the joint. Same fill, so the overlap vanishes.
        Shape {
            anchors.fill: parent
            visible: root.reveal > 0 && card.neckOpacity > 0
            opacity: card.neckOpacity
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                id: neck
                strokeWidth: -1
                fillColor: Theme.windowSurface

                readonly property real top: card.barY
                readonly property real bot: Math.max(card.blobTop, card.barY) + 3
                readonly property real half: Math.min(card.neckHalf, (card.blobRight - card.blobLeft) / 2)
                readonly property real topHalf: half + card.flare
                readonly property real waist: Math.min(half, card.waist)

                startX: card.ox - topHalf
                startY: top

                PathCubic {
                    x: card.ox - neck.half
                    y: neck.bot
                    control1X: card.ox - neck.waist
                    control1Y: neck.top
                    control2X: card.ox - neck.waist
                    control2Y: neck.bot
                }
                PathLine {
                    x: card.ox + neck.half
                    y: neck.bot
                }
                PathCubic {
                    x: card.ox + neck.topHalf
                    y: neck.top
                    control1X: card.ox + neck.waist
                    control1Y: neck.bot
                    control2X: card.ox + neck.waist
                    control2Y: neck.top
                }
            }
        }

        Item {
            id: clipper

            x: Math.max(0, card.blobLeft)
            y: Math.max(0, card.blobTop)
            width: Math.max(0, Math.min(card.width, card.blobRight) - x)
            height: Math.max(0, Math.min(card.height, card.blobBottom) - y)
            clip: root.reveal < 1
            opacity: card.contentOpacity

            Column {
                id: col
                x: 12 - clipper.x
                y: 12 - clipper.y
                width: card.width - 24
                spacing: 10

                Text {
                    id: header
                    text: root.title
                    visible: root.title !== ""
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel
                    font.bold: true
                    color: Theme.fg
                }

                Column {
                    id: body
                    width: col.width
                    spacing: 8
                }
            }
        }
    }
}
