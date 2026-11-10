import QtQuick
import "../.."
import "../../services"

// Things that are on and easy to forget: caffeine (idle inhibited), a
// running screen recording, and sync with the homeserver (whenever Syncthing
// runs here). The rest hide when off -- the bar has no idle placeholder for
// "nothing unusual". Click the recording to stop it, click the cup to let the
// machine sleep again.
Row {
    id: root

    // Read by bar/ModuleRow.qml to hide the whole entry.
    readonly property bool shown: Caffeine.enabled || Recorder.recording || Sync.state !== "off"
    height: Theme.barHeight
    spacing: Math.round(8 * Theme.s)

    // Green 0: safe to turn the machine off. Yellow N: items still to copy either
    // way. Red: the homeserver is unreachable.
    Text {
        visible: Sync.state !== "off"
        height: parent.height
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font
        font.pixelSize: Theme.fsBar
        text: Sync.state === "offline" ? "󰅤 offline" : "󰓦 " + (Sync.state.split(" ")[1] ?? "0")
        color: Sync.state === "offline" ? Theme.red : Sync.state === "synced" ? Theme.green : Theme.yellow
    }

    Text {
        visible: Recorder.recording
        height: parent.height
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font
        font.pixelSize: Theme.fsBar
        text: "● " + Recorder.elapsedText()
        color: Theme.red

        SequentialAnimation on opacity {
            running: Recorder.recording
            loops: Animation.Infinite
            NumberAnimation { to: 0.45; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Recorder.stop()
        }
    }

    Text {
        visible: Caffeine.enabled
        height: parent.height
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font
        font.pixelSize: Theme.fsBar
        text: "󰅶"
        color: Theme.yellow

        MouseArea {
            anchors.fill: parent
            onClicked: Caffeine.toggle()
        }
    }
}
