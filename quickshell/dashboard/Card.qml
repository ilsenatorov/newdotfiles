import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.UPower
import ".."
import "../services"

// SUPER+G's system-info overlay: fastfetch-style identity header, the
// CPU/RAM/TMP/DSK/GPU bars and UP/WX/LOAD/... stat grid (unchanged from the
// old desktop-corner dashboard), plus a top-processes list. Fixed size and
// shown/hidden as a whole by shell.qml's Loader -- no more pill-to-card morph,
// since this only exists while SUPER+G is actually open.
Item {
    id: root

    implicitWidth: Theme.cardW
    implicitHeight: Theme.cardH

    // Starts false so every field's entrance animation (staggered via
    // `shown`/`index` on StatBar/Stat below) actually has something to
    // animate from -- a fresh Card instance is created by the Loader every
    // time the overlay opens, so this replays each time rather than once.
    property bool ready: false
    Component.onCompleted: {
        root.ready = true;
        SysMon.procsActive = true;
    }
    Component.onDestruction: SysMon.procsActive = false

    // Drawn through the MultiEffect below, which is why this is hidden.
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface
        border.width: 2
        border.color: "transparent"
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        source: bg
        anchors.fill: bg
        shadowEnabled: true
        shadowColor: "#0A0F12"
        shadowBlur: 0.7
        shadowVerticalOffset: 4
        shadowOpacity: 0.6
    }

    Item {
        anchors.fill: parent
        anchors.margins: Theme.pad
        clip: true

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 16

            // ---- fastfetch-style header -----------------------------------
            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 2

                Text {
                    text: (SysMon.hostname !== "" ? SysMon.hostname : "?")
                    color: Colors.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                    font.bold: true
                }
                Text {
                    text: (SysMon.osName !== "" ? SysMon.osName : "Linux")
                        + (SysMon.kernelVersion !== "" ? "  ·  " + SysMon.kernelVersion : "")
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: (SysMon.shellName !== "" ? SysMon.shellName : "sh")
                        + "  ·  " + Quickshell.screens.map(s => s.name + " " + s.width + "x" + s.height).join(", ")
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            Clock {
                anchors.left: parent.left
                anchors.right: parent.right
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 10

                StatBar {
                    width: parent.width
                    index: 0
                    shown: root.ready
                    label: "CPU"
                    value: SysMon.cpu
                    caption: Math.round(SysMon.cpu * 100) + "%"
                    barColor: SysMon.cpu > 0.9 ? Theme.red : Colors.accent
                }

                StatBar {
                    width: parent.width
                    index: 1
                    shown: root.ready
                    label: "RAM"
                    value: SysMon.ram
                    caption: Math.round(SysMon.ram * 100) + "%"
                    barColor: SysMon.ram > 0.9 ? Theme.red : Colors.accent
                }

                StatBar {
                    width: parent.width
                    index: 2
                    shown: root.ready
                    label: "TMP"
                    value: SysMon.tempFrac
                    caption: Math.round(SysMon.tempC) + "°"
                    // Mirrors waybar's temperature critical-threshold of 85.
                    barColor: SysMon.tempC > 85 ? Theme.red : (SysMon.tempC > 75 ? Theme.yellow : Colors.accent)
                }

                StatBar {
                    width: parent.width
                    index: 3
                    shown: root.ready
                    label: "DSK"
                    value: SysMon.disk
                    caption: Math.round(SysMon.disk * 100) + "%"
                    barColor: SysMon.disk > 0.9 ? Theme.red : Colors.accent
                }

                // NVIDIA only -- see SysMon.gpuAvailable. This box also has an
                // Intel iGPU, but reading its utilization needs intel_gpu_top
                // (root, not installed), so it has no stat here.
                StatBar {
                    width: parent.width
                    index: 4
                    shown: root.ready && SysMon.gpuAvailable
                    visible: SysMon.gpuAvailable
                    label: "GPU"
                    value: SysMon.gpuUtil
                    caption: Math.round(SysMon.gpuUtil * 100) + "%"
                    barColor: SysMon.gpuUtil > 0.9 ? Theme.red : Colors.accent
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.divider
            }

            Grid {
                anchors.left: parent.left
                anchors.right: parent.right
                columns: 2
                rowSpacing: 8
                columnSpacing: 0

                property int colW: (width - columnSpacing) / 2

                Stat {
                    width: parent.colW; index: 5; shown: root.ready
                    label: "UP"; value: SysMon.uptimeText
                }
                Stat {
                    width: parent.colW; index: 6; shown: root.ready
                    label: "WX"; value: Weather.text
                }
                Stat {
                    width: parent.colW; index: 7; shown: root.ready
                    label: "LOAD"; value: SysMon.load1.toFixed(2)
                    // 12 threads here, so one core saturated is ~1.0.
                    valueColor: SysMon.load1 > 12 ? Theme.red : (SysMon.load1 > 6 ? Theme.yellow : Theme.fg)
                }
                Stat {
                    width: parent.colW; index: 8; shown: root.ready
                    label: "NET"; value: "▲ " + SysMon.fmtBytes(SysMon.netUp) + "  ▼ " + SysMon.fmtBytes(SysMon.netDown)
                }
                Stat {
                    width: parent.colW; index: 9; shown: root.ready
                    label: "FREE"; value: SysMon.fmtBytes(SysMon.diskFreeBytes)
                }
                Stat {
                    width: parent.colW; index: 10; shown: root.ready
                    label: "CLD"; value: ClaudeUsage.text
                    // Dimmed rather than hidden when the OAuth token has expired:
                    // the numbers are still the last true ones, just not fresh.
                    dimmed: ClaudeUsage.stale
                    valueColor: ClaudeUsage.fiveHour > 90 ? Theme.red : (ClaudeUsage.fiveHour > 70 ? Theme.yellow : Theme.fg)
                }
                Stat {
                    width: parent.colW; index: 11; shown: root.ready
                    label: "SWP"; value: SysMon.fmtBytes(SysMon.swapUsedBytes)
                    valueColor: SysMon.swapTotalBytes > 0 && SysMon.swapUsedBytes / SysMon.swapTotalBytes > 0.5 ? Theme.yellow : Theme.fg
                }
                Stat {
                    width: parent.colW; index: 12; shown: root.ready && SysMon.gpuAvailable
                    visible: SysMon.gpuAvailable
                    label: "GTM"; value: Math.round(SysMon.gpuTempC) + "°"
                    valueColor: SysMon.gpuTempC > 85 ? Theme.red : (SysMon.gpuTempC > 75 ? Theme.yellow : Theme.fg)
                }
                Stat {
                    width: parent.colW; index: 13; shown: root.ready && SysMon.gpuAvailable
                    visible: SysMon.gpuAvailable
                    label: "VRM"
                    value: SysMon.fmtBytes(SysMon.gpuVramUsedBytes) + " / " + SysMon.fmtBytes(SysMon.gpuVramTotalBytes)
                }
                Stat {
                    width: parent.colW; index: 14; shown: root.ready
                    label: "BAT"
                    value: {
                        const d = UPower.displayDevice;
                        if (d === null || !d.isLaptopBattery) return "AC";
                        // Quickshell reports percentage as 0..1.
                        const pct = Math.round(d.percentage * 100);
                        const charging = d.state === UPowerDeviceState.Charging;
                        const full = d.state === UPowerDeviceState.FullyCharged;
                        return pct + "%" + (charging ? "  " : (full ? "  " : ""));
                    }
                    valueColor: {
                        const d = UPower.displayDevice;
                        if (d === null) return Theme.fg;
                        if (d.state === UPowerDeviceState.Charging || d.state === UPowerDeviceState.FullyCharged) return Theme.fg;
                        return d.percentage < 0.15 ? Theme.red : (d.percentage < 0.3 ? Theme.yellow : Theme.fg);
                    }
                }
            }

            // Only exists while something is actually playing.
            Stat {
                width: parent.width
                index: 15
                shown: root.ready && Media.active
                visible: Media.active
                label: ""
                value: Media.text
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.divider
            }

            // ---- htop-style top processes -----------------------------------
            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 4

                Text {
                    text: "TOP PROCESSES"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel
                    font.letterSpacing: 1.5
                }

                Repeater {
                    model: SysMon.topProcesses

                    Row {
                        width: parent.width
                        spacing: 8

                        required property var modelData

                        Text {
                            width: parent.width - 60
                            text: modelData.name
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fsValue
                            elide: Text.ElideRight
                        }
                        Text {
                            width: 52
                            horizontalAlignment: Text.AlignRight
                            text: modelData.cpu.toFixed(1) + "%"
                            color: modelData.cpu > 50 ? Theme.red : Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fsValue
                        }
                    }
                }
            }
        }
    }
}
