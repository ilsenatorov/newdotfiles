import QtQuick
import "../.."
import "../../services"

// NVIDIA GPU utilization + temperature, mirrors Sys.qml's layout. Hidden
// entirely when SysMon.gpuAvailable is false (no nvidia-smi, or no NVIDIA
// device -- see SysMon.qml).
Row {
    visible: SysMon.gpuAvailable
    spacing: Theme.barPillGap

    Text {
        text: "  " + Math.round(SysMon.gpuUtil * 100) + "%"
        height: Theme.barHeight
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font
        font.pixelSize: Theme.fsBar
        color: Theme.green
    }

    Text {
        text: "  " + SysMon.gpuTempC.toFixed(0) + "°C"
        height: Theme.barHeight
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font
        font.pixelSize: Theme.fsBar
        color: SysMon.gpuTempC >= 85 ? Theme.red : Theme.green
    }
}
