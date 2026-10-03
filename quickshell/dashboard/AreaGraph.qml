import QtQuick
import ".."
import "../services"

// Rolling area chart over SysMon's timestamped history. Plots by sample time,
// not by index, so the 10s samples taken while the dashboard was closed sit
// where they belong instead of being stretched to look like 2s ones.
//
// series: [{values, color, label}]. Values below 0 are gaps (missing GPU).
// Fixed 0..1 scale by default; `autoScale` fits the visible peak instead
// (network). `mirror` draws series[0] up from a centre axis and series[1]
// down from it -- download above, upload below.
Item {
    id: root

    property var series: []
    property bool autoScale: false
    property bool mirror: false
    property real minScale: 1           // autoScale never zooms in past this
    property var format: v => Math.round(v * 100) + "%"

    // Visible peak, published for a caption when autoScale is on.
    property real scaleMax: 1

    property int hoverIndex: -1

    function rgba(c: color, a: real): string {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
            + Math.round(c.b * 255) + "," + a + ")";
    }

    // Round a peak up to 1/2/5 x 10^n so the scale doesn't twitch every sample.
    function niceCeil(v: real): real {
        const p = Math.pow(10, Math.floor(Math.log10(v)));
        for (const m of [1, 2, 5, 10]) if (v <= m * p) return m * p;
        return 10 * p;
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        function xFor(t, now) {
            return width * (1 - (now - t) / SysMon.historyWindowMs);
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const times = SysMon.historyTimes;
            const n = times.length;
            const w = width, h = height;
            const now = n > 0 ? times[n - 1] : Date.now();
            const mid = root.mirror ? h / 2 : h;

            // Scale.
            let peak = 0;
            if (root.autoScale) {
                for (const s of root.series)
                    for (let i = 0; i < s.values.length; i++)
                        if (now - times[i] <= SysMon.historyWindowMs) peak = Math.max(peak, s.values[i]);
                root.scaleMax = root.niceCeil(Math.max(root.minScale, peak));
            } else {
                root.scaleMax = 1;
            }
            const span = root.mirror ? h / 2 - 2 : h - 2;

            // Faint guides: quarters, or the centre axis when mirrored.
            ctx.lineWidth = 1;
            ctx.strokeStyle = root.rgba(Theme.rule, 0.6);
            ctx.setLineDash([2, 4]);
            const guides = root.mirror ? [0.5] : [0.25, 0.5, 0.75];
            for (const g of guides) {
                const y = Math.round(h * g) + 0.5;
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
            }
            ctx.setLineDash([]);

            root.series.forEach((s, si) => {
                const down = root.mirror && si === 1;
                const yFor = v => {
                    const f = Math.max(0, Math.min(1, v / root.scaleMax));
                    return down ? mid + f * span : mid - f * span;
                };

                // Contiguous runs of valid points; gaps split the area.
                const runs = [];
                let run = [];
                for (let i = 0; i < s.values.length && i < n; i++) {
                    const v = s.values[i];
                    const x = xFor(times[i], now);
                    if (v < 0 || x < -w) { if (run.length) runs.push(run); run = []; continue; }
                    run.push([x, yFor(v)]);
                }
                if (run.length) runs.push(run);

                const grad = ctx.createLinearGradient(0, down ? h : 0, 0, mid);
                grad.addColorStop(0, root.rgba(s.color, root.series.length > 2 ? 0.22 : 0.35));
                grad.addColorStop(1, root.rgba(s.color, 0.0));

                for (const r of runs) {
                    if (r.length < 2) continue;
                    ctx.beginPath();
                    ctx.moveTo(r[0][0], mid);
                    for (const p of r) ctx.lineTo(p[0], p[1]);
                    ctx.lineTo(r[r.length - 1][0], mid);
                    ctx.closePath();
                    ctx.fillStyle = grad;
                    ctx.fill();

                    ctx.beginPath();
                    ctx.moveTo(r[0][0], r[0][1]);
                    for (const p of r) ctx.lineTo(p[0], p[1]);
                    ctx.strokeStyle = s.color;
                    ctx.lineWidth = 1.6;
                    ctx.lineJoin = "round";
                    ctx.stroke();
                }
            });

            // Hover crosshair + dots.
            if (root.hoverIndex >= 0 && root.hoverIndex < n) {
                const x = xFor(times[root.hoverIndex], now);
                ctx.strokeStyle = root.rgba(Theme.fg, 0.35);
                ctx.lineWidth = 1;
                ctx.beginPath(); ctx.moveTo(Math.round(x) + 0.5, 0); ctx.lineTo(Math.round(x) + 0.5, h); ctx.stroke();
                root.series.forEach((s, si) => {
                    const v = s.values[root.hoverIndex];
                    if (v === undefined || v < 0) return;
                    const f = Math.max(0, Math.min(1, v / root.scaleMax));
                    const y = (root.mirror && si === 1) ? mid + f * span : mid - f * span;
                    ctx.fillStyle = s.color;
                    ctx.beginPath(); ctx.arc(x, y, 3, 0, 2 * Math.PI); ctx.fill();
                });
            }
        }

        Connections {
            target: SysMon
            function onHistoryVersionChanged() { canvas.requestPaint(); }
        }
        Component.onCompleted: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    onHoverIndexChanged: canvas.requestPaint()

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onExited: root.hoverIndex = -1
        onPositionChanged: m => {
            const times = SysMon.historyTimes;
            if (times.length === 0) return;
            const now = times[times.length - 1];
            const t = now - (1 - m.x / width) * SysMon.historyWindowMs;
            let best = -1, bestD = Infinity;
            for (let i = 0; i < times.length; i++) {
                const d = Math.abs(times[i] - t);
                if (d < bestD) { bestD = d; best = i; }
            }
            root.hoverIndex = best;
        }
    }

    // Hover readout: how long ago, then each series' value at that moment.
    Rectangle {
        visible: root.hoverIndex >= 0
        x: Math.max(0, Math.min(root.width - width, mouse.mouseX + 10))
        y: 2
        width: tip.implicitWidth + 12
        height: tip.implicitHeight + 6
        radius: 6
        color: Theme.windowSurface
        border.width: 1
        border.color: Theme.rule

        Text {
            id: tip
            anchors.centerIn: parent
            textFormat: Text.StyledText
            font.family: Theme.font
            font.pixelSize: Math.round(12 * Theme.s)
            color: Theme.dim
            text: {
                const i = root.hoverIndex;
                const times = SysMon.historyTimes;
                if (i < 0 || i >= times.length) return "";
                const ago = Math.round((times[times.length - 1] - times[i]) / 1000);
                const parts = [ago === 0 ? "now" : "-" + ago + "s"];
                for (const s of root.series) {
                    const v = s.values[i];
                    if (v === undefined || v < 0) continue;
                    parts.push("<font color='" + s.color + "'>" + s.label + " " + root.format(v) + "</font>");
                }
                return parts.join("  ");
            }
        }
    }
}
