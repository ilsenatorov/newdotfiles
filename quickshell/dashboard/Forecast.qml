import QtQuick
import ".."
import "../services"

// Next-24h strip from Weather.hourly: condition glyphs and temperatures every
// 3h along the top, a smoothed temperature curve with a soft fill, and
// precipitation-probability bars along the bottom. Repaints only when a new
// forecast lands (every 15 min).
Item {
    id: root

    readonly property var hours: Weather.hourly

    readonly property int fsSmall: Math.round(12 * Theme.s)
    readonly property int fsIcon: Math.round(18 * Theme.s)
    readonly property real step: width / Math.max(1, hours.length)
    function xAt(i: int): real { return step * (i + 0.5); }
    readonly property real lo: hours.length ? Math.min(...hours.map(p => p.temp)) : 0
    readonly property real hi: hours.length ? Math.max(...hours.map(p => p.temp)) : 0

    function rgba(c: color, a: real): string {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
            + Math.round(c.b * 255) + "," + a + ")";
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const hs = root.hours;
            const n = hs.length;
            if (n < 2) return;

            const h = height;
            const labelH = root.fsSmall + 4;     // hour labels at the bottom
            const rainH = Math.round(h * 0.18);  // precipitation band above them
            const topH = root.fsIcon + root.fsSmall + 10;  // glyph + temp labels at the top
            const plotTop = topH + 4;
            const plotBottom = h - labelH - rainH - 6;
            const step = root.step;
            const xAt = root.xAt;
            const lo = root.lo, hi = root.hi;
            // At least a 4-degree span so a flat day doesn't amplify noise.
            const pad = Math.max(0, 4 - (hi - lo)) / 2;
            const yAt = t => plotBottom - (t - (lo - pad)) / ((hi + pad) - (lo - pad)) * (plotBottom - plotTop);

            // Precipitation bars.
            const rainBase = h - labelH - 2;
            for (let i = 0; i < n; i++) {
                const pop = hs[i].pop / 100;
                if (pop <= 0) continue;
                const bh = Math.max(2, pop * rainH);
                ctx.fillStyle = root.rgba(Colors.blue, 0.25 + 0.6 * pop);
                ctx.fillRect(xAt(i) - step * 0.32, rainBase - bh, step * 0.64, bh);
            }

            // Temperature curve: quadratic smoothing through midpoints.
            const pts = hs.map((p, i) => [xAt(i), yAt(p.temp)]);
            const curve = () => {
                ctx.moveTo(pts[0][0], pts[0][1]);
                for (let i = 1; i < pts.length - 1; i++) {
                    const mx = (pts[i][0] + pts[i + 1][0]) / 2;
                    const my = (pts[i][1] + pts[i + 1][1]) / 2;
                    ctx.quadraticCurveTo(pts[i][0], pts[i][1], mx, my);
                }
                ctx.lineTo(pts[n - 1][0], pts[n - 1][1]);
            };

            const grad = ctx.createLinearGradient(0, plotTop, 0, plotBottom);
            grad.addColorStop(0, root.rgba(Colors.orange, 0.30));
            grad.addColorStop(1, root.rgba(Colors.orange, 0.0));
            ctx.beginPath();
            curve();
            ctx.lineTo(pts[n - 1][0], plotBottom);
            ctx.lineTo(pts[0][0], plotBottom);
            ctx.closePath();
            ctx.fillStyle = grad;
            ctx.fill();

            ctx.beginPath();
            curve();
            ctx.strokeStyle = Colors.orange;
            ctx.lineWidth = 2;
            ctx.lineJoin = "round";
            ctx.stroke();

            // Every 3h: a dot on the curve. The labels above/below it are
            // QML Text (see the Repeater) -- Context2D mangles a spaced family
            // like "MesloLGS NF" and would fall back to a font without glyphs.
            ctx.fillStyle = Colors.orange;
            for (let i = 0; i < n; i += 3) {
                ctx.beginPath(); ctx.arc(xAt(i), pts[i][1], 2.5, 0, 2 * Math.PI); ctx.fill();
            }
        }

        Component.onCompleted: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    onHoursChanged: canvas.requestPaint()

    // Every 3h: condition glyph + temperature above the curve, hour below.
    Repeater {
        model: root.hours.length < 2 ? [] : root.hours.filter((_, i) => i % 3 === 0)

        Item {
            required property var modelData
            required property int index
            readonly property real cx: root.xAt(index * 3)

            Column {
                x: parent.cx - width / 2
                y: 0
                spacing: 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.bucketFor(modelData.code, modelData.day).icon
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: root.fsIcon
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.round(modelData.temp) + "°"
                    color: modelData.temp === root.hi ? Colors.orange
                        : (modelData.temp === root.lo ? Colors.cyan : Theme.fg)
                    font.family: Theme.font
                    font.pixelSize: root.fsSmall
                }
            }

            Text {
                x: parent.cx - width / 2
                y: root.height - height
                text: index === 0 ? "now" : Qt.formatDateTime(new Date(modelData.t), "HH")
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: root.fsSmall
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.hours.length < 2
        text: "no forecast yet"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Math.round(13 * Theme.s)
    }
}
