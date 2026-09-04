import QtQuick
import QtQuick.Effects
import Quickshell.Services.UPower
import ".."
import "../services"

// The morphing surface. Collapsed it is a waybar-sized clock pill in the corner;
// expanded it is the full dashboard. It grows up and to the right from the
// bottom-left corner, so the anchor point never moves.
Item {
    id: root

    property bool expanded: false
    signal toggleRequested

    implicitWidth: expanded ? Theme.cardW : Theme.pillW
    implicitHeight: expanded ? Theme.cardH + (Media.active ? Theme.npRow : 0) : Theme.pillH
    width: implicitWidth
    height: implicitHeight

    // OutBack's overshoot is the "pop" -- the card briefly exceeds its target
    // size before settling. That is what the inset in Theme is reserving room for.
    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.durExpand; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
    }

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.durExpand; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
    }

    // Lift away from the screen corner, not around the centre.
    transformOrigin: Item.BottomLeft
    scale: hover.hovered ? 1.015 : 1.0

    Behavior on scale {
        NumberAnimation { duration: Theme.durHover; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOutQuint }
    }

    // Drawn through the MultiEffect below, which is why this is hidden.
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface
        border.width: 2
        // Half-strength: at full accent a 2px border round the whole card shouts
        // louder than the bar's own accents and stops reading as a hover hint.
        border.color: hover.hovered ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.45) : "transparent"
        visible: false
        layer.enabled: true

        Behavior on border.color { ColorAnimation { duration: Theme.durHover } }
    }

    MultiEffect {
        source: bg
        anchors.fill: bg
        shadowEnabled: true
        shadowColor: "#0A0F12"
        shadowBlur: 0.7
        shadowVerticalOffset: 4
        shadowOpacity: hover.hovered ? 0.8 : 0.45

        Behavior on shadowOpacity { NumberAnimation { duration: Theme.durHover } }
    }

    // Content is laid out at full card size regardless of the current size, so
    // growing reveals it rather than squashing it. This clips the overflow.
    Item {
        anchors.fill: parent
        clip: true

        // Pinned to where the pill's centre is, so it does not drift during the morph.
        Text {
            id: pillClock
            x: (Theme.pillW - width) / 2
            y: root.height - Theme.pillH / 2 - height / 2
            text: Time.hhmm
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fsPill
            font.letterSpacing: 1
            opacity: root.expanded ? 0 : 1
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }

        Item {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Theme.pad
            width: Theme.cardW - Theme.pad * 2
            height: Theme.cardH - Theme.pad * 2 + (Media.active ? Theme.npRow : 0)
            opacity: root.expanded ? 1 : 0
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: Theme.durFade } }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 16

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
                        shown: root.expanded
                        label: "CPU"
                        value: SysMon.cpu
                        caption: Math.round(SysMon.cpu * 100) + "%"
                        barColor: SysMon.cpu > 0.9 ? Theme.red : Colors.accent
                    }

                    StatBar {
                        width: parent.width
                        index: 1
                        shown: root.expanded
                        label: "RAM"
                        value: SysMon.ram
                        caption: Math.round(SysMon.ram * 100) + "%"
                        barColor: SysMon.ram > 0.9 ? Theme.red : Colors.accent
                    }

                    StatBar {
                        width: parent.width
                        index: 2
                        shown: root.expanded
                        label: "TMP"
                        value: SysMon.tempFrac
                        caption: Math.round(SysMon.tempC) + "\u00b0"
                        // Mirrors waybar's temperature critical-threshold of 85.
                        barColor: SysMon.tempC > 85 ? Theme.red : (SysMon.tempC > 75 ? Theme.yellow : Colors.accent)
                    }

                    StatBar {
                        width: parent.width
                        index: 3
                        shown: root.expanded
                        label: "DSK"
                        value: SysMon.disk
                        caption: Math.round(SysMon.disk * 100) + "%"
                        barColor: SysMon.disk > 0.9 ? Theme.red : Colors.accent
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
                        width: parent.colW; index: 4; shown: root.expanded
                        label: "UP"; value: SysMon.uptimeText
                    }
                    Stat {
                        width: parent.colW; index: 5; shown: root.expanded
                        label: "WX"; value: Weather.text
                    }
                    Stat {
                        width: parent.colW; index: 6; shown: root.expanded
                        label: "LOAD"; value: SysMon.load1.toFixed(2)
                        // 12 threads here, so one core saturated is ~1.0.
                        valueColor: SysMon.load1 > 12 ? Theme.red : (SysMon.load1 > 6 ? Theme.yellow : Theme.fg)
                    }
                    Stat {
                        width: parent.colW; index: 7; shown: root.expanded
                        label: "NET"; value: "\u25b2 " + SysMon.fmtBytes(SysMon.netUp) + "  \u25bc " + SysMon.fmtBytes(SysMon.netDown)
                    }
                    Stat {
                        width: parent.colW; index: 8; shown: root.expanded
                        label: "FREE"; value: SysMon.fmtBytes(SysMon.diskFreeBytes)
                    }
                    Stat {
                        width: parent.colW; index: 9; shown: root.expanded
                        label: "CLD"; value: ClaudeUsage.text
                        // Dimmed rather than hidden when the OAuth token has expired:
                        // the numbers are still the last true ones, just not fresh.
                        dimmed: ClaudeUsage.stale
                        valueColor: ClaudeUsage.fiveHour > 90 ? Theme.red : (ClaudeUsage.fiveHour > 70 ? Theme.yellow : Theme.fg)
                    }
                    Stat {
                        width: parent.colW; index: 10; shown: root.expanded
                        label: "SWP"; value: SysMon.fmtBytes(SysMon.swapUsedBytes)
                        valueColor: SysMon.swapTotalBytes > 0 && SysMon.swapUsedBytes / SysMon.swapTotalBytes > 0.5 ? Theme.yellow : Theme.fg
                    }
                    Stat {
                        width: parent.colW; index: 11; shown: root.expanded
                        label: "BAT"
                        value: {
                            const d = UPower.displayDevice;
                            if (d === null || !d.isLaptopBattery) return "AC";
                            // Quickshell reports percentage as 0..1.
                            const pct = Math.round(d.percentage * 100);
                            const charging = d.state === UPowerDeviceState.Charging;
                            const full = d.state === UPowerDeviceState.FullyCharged;
                            return pct + "%" + (charging ? "  \uf0e7" : (full ? "" : ""));
                        }
                        valueColor: {
                            const d = UPower.displayDevice;
                            if (d === null) return Theme.fg;
                            if (d.state === UPowerDeviceState.Charging || d.state === UPowerDeviceState.FullyCharged) return Theme.fg;
                            return d.percentage < 0.15 ? Theme.red : (d.percentage < 0.3 ? Theme.yellow : Theme.fg);
                        }
                    }
                }

                // Only exists while something is actually playing; the card
                // animates its height to suit.
                Stat {
                    width: parent.width
                    index: 12
                    shown: root.expanded && Media.active
                    visible: Media.active
                    label: "\uf001"
                    value: Media.text
                }
            }
        }
    }

    HoverHandler { id: hover }

    // Clicking works as well as SUPER+G -- the surface already takes input for hover.
    TapHandler { onTapped: root.toggleRequested() }
}
