import QtQuick
import ".."
import "../services"

// Terminal-style rolling trace: one point every SysMon poll, covering the
// last minute. Missing GPU telemetry is left unplotted rather than shown as 0.
Item {
    id: root
    implicitHeight: 210

    Text {
        text: "┌─ SYS::LOAD // 60 SEC"
        color: Colors.green
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
        font.letterSpacing: 1
    }

    Row {
        anchors.right: parent.right
        spacing: 10

        Text {
            text: "CPU " + Math.round(SysMon.cpu * 100) + "%"
            color: Colors.green
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
        }
        Text {
            text: "RAM " + Math.round(SysMon.ram * 100) + "%"
            color: Colors.cyan
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
        }
        Text {
            text: SysMon.gpuAvailable ? "GPU " + Math.round(SysMon.gpuUtil * 100) + "%" : "GPU --"
            color: Colors.orange
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
        }
    }

    Canvas {
        id: canvas
        anchors.top: parent.top
        anchors.topMargin: 24
        anchors.left: parent.left
        anchors.right: parent.right
        height: 158
        antialiasing: true

        function chartLeft() { return 36; }
        function chartWidth() { return width - chartLeft(); }

        function plot(ctx, values, color) {
            if (values.length < 2) return;
            const offset = SysMon.historySize - values.length;
            let started = false;
            let points = 0;
            ctx.beginPath();
            for (let i = 0; i < values.length; i++) {
                if (values[i] < 0) { started = false; continue; }
                const x = chartLeft() + (offset + i) * chartWidth() / (SysMon.historySize - 1);
                const y = height - 4 - Math.max(0, Math.min(1, values[i])) * (height - 8);
                if (!started) { ctx.moveTo(x, y); started = true; }
                else ctx.lineTo(x, y);
                points++;
            }
            if (points < 2) return;
            ctx.strokeStyle = color;
            ctx.lineWidth = 2;
            ctx.stroke();
        }

        onPaint: {
            const ctx = getContext("2d");
            const left = chartLeft();
            const right = width - 1;
            const top = 4;
            const bottom = height - 4;
            ctx.clearRect(0, 0, width, height);

            // Subtle terminal grid, with an axis and percentage readout.
            ctx.font = Theme.fsLabel + "px " + Theme.font;
            ctx.fillStyle = Theme.dim;
            ctx.textAlign = "left";
            ctx.fillText("100", 0, top + Theme.fsLabel);
            ctx.fillText(" 50", 0, (top + bottom) / 2 + Theme.fsLabel / 2);
            ctx.fillText("  0", 0, bottom);

            ctx.strokeStyle = Colors.accentDim;
            ctx.lineWidth = 1;
            for (let i = 0; i <= 4; i++) {
                const y = top + i * (bottom - top) / 4;
                for (let x = left; x < right; x += 8) {
                    ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(Math.min(x + 3, right), y); ctx.stroke();
                }
            }
            for (let i = 0; i <= 6; i++) {
                const x = left + i * (right - left) / 6;
                ctx.beginPath(); ctx.moveTo(x, top); ctx.lineTo(x, bottom); ctx.stroke();
            }
            ctx.strokeStyle = Colors.green;
            ctx.globalAlpha = 0.55;
            ctx.beginPath(); ctx.moveTo(left, top); ctx.lineTo(left, bottom); ctx.lineTo(right, bottom); ctx.stroke();
            ctx.globalAlpha = 1;

            plot(ctx, SysMon.cpuHistory, Colors.green);
            plot(ctx, SysMon.ramHistory, Colors.cyan);
            plot(ctx, SysMon.gpuHistory, Colors.orange);
        }

        Connections {
            target: SysMon
            function onHistoryVersionChanged() { canvas.requestPaint(); }
        }
        Component.onCompleted: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        text: "└─ -60s"
        color: Colors.green
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
    }
    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: "NOW ─┘"
        color: Colors.green
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
    }
}
