pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../ui"
import "../services"

// SUPER+M. Keyboard-only by design: every action is a key in one of
// three modes, and the hint line always lists the keys for the current mode.
//   place   -- arrows/hjkl pick a tile, m/d mirror/disable, Enter applies,
//              o cycles the output when several are connected
//   layouts -- saved layouts; Up/Down pick, Enter restores
//   save    -- type a name, Enter saves the current layout
// Tab / Shift+Tab (or / and s from place) switch modes; Esc backs out to place,
// then closes. No Controls: their ComboBox fired `activated` on a bare arrow
// key and their Button ignored Enter, which is what forced the mouse.
Item {
    id: root

    signal closeRequested

    readonly property string script: Quickshell.shellPath("../hypr/scripts/monitor-place.sh")
    readonly property string layoutScript: Quickshell.shellPath("../hypr/scripts/monitor-layout.py")
    readonly property bool busy: MonitorLayouts.busy
    readonly property var modes: ["place", "layouts", "save"]
    property string mode: "place"
    property string anchorName: ""
    property var targets: []
    property var savedLayouts: []
    property int layoutIndex: 0
    property string chosen: ""
    property string error: ""
    property string sel: "Right"
    readonly property var chosenTarget: root.targets.find(t => t.name === root.chosen) ?? null

    function run(command: var, message: string): void {
        if (root.busy) return;
        root.error = "";
        MonitorLayouts.run(command, message);
    }

    function apply(): void {
        if (root.chosen !== "")
            root.run([root.script, root.sel.toLowerCase(), root.chosen], "Layout remembered");
    }

    function save(): void {
        const name = nameInput.text.trim();
        if (name === "") root.error = "Enter a layout name.";
        else root.run(["python3", root.layoutScript, "--save", name], "Layout saved");
    }

    function restore(): void {
        const name = root.savedLayouts[root.layoutIndex];
        if (name !== undefined)
            root.run(["python3", root.layoutScript, "--apply", name], "Layout restored");
    }

    function setMode(next: string): void {
        root.error = "";
        root.mode = next;
        if (next === "save") {
            nameInput.forceActiveFocus();
            nameInput.selectAll();
        } else {
            card.forceActiveFocus();
        }
    }

    function cycleMode(step: int): void {
        const i = root.modes.indexOf(root.mode);
        root.setMode(root.modes[(i + step + root.modes.length) % root.modes.length]);
    }

    function cycleTarget(): void {
        if (root.targets.length < 2) return;
        const i = root.targets.findIndex(t => t.name === root.chosen);
        root.chosen = root.targets[(i + 1) % root.targets.length].name;
    }

    function moveLayout(step: int): void {
        const n = root.savedLayouts.length;
        if (n > 0) root.layoutIndex = (root.layoutIndex + step + n) % n;
    }

    // Keys shared by every mode. Returns true when handled.
    function commonKey(event: var): bool {
        if (event.key === Qt.Key_Escape) {
            if (root.mode === "place") root.closeRequested();
            else root.setMode("place");
        } else if (event.key === Qt.Key_Tab) {
            root.cycleMode(1);
        } else if (event.key === Qt.Key_Backtab) {
            root.cycleMode(-1);
        } else {
            return false;
        }
        return true;
    }

    function placeKey(event: var): bool {
        switch (event.key) {
        case Qt.Key_Left: case Qt.Key_H: root.sel = "Left"; break;
        case Qt.Key_Right: case Qt.Key_L: root.sel = "Right"; break;
        case Qt.Key_Up: case Qt.Key_K: root.sel = "Above"; break;
        case Qt.Key_Down: case Qt.Key_J: root.sel = "Below"; break;
        case Qt.Key_M: root.sel = "Mirror"; break;
        case Qt.Key_D: root.sel = "Disable"; break;
        case Qt.Key_O: root.cycleTarget(); break;
        case Qt.Key_S: root.setMode("save"); break;
        case Qt.Key_Slash: root.setMode("layouts"); break;
        case Qt.Key_Return: case Qt.Key_Enter: root.apply(); break;
        default: return false;
        }
        return true;
    }

    function layoutsKey(event: var): bool {
        switch (event.key) {
        case Qt.Key_Up: case Qt.Key_K: root.moveLayout(-1); break;
        case Qt.Key_Down: case Qt.Key_J: case Qt.Key_Right: root.moveLayout(1); break;
        case Qt.Key_Return: case Qt.Key_Enter: root.restore(); break;
        default: return false;
        }
        return true;
    }

    Process {
        id: layoutsProc
        running: true
        command: ["python3", root.layoutScript, "--list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.savedLayouts = JSON.parse(text);
                    root.layoutIndex = Math.min(root.layoutIndex, Math.max(0, root.savedLayouts.length - 1));
                } catch (e) {
                    root.error = "Could not read saved layouts.";
                }
            }
        }
    }

    Connections {
        target: MonitorLayouts
        function onApplied(): void {
            queryProc.running = true;
            layoutsProc.running = true;
            if (root.mode === "save") {
                nameInput.text = "";
                root.setMode("place");
            }
        }
    }

    Process {
        id: queryProc
        running: true
        command: [root.script, "--query"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.anchorName = data.anchor ?? "";
                    root.targets = data.targets ?? [];
                    if (!root.targets.some(t => t.name === root.chosen))
                        root.chosen = root.targets.length ? root.targets[0].name : "";
                } catch (e) {
                    root.error = "Could not read the display layout.";
                }
            }
        }
    }

    onChosenTargetChanged: {
        if (root.chosenTarget && root.chosenTarget.current)
            root.sel = root.chosenTarget.current;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: if (!root.busy) root.closeRequested()
    }

    component SectionLabel: Text {
        required property string modeName
        color: root.mode === modeName ? Colors.accent : Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
        font.bold: root.mode === modeName
    }

    Item {
        id: card
        anchors.centerIn: parent
        width: Theme.menuW
        height: col.implicitHeight + Theme.pad
        focus: true

        Surface { anchors.fill: parent }
        MouseArea { anchors.fill: parent }

        Keys.onPressed: event => {
            if (root.busy) { event.accepted = true; return; }
            event.accepted = root.commonKey(event)
                || (root.mode === "place" && root.placeKey(event))
                || (root.mode === "layouts" && root.layoutsKey(event));
        }
        Component.onCompleted: card.forceActiveFocus()

        component Tile: Rectangle {
            id: tile
            required property string placement
            property int tileW: Theme.menuTileW
            readonly property bool picked: root.sel === tile.placement
            width: tile.tileW
            height: Theme.menuTileH
            radius: Theme.radius / 2
            color: tile.picked ? Colors.surface : Theme.surface
            border.width: 1
            border.color: tile.picked && root.mode === "place" ? Colors.accent : Theme.rule

            Column {
                anchors.centerIn: parent
                spacing: 1
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tile.placement
                    color: tile.picked ? Colors.accent : Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.chosenTarget && root.chosenTarget.current === tile.placement
                    text: "current"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: !root.busy
                onClicked: {
                    root.setMode("place");
                    root.sel = tile.placement;
                    root.apply();
                }
            }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.pad / 2
            spacing: 8

            // ---- place ----
            SectionLabel {
                modeName: "place"
                text: root.chosen
                    ? "Place " + root.chosen + (root.targets.length > 1 ? "   (o: next output)" : "")
                    : "Built-in display only"
            }

            Grid {
                visible: root.chosen !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 3
                spacing: 6
                Item { width: Theme.menuTileW; height: Theme.menuTileH }
                Tile { placement: "Above" }
                Item { width: Theme.menuTileW; height: Theme.menuTileH }
                Tile { placement: "Left" }
                Rectangle {
                    width: Theme.menuTileW
                    height: Theme.menuTileH
                    radius: Theme.radius / 2
                    color: Theme.barPill
                    border.width: 1
                    border.color: Theme.divider
                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        text: root.anchorName
                        elide: Text.ElideRight
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fsLabel
                    }
                }
                Tile { placement: "Right" }
                Item { width: Theme.menuTileW; height: Theme.menuTileH }
                Tile { placement: "Below" }
                Item { width: Theme.menuTileW; height: Theme.menuTileH }
            }

            Row {
                visible: root.chosen !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Tile { placement: "Mirror"; tileW: Theme.menuTileW * 1.5 }
                Tile { placement: "Disable"; tileW: Theme.menuTileW * 1.5 }
            }

            // ---- layouts ----
            SectionLabel { modeName: "layouts"; text: "Saved layouts" }

            Text {
                visible: root.savedLayouts.length === 0
                text: "None yet — press s to save the current one."
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
            }

            ListView {
                id: layoutList
                width: col.width
                height: Math.min(root.savedLayouts.length, 4) * Theme.menuRowH
                visible: root.savedLayouts.length > 0
                clip: true
                model: root.savedLayouts
                currentIndex: root.layoutIndex
                boundsBehavior: Flickable.StopAtBounds
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: height

                delegate: Rectangle {
                    id: layoutRow
                    required property int index
                    required property string modelData
                    readonly property bool current: layoutRow.index === root.layoutIndex && root.mode === "layouts"
                    width: layoutList.width
                    height: Theme.menuRowH
                    radius: Theme.radius / 2
                    color: layoutRow.current ? Colors.surface : "transparent"

                    Rectangle {
                        width: 3
                        height: parent.height - 8
                        radius: 2
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.accent
                        visible: layoutRow.current
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: layoutRow.modelData
                        elide: Text.ElideRight
                        color: layoutRow.current ? Colors.accent : Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fsValue
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.busy
                        onClicked: {
                            root.layoutIndex = layoutRow.index;
                            root.restore();
                        }
                    }
                }
            }

            // ---- save ----
            SectionLabel { modeName: "save"; text: "Save current layout as" }

            Rectangle {
                width: col.width
                height: nameInput.implicitHeight + 16
                radius: Theme.radius / 2
                color: Theme.surface
                border.width: 1
                border.color: nameInput.activeFocus ? Colors.accent : Theme.rule

                Text {
                    visible: nameInput.text === ""
                    text: root.mode === "save" ? "Layout name, Enter to save" : "Press s to name and save"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextInput {
                    id: nameInput
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                    color: Theme.fg
                    clip: true
                    readOnly: root.busy
                    activeFocusOnPress: false

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (!root.busy) root.save();
                            event.accepted = true;
                        } else {
                            event.accepted = root.commonKey(event);
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.setMode("save")
                }
            }

            // ---- status + hints ----
            Text {
                width: col.width
                text: root.error || MonitorLayouts.error || (root.busy ? "Applying…" : MonitorLayouts.status)
                    || (root.chosenTarget?.description ?? "")
                visible: text !== ""
                color: root.error || MonitorLayouts.error ? Theme.red : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
                wrapMode: Text.Wrap
            }

            Text {
                width: col.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
                text: {
                    switch (root.mode) {
                    case "layouts": return "↑↓/jk pick · Enter restore · Tab next · Esc back";
                    case "save": return "type a name · Enter save · Tab next · Esc back";
                    default: return "←→↑↓/hjkl place · m mirror · d disable · Enter apply"
                        + (root.targets.length > 1 ? " · o output" : "")
                        + "\n/ layouts · s save · Tab next · Esc close";
                    }
                }
            }
        }
    }
}
