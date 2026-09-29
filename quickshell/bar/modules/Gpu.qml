import QtQuick
import "../.."
import "../../services"

// NVIDIA GPU utilization, mirrors Sys.qml's layout. Hidden
// entirely when SysMon.gpuAvailable is false (no nvidia-smi, or no NVIDIA
// device -- see SysMon.qml).
Row {
    visible: SysMon.gpuAvailable
    spacing: Theme.barPillGap

    Text {
        text: " " + String(Math.round(SysMon.gpuUtil * 100)).padStart(3) + "%"
        height: Theme.barHeight
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font
        font.pixelSize: Theme.fsBar
        color: Colors.green
    }
}
