import QtQuick
import Quickshell
import Quickshell.Services.UPower
import ".."
import "../ui"
import "../services"

// SUPER+G's system-info overlay: a four-column tile grid built to be read at
// a glance. Headline gauges up top, the last two minutes of activity and
// network as graphs, then processes, memory/disks and thermals as bars, and
// the day's forecast plus Claude limits at the bottom. One hue per series
// everywhere (CPU green, RAM cyan, GPU orange, network blue/purple, disks
// lavender); yellow/red only ever mean "warn"/"critical" (Theme.level).
//
// Fixed size and shown/hidden as a whole by shell.qml's Loader; a fresh
// instance per open, so the staggered entrance replays every time.
Item {
    id: root

    implicitWidth: Theme.cardW
    implicitHeight: Theme.cardH

    property bool ready: false
    Component.onCompleted: {
        root.ready = true;
        // Processes/NVMe sampling only while this is open; the 2s poll is
        // always on (shell.qml binds SysMon.fast for the bar).
        SysMon.procsActive = true;
    }
    Component.onDestruction: {
        SysMon.procsActive = false;
    }

    readonly property real sc: Theme.s
    readonly property int gap: Math.round(12 * sc)

    readonly property color cCpu: Colors.green
    readonly property color cRam: Colors.cyan
    readonly property color cGpu: Colors.orange
    readonly property color cDown: Colors.blue
    readonly property color cUp: Colors.purple
    readonly property color cDisk: Colors.accentAlt

    readonly property bool gpu: SysMon.gpuAvailable

    // "2h 14m" / "3d 6h" until `ms`, against the minute clock.
    function until(ms: real): string {
        const s = Math.max(0, (ms - Time.now.getTime()) / 1000);
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return d > 0 ? d + "d " + h + "h" : (h > 0 ? h + "h " + m + "m" : m + "m");
    }

    function chip(c: color, text: string): string {
        return "<font color='" + c + "'>●</font> " + text;
    }

    // Big-number gauge tile: ring on the left, value/word pairs beside it.
    component GaugeTile: Tile {
        id: gt

        property real value: 0
        property color hue: Colors.accent
        property string label
        property var lines: []          // [{v, k, c?}]

        shown: root.ready

        Ring {
            id: ring
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(parent.height, Math.round(parent.width * 0.5))
            height: width
            value: gt.value
            color: Theme.level(gt.value, 0.8, 0.92, gt.hue)
            label: gt.label
        }

        Column {
            anchors.left: ring.right
            anchors.leftMargin: Math.round(12 * root.sc)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(6 * root.sc)

            Repeater {
                model: gt.lines

                Text {
                    required property var modelData
                    width: parent.width
                    elide: Text.ElideRight
                    textFormat: Text.StyledText
                    font.family: Theme.font
                    font.pixelSize: Math.round(16 * root.sc)
                    color: modelData.c ?? Theme.fg
                    text: modelData.v + " <font color='" + Theme.dim + "' size='2'>" + modelData.k + "</font>"
                }
            }
        }
    }

    Surface {
        anchors.fill: parent
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.pad

        readonly property real colW: (width - 3 * root.gap) / 4
        function span(n: int): real { return n * colW + (n - 1) * root.gap; }

        // ---- header: clock, machine identity, current weather -------------
        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.round(56 * root.sc)

            Row {
                id: clock
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(14 * root.sc)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.StyledText
                    text: Time.hh + "<font color='" + Colors.accent + "'>:</font>" + Time.mm
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Math.round(44 * root.sc)
                    font.weight: Font.Light
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: Qt.formatDateTime(Time.now, "dddd").toUpperCase()
                        color: Colors.accent
                        font.family: Theme.font
                        font.pixelSize: Math.round(13 * root.sc)
                        font.letterSpacing: 2
                    }
                    Text {
                        text: Qt.formatDateTime(Time.now, "dd MMM yyyy").toUpperCase()
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Math.round(13 * root.sc)
                        font.letterSpacing: 2
                    }
                }
            }

            Row {
                id: weatherNow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(10 * root.sc)
                visible: Weather.valid

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.bucket.icon
                    color: Colors.orange
                    font.family: Theme.font
                    font.pixelSize: Math.round(30 * root.sc)
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: Math.round(Weather.tempC) + "°"
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Math.round(26 * root.sc)
                        font.weight: Font.Light
                    }
                    Text {
                        text: Weather.bucket.label
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Math.round(11 * root.sc)
                        font.letterSpacing: 1.5
                    }
                }
            }

            // Machine identity, fastfetch-style but as glyph chips.
            Row {
                anchors.left: clock.right
                anchors.leftMargin: Math.round(32 * root.sc)
                anchors.right: weatherNow.left
                anchors.rightMargin: Math.round(24 * root.sc)
                anchors.verticalCenter: parent.verticalCenter
                layoutDirection: Qt.RightToLeft
                spacing: Math.round(18 * root.sc)
                clip: true

                Repeater {
                    model: {
                        const out = [
                            { i: "", t: "up " + SysMon.uptimeText },
                            { i: "", t: SysMon.kernelVersion.replace(/-.*$/, "") },
                            { i: "", t: SysMon.osName.replace(/ Linux$/, "") },
                            { i: "", t: SysMon.hostname }
                        ];
                        const d = UPower.displayDevice;
                        if (d !== null && d.isLaptopBattery) {
                            const charging = d.state === UPowerDeviceState.Charging
                                || d.state === UPowerDeviceState.FullyCharged;
                            out.unshift({
                                i: charging ? "" : "",
                                t: Math.round(d.percentage * 100) + "%",
                                c: charging ? Theme.fg : Theme.level(1 - d.percentage, 0.7, 0.85, Theme.fg)
                            });
                        }
                        return out.filter(x => x.t !== "");
                    }

                    Row {
                        required property var modelData
                        spacing: Math.round(6 * root.sc)

                        Text {
                            text: modelData.i
                            color: Colors.accent
                            font.family: Theme.font
                            font.pixelSize: Math.round(13 * root.sc)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: modelData.t
                            color: modelData.c ?? Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Math.round(13 * root.sc)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.topMargin: root.gap
            anchors.bottom: parent.bottom
            spacing: root.gap

            // ---- headline gauges ------------------------------------------
            Row {
                id: gauges
                spacing: root.gap
                height: Math.round(150 * root.sc)

                readonly property int count: root.gpu ? 4 : 2
                readonly property real tileW: (content.width - (count - 1) * root.gap) / count

                GaugeTile {
                    width: gauges.tileW; height: gauges.height; index: 0
                    value: SysMon.cpu; hue: root.cCpu; label: "CPU"
                    lines: [
                        { v: Math.round(SysMon.tempC) + "°", k: "temp", c: Theme.level(SysMon.tempC, 75, 85, Theme.fg) },
                        { v: SysMon.load1.toFixed(2), k: "load", c: Theme.level(SysMon.load1 / SysMon.cores, 0.75, 1, Theme.fg) },
                        { v: SysMon.cores, k: "threads" }
                    ]
                }
                GaugeTile {
                    width: gauges.tileW; height: gauges.height; index: 1
                    value: SysMon.ram; hue: root.cRam; label: "RAM"
                    lines: [
                        { v: SysMon.fmtBytes(SysMon.ramUsedBytes), k: "used" },
                        { v: SysMon.fmtBytes(SysMon.ramCacheBytes), k: "cache" },
                        { v: SysMon.fmtBytes(SysMon.ramTotalBytes), k: "total" }
                    ]
                }
                GaugeTile {
                    visible: root.gpu
                    width: gauges.tileW; height: gauges.height; index: 2
                    value: SysMon.gpuUtil; hue: root.cGpu; label: "GPU"
                    lines: [
                        { v: Math.round(SysMon.gpuTempC) + "°", k: "temp", c: Theme.level(SysMon.gpuTempC, 75, 85, Theme.fg) },
                        { v: SysMon.gpuPowerW >= 0 ? Math.round(SysMon.gpuPowerW) + "W" : "--", k: "power" },
                        { v: SysMon.gpuFanFrac >= 0 ? Math.round(SysMon.gpuFanFrac * 100) + "%" : "--", k: "fan" }
                    ]
                }
                GaugeTile {
                    visible: root.gpu
                    width: gauges.tileW; height: gauges.height; index: 3
                    value: SysMon.gpuVramTotalBytes > 0 ? SysMon.gpuVramUsedBytes / SysMon.gpuVramTotalBytes : 0
                    hue: root.cGpu; label: "VRAM"
                    lines: [
                        { v: SysMon.fmtBytes(SysMon.gpuVramUsedBytes), k: "used" },
                        { v: SysMon.fmtBytes(SysMon.gpuVramTotalBytes - SysMon.gpuVramUsedBytes), k: "free" },
                        { v: SysMon.fmtBytes(SysMon.gpuVramTotalBytes), k: "total" }
                    ]
                }
            }

            // ---- history graphs -------------------------------------------
            Row {
                spacing: root.gap
                height: Math.round(160 * root.sc)

                Tile {
                    width: content.span(2); height: parent.height
                    index: 4; shown: root.ready
                    icon: ""; title: "Activity · 2 min"
                    captionColor: Theme.dim
                    caption: root.chip(root.cCpu, "CPU " + Math.round(SysMon.cpu * 100) + "%")
                        + "   " + root.chip(root.cRam, "RAM " + Math.round(SysMon.ram * 100) + "%")
                        + (root.gpu ? "   " + root.chip(root.cGpu, "GPU " + Math.round(SysMon.gpuUtil * 100) + "%") : "")

                    AreaGraph {
                        anchors.fill: parent
                        series: [
                            { values: SysMon.cpuHistory, color: root.cCpu, label: "CPU" },
                            { values: SysMon.ramHistory, color: root.cRam, label: "RAM" }
                        ].concat(root.gpu ? [{ values: SysMon.gpuHistory, color: root.cGpu, label: "GPU" }] : [])
                    }
                }

                Tile {
                    id: netTile
                    width: content.span(2); height: parent.height
                    index: 5; shown: root.ready
                    icon: ""; title: "Network"
                    caption: SysMon.netIface
                    captionColor: Theme.dim

                    Row {
                        id: rates
                        anchors.left: parent.left
                        anchors.top: parent.top
                        spacing: Math.round(22 * root.sc)

                        Text {
                            textFormat: Text.StyledText
                            text: "▼ " + SysMon.fmtRate(SysMon.netDown) + "<font color='" + Theme.dim + "' size='2'>/s</font>"
                            color: root.cDown
                            font.family: Theme.font
                            font.pixelSize: Math.round(18 * root.sc)
                        }
                        Text {
                            textFormat: Text.StyledText
                            text: "▲ " + SysMon.fmtRate(SysMon.netUp) + "<font color='" + Theme.dim + "' size='2'>/s</font>"
                            color: root.cUp
                            font.family: Theme.font
                            font.pixelSize: Math.round(18 * root.sc)
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: rates.verticalCenter
                        text: "scale " + SysMon.fmtRate(netGraph.scaleMax) + "/s"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Math.round(11 * root.sc)
                    }

                    AreaGraph {
                        id: netGraph
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: rates.bottom
                        anchors.topMargin: Math.round(6 * root.sc)
                        anchors.bottom: parent.bottom
                        mirror: true
                        autoScale: true
                        minScale: 64 * 1024
                        format: v => SysMon.fmtRate(v) + "/s"
                        series: [
                            { values: SysMon.netDownHistory, color: root.cDown, label: "▼" },
                            { values: SysMon.netUpHistory, color: root.cUp, label: "▲" }
                        ]
                    }
                }
            }

            // ---- details --------------------------------------------------
            Row {
                spacing: root.gap
                height: Math.round(236 * root.sc)

                Tile {
                    width: content.span(2); height: parent.height
                    index: 6; shown: root.ready
                    icon: ""; title: "Processes"
                    caption: "cpu · mem"
                    captionColor: Theme.dim

                    ProcList {
                        anchors.left: parent.left
                        anchors.right: parent.right
                    }
                }

                Tile {
                    width: content.span(1); height: parent.height
                    index: 7; shown: root.ready
                    icon: ""; title: "Memory · Disks"

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: Math.round(2 * root.sc)

                        Meter {
                            width: parent.width
                            label: "RAM"
                            segments: [
                                { v: SysMon.ram, color: Theme.level(SysMon.ram, 0.8, 0.92, root.cRam) },
                                { v: SysMon.ramTotalBytes > 0 ? SysMon.ramCacheBytes / SysMon.ramTotalBytes : 0, color: Qt.alpha(root.cRam, 0.4) }
                            ]
                            caption: Math.round(SysMon.ram * 100) + "%"
                        }

                        // Legend for the stacked bar above.
                        Text {
                            x: Math.round(52 * root.sc)
                            textFormat: Text.StyledText
                            text: "<font color='" + root.cRam + "'>■</font> used   <font color='"
                                + Qt.alpha(root.cRam, 0.4) + "'>■</font> cache"
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Math.round(11 * root.sc)
                        }

                        Meter {
                            width: parent.width
                            visible: SysMon.swapTotalBytes > 0
                            label: "Swap"
                            value: SysMon.swapTotalBytes > 0 ? SysMon.swapUsedBytes / SysMon.swapTotalBytes : 0
                            barColor: Theme.level(value, 0.5, 0.8, Qt.alpha(root.cRam, 0.7))
                            caption: SysMon.fmtBytes(SysMon.swapUsedBytes)
                        }

                        Item { width: 1; height: Math.round(8 * root.sc) }

                        Repeater {
                            model: SysMon.mounts

                            Meter {
                                required property var modelData
                                readonly property real frac: modelData.used / Math.max(1, modelData.used + modelData.avail)

                                width: parent.width
                                label: modelData.target === "/" ? "root" : modelData.target.replace(/^.*\//, "")
                                value: frac
                                barColor: Theme.level(frac, 0.85, 0.95, root.cDisk)
                                captionWidth: Math.round(70 * root.sc)
                                caption: SysMon.fmtBytes(modelData.avail) + " free"
                                captionColor: Theme.level(frac, 0.85, 0.95, Theme.fg)
                            }
                        }
                    }
                }

                Tile {
                    width: content.span(1); height: parent.height
                    index: 8; shown: root.ready
                    icon: ""; title: "Thermals"

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: Math.round(2 * root.sc)

                        readonly property int lw: Math.round(52 * root.sc)
                        function frac(t: real): real {
                            return Math.max(0, Math.min(1, (t - SysMon.tempMin) / (SysMon.tempMax - SysMon.tempMin)));
                        }

                        Meter {
                            width: parent.width; labelWidth: parent.lw
                            label: "CPU"
                            value: parent.frac(SysMon.tempC)
                            barColor: Theme.level(SysMon.tempC, 75, 85, root.cCpu)
                            caption: Math.round(SysMon.tempC) + "°"
                        }
                        Meter {
                            width: parent.width; labelWidth: parent.lw
                            visible: root.gpu
                            label: "GPU"
                            value: parent.frac(SysMon.gpuTempC)
                            barColor: Theme.level(SysMon.gpuTempC, 75, 85, root.cGpu)
                            caption: Math.round(SysMon.gpuTempC) + "°"
                        }
                        Repeater {
                            model: SysMon.nvmeTemps

                            Meter {
                                required property var modelData
                                required property int index
                                width: parent.width; labelWidth: parent.lw
                                label: SysMon.nvmeTemps.length > 1 ? "NVMe " + (index + 1) : "NVMe"
                                value: parent.frac(modelData)
                                // NVMe throttles far cooler than a CPU does.
                                barColor: Theme.level(modelData, 60, 70, root.cDisk)
                                caption: Math.round(modelData) + "°"
                            }
                        }

                        Item { width: 1; height: Math.round(8 * root.sc); visible: root.gpu }

                        Meter {
                            width: parent.width; labelWidth: parent.lw
                            visible: root.gpu && SysMon.gpuPowerW >= 0 && SysMon.gpuPowerLimitW > 0
                            label: "Power"
                            value: SysMon.gpuPowerLimitW > 0 ? SysMon.gpuPowerW / SysMon.gpuPowerLimitW : 0
                            barColor: root.cGpu
                            caption: Math.round(SysMon.gpuPowerW) + "W"
                        }
                        Meter {
                            width: parent.width; labelWidth: parent.lw
                            visible: root.gpu && SysMon.gpuFanFrac >= 0
                            label: "Fan"
                            value: SysMon.gpuFanFrac
                            barColor: root.cGpu
                            caption: Math.round(SysMon.gpuFanFrac * 100) + "%"
                        }
                    }
                }
            }

            // ---- forecast + Claude ----------------------------------------
            Row {
                id: bottomRow
                spacing: root.gap
                height: content.height - header.height - root.gap * 4
                    - Math.round((150 + 160 + 236) * root.sc)

                readonly property bool weatherOn: Local.svcWeather
                readonly property bool claudeOn: ClaudeUsage.valid
                visible: weatherOn || claudeOn

                Tile {
                    visible: bottomRow.weatherOn
                    width: content.span(bottomRow.claudeOn ? 3 : 4); height: parent.height
                    index: 9; shown: root.ready
                    icon: Weather.bucket.icon; iconColor: Colors.orange
                    title: "Next 24 hours"
                    captionColor: Theme.dim
                    caption: {
                        const hs = Weather.hourly;
                        if (hs.length === 0) return "";
                        const t = hs.map(h => h.temp);
                        const rain = Math.max(...hs.map(h => h.pop));
                        return "<font color='" + Colors.orange + "'>↑ " + Math.round(Math.max(...t)) + "°</font>   "
                            + "<font color='" + Colors.cyan + "'>↓ " + Math.round(Math.min(...t)) + "°</font>   "
                            + "<font color='" + Colors.blue + "'> " + rain + "%</font>";
                    }

                    Forecast {
                        anchors.fill: parent
                    }
                }

                Tile {
                    visible: bottomRow.claudeOn
                    width: content.span(bottomRow.weatherOn ? 1 : 4); height: parent.height
                    index: 10; shown: root.ready
                    icon: ""; iconColor: Colors.orange
                    title: "Claude"
                    caption: ClaudeUsage.stale ? "stale" : ""
                    captionColor: Theme.dim
                    opacity: ClaudeUsage.stale ? 0.6 : 1

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        spacing: Math.round(10 * root.sc)

                        Repeater {
                            model: [
                                { label: "5H", v: ClaudeUsage.fiveHour / 100, reset: ClaudeUsage.fiveHourReset },
                                { label: "7D", v: ClaudeUsage.sevenDay / 100, reset: ClaudeUsage.sevenDayReset }
                            ]

                            Column {
                                required property var modelData
                                spacing: Math.round(2 * root.sc)

                                readonly property real ringSize: Math.min(
                                    bottomRow.height - Math.round(66 * root.sc),
                                    Math.round(80 * root.sc))

                                Ring {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.ringSize
                                    height: width
                                    thickness: Math.round(6 * root.sc)
                                    value: modelData.v
                                    color: Theme.level(modelData.v, 0.75, 0.9, Colors.accent)
                                    label: modelData.label
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: modelData.reset > 0
                                    text: " " + root.until(modelData.reset)
                                    color: Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: Math.round(11 * root.sc)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
