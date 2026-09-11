import QtQuick
import "../.."
import "../../services"

// cpu / temperature / memory / disk / net-up / net-down, one Row of Text
// items -- direct port of waybar's cpu/temperature/memory/disk/network#up
// /network#downspeed modules onto the SysMon singleton, which already
// samples all of this from sysfs with no subprocess. Every Text is pinned to
// Theme.barHeight and center-aligned because Row (a Positioner) top-aligns
// children of differing height rather than centering them.
Row {
    spacing: Theme.barPillGap

    Text {
        text: "  " + Math.round(SysMon.cpu * 100) + "%"
        height: Theme.barHeight
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font
        font.pixelSize: Theme.fsBar
        color: Colors.accent
    }

    Text {
        visible: SysMon.tempPath !== ""
        text: "  " + SysMon.tempC.toFixed(0) + "°C"
        height: Theme.barHeight
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font
        font.pixelSize: Theme.fsBar
        color: SysMon.tempC >= 85 ? Theme.red : Colors.accent
    }

    Text {
        text: "󰍛  " + SysMon.fmtBytes(SysMon.ramUsedBytes)
        height: Theme.barHeight
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font
        font.pixelSize: Theme.fsBar
        color: Theme.blue
    }

    Text {
        text: "  " + SysMon.fmtBytes(SysMon.diskFreeBytes)
        height: Theme.barHeight
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font
        font.pixelSize: Theme.fsBar
        color: Theme.orange
    }

    Text {
        text: "  " + SysMon.fmtBytes(SysMon.netUp) + "/s"
        height: Theme.barHeight
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font
        font.pixelSize: Theme.fsBar
        color: Theme.purple
    }

    Text {
        text: "  " + SysMon.fmtBytes(SysMon.netDown) + "/s"
        height: Theme.barHeight
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font
        font.pixelSize: Theme.fsBar
        color: Theme.purple
    }
}
