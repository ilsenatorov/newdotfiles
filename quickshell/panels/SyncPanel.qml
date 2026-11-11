import QtQuick
import ".."
import "../services"
import "../ui"

// Opened by left-clicking the bar's sync indicator: overall state, how much is
// still to send / receive, and the per-folder breakdown (busiest first).
// Pause / resume lives here too (right-click on the bar does the same).
Column {
    id: root
    width: parent ? parent.width : Theme.panelW
    spacing: Math.round(10 * Theme.s)

    Component.onCompleted: Sync.detailed = true
    Component.onDestruction: Sync.detailed = false

    readonly property var sorted: Sync.folders.slice().sort(
        (a, b) => (b.upBytes + b.downBytes) - (a.upBytes + a.downBytes) || a.id.localeCompare(b.id))

    readonly property string headline: {
        if (Sync.state === "offline") return "Homeserver unreachable";
        if (Sync.paused) return "Paused";
        if (Sync.state === "synced") return "Everything is synced";
        return "Syncing " + (Sync.state.split(" ")[1] ?? "") + " items";
    }
    readonly property color headColor: Sync.state === "offline" ? Theme.red
        : Sync.paused ? Theme.dim : Sync.state === "synced" ? Theme.green : Theme.yellow

    Row {
        width: parent.width
        spacing: Math.round(8 * Theme.s)

        Text {
            width: parent.width - toggle.width - parent.spacing
            height: toggle.height
            verticalAlignment: Text.AlignVCenter
            text: root.headline
            color: root.headColor
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
            font.bold: true
        }
        Button {
            id: toggle
            label: Sync.paused ? "Resume" : "Pause"
            primary: Sync.paused
            onClicked: Sync.toggle()
        }
    }

    InfoRows {
        width: parent.width
        rows: [
            ["To send", Sync.fmtBytes(Sync.upBytes) + (Sync.upBytes > 0 ? "  ↑" : "")],
            ["To get", Sync.fmtBytes(Sync.downBytes) + (Sync.downBytes > 0 ? "  ↓" : "")],
            ["Busiest", Sync.busiest ? Sync.busiest.id : "none"],
        ]
    }

    SectionLabel { text: "Folders" }

    Repeater {
        model: root.sorted

        Row {
            width: root.width
            spacing: Math.round(8 * Theme.s)

            required property var modelData
            readonly property real moving: modelData.upBytes + modelData.downBytes
            readonly property int items: modelData.upItems + modelData.downItems

            Text {
                width: parent.width * 0.4
                text: modelData.id
                color: parent.moving > 0 ? Theme.fg : Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
                elide: Text.ElideRight
            }
            Text {
                width: parent.width - parent.width * 0.4 - parent.spacing
                horizontalAlignment: Text.AlignRight
                text: {
                    const m = modelData;
                    if (parent.items === 0) return m.state === "idle" ? "up to date" : m.state;
                    let t = "";
                    if (m.upItems > 0) t += "↑ " + m.upItems + " · " + Sync.fmtBytes(m.upBytes) + "  ";
                    if (m.downItems > 0) t += "↓ " + m.downItems + " · " + Sync.fmtBytes(m.downBytes);
                    return t.trim();
                }
                color: parent.items > 0 ? Theme.yellow : Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
                elide: Text.ElideLeft
            }
        }
    }

    Text {
        visible: root.sorted.length === 0
        text: "No folder info"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
    }
}
