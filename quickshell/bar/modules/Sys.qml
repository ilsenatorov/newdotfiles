import QtQuick
import "../.."
import "../../services"
import "../../ui"

// cpu / memory / net up+down, one Row of Text items -- port of waybar's
// cpu/memory/network modules onto the SysMon singleton, which already
// samples this from sysfs with no subprocess. Numbers are left-padded to a
// fixed width (the bar font is monospace) so the pill doesn't shift as digit
// counts change. Every Text is pinned to Theme.barHeight and center-aligned
// because Row (a Positioner) top-aligns children of differing height rather
// than centering them.
Row {
    spacing: Theme.barPillGap

    Text {
        text: " " + String(Math.round(SysMon.cpu * 100)).padStart(3) + "%"
        height: Theme.barHeight
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font
        font.pixelSize: Theme.fsBar
        color: Colors.cyan
    }

    Text {
        text: "󰍛 " + SysMon.fmtBytes(SysMon.ramUsedBytes).padStart(4)
        height: Theme.barHeight
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font
        font.pixelSize: Theme.fsBar
        color: Colors.cyan
    }

    Sep {}

    Text {
        text: " " + SysMon.fmtRate(SysMon.netUp).padStart(4) + "   " + SysMon.fmtRate(SysMon.netDown).padStart(4)
        height: Theme.barHeight
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font
        font.pixelSize: Theme.fsBar
        color: Colors.purple
    }
}
