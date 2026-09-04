import QtQuick
import Quickshell.Services.UPower
import "../.."

// Same states/threshold as waybar's battery module: bat BAT0, adapter AC,
// warning 30%, critical 15%, five-step icon ramp.
Text {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool laptop: dev !== null && dev.isLaptopBattery
    readonly property real pct: laptop ? dev.percentage * 100 : 0
    readonly property bool charging: laptop && dev.state === UPowerDeviceState.Charging
    readonly property bool full: laptop && dev.state === UPowerDeviceState.FullyCharged
    readonly property bool critical: laptop && pct <= 15
    readonly property bool warning: laptop && pct <= 30

    visible: laptop
    height: Theme.barHeight
    verticalAlignment: Text.AlignVCenter
    font.family: Theme.font
    font.pixelSize: Theme.fsBar

    text: {
        if (full) return "  Full";
        if (charging) return "⚡ " + Math.round(pct) + "%";
        return icon() + "  " + Math.round(pct) + "%";
    }

    color: {
        if (charging) return Theme.green;
        if (full || critical) return Theme.red;
        if (warning) return Theme.yellow;
        return Theme.pink;
    }

    function icon(): string {
        if (pct >= 90) return "";
        if (pct >= 70) return "";
        if (pct >= 40) return "";
        if (pct >= 15) return "";
        return "";
    }
}
