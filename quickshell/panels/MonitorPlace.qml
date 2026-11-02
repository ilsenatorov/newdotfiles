pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../ui"
import "../services"

// SUPER+T, m. Keyboard-only by design: every action is a key in one of
// three modes, and the hint line always lists the keys for the current mode.
//   arrange -- a scaled map of every output. Arrows/hjkl select a screen,
//              Shift+arrows step it to the next edge/centre of the others,
//              r/R rotate, m cycles mirroring, d disables. Edits stay a draft
//              until Enter applies them all at once; Esc reverts.
//   layouts -- saved layouts; Up/Down pick, Enter restores
//   save    -- type a name, Enter saves the current layout
// Tab / Shift+Tab (or / and s from arrange) switch modes; Esc backs out to
// arrange, then closes. monitor-layout.py does the reading (--current) and
// applying (--set), and remembers what was applied for this display set.
Item {
    id: root

    signal closeRequested

    readonly property string layoutScript: Quickshell.shellPath("../hypr/scripts/monitor-layout.py")
    readonly property bool busy: MonitorLayouts.busy
    readonly property var modes: ["arrange", "layouts", "save"]
    property string mode: "arrange"
    // The live layout as JSON, and the copy being edited. Entries are
    // monitor-layout.py --current's, with position split into numeric x/y.
    property string appliedJson: ""
    property var draft: []
    property int selIndex: 0
    property var savedLayouts: []
    property int layoutIndex: 0
    property string error: ""
    readonly property bool dirty: JSON.stringify(root.draft) !== root.appliedJson
    readonly property var sel: root.draft[root.selIndex] ?? null
    readonly property var overlapping: {
        const live = root.draft.filter(root.independent);
        return live.filter(a => live.some(b => {
            if (a === b) return false;
            const sa = root.size(a), sb = root.size(b);
            return a.x < b.x + sb.w && b.x < a.x + sa.w && a.y < b.y + sb.h && b.y < a.y + sa.h;
        })).map(m => m.name);
    }

    // Laid-out (rotated) logical size; w/h from --current are unrotated.
    function size(m: var): var {
        return m.transform % 2 ? { w: m.h, h: m.w } : { w: m.w, h: m.h };
    }

    function independent(m: var): bool {
        return !m.disabled && m.mirror === "";
    }

    function nameOf(identity: string): string {
        return root.draft.find(m => m.identity === identity)?.name ?? identity;
    }

    // Other screens that occupy space, i.e. what the selection snaps against.
    function others(): var {
        return root.draft.filter((m, i) => i !== root.selIndex && root.independent(m));
    }

    function edit(changes: var): void {
        if (!root.sel) return;
        const next = root.draft.slice();
        next[root.selIndex] = Object.assign({}, root.sel, changes);
        root.draft = next;
    }

    function run(command: var, message: string): void {
        if (root.busy) return;
        root.error = "";
        MonitorLayouts.run(command, message);
    }

    // Select the nearest screen whose centre lies in direction (dx, dy),
    // favouring ones straight ahead over ones off to the side.
    function navigate(dx: int, dy: int): void {
        if (!root.sel) return;
        const s = root.size(root.sel);
        const cx = root.sel.x + s.w / 2, cy = root.sel.y + s.h / 2;
        let best = -1, bestScore = Infinity;
        root.draft.forEach((m, i) => {
            const ms = root.size(m);
            const ex = m.x + ms.w / 2 - cx, ey = m.y + ms.h / 2 - cy;
            const along = ex * dx + ey * dy;
            const score = along + 2 * Math.abs(ex * dy + ey * dx);
            if (i !== root.selIndex && along > 0 && score < bestScore) {
                best = i;
                bestScore = score;
            }
        });
        if (best >= 0) root.selIndex = best;
    }

    // Step to the closest snap stop in that direction: flush outside either
    // edge of another screen, aligned with either edge, or centred on it.
    function move(dx: int, dy: int): void {
        if (!root.sel) return;
        const horizontal = dx !== 0, dir = dx + dy;
        const pos = horizontal ? root.sel.x : root.sel.y;
        const len = horizontal ? root.size(root.sel).w : root.size(root.sel).h;
        let best = null;
        for (const o of root.others()) {
            const start = horizontal ? o.x : o.y;
            const olen = horizontal ? root.size(o).w : root.size(o).h;
            for (const c of [start - len, start, start + Math.round((olen - len) / 2), start + olen - len, start + olen]) {
                if ((c - pos) * dir > 0 && (best === null || Math.abs(c - pos) < Math.abs(best - pos)))
                    best = c;
            }
        }
        if (best !== null) root.edit(horizontal ? { x: best } : { y: best });
    }

    // 90° clockwise (step 1) or counter-clockwise (-1), keeping any flip bit.
    // A screen sitting on top of / left of another keeps that shared edge.
    function rotate(step: int): void {
        if (!root.sel) return;
        const m = root.sel, s = root.size(m), others = root.others();
        const transform = (m.transform & 4) | ((m.transform + step + 4) & 3);
        const n = root.size(Object.assign({}, m, { transform: transform }));
        root.edit({
            transform: transform,
            x: others.some(o => o.x === m.x + s.w) ? m.x + s.w - n.w : m.x,
            y: others.some(o => o.y === m.y + s.h) ? m.y + s.h - n.h : m.y
        });
    }

    // Off -> mirror each other independent screen in turn -> off.
    function cycleMirror(): void {
        if (!root.sel) return;
        const sources = root.others().map(o => o.identity);
        const i = sources.indexOf(root.sel.mirror);
        root.edit({ mirror: i + 1 < sources.length ? sources[i + 1] : "", disabled: false });
    }

    function apply(): void {
        if (!root.dirty) return;
        const layout = root.draft.map(m => ({
            identity: m.identity, mode: m.mode, position: m.x + "x" + m.y,
            scale: m.scale, transform: m.transform, disabled: m.disabled, mirror: m.mirror
        }));
        root.run(["python3", root.layoutScript, "--set", JSON.stringify(layout)], "Layout applied");
    }

    function save(): void {
        const name = nameInput.text.trim();
        if (root.dirty) root.error = "Apply (Enter) or revert (Esc) the draft first.";
        else if (name === "") root.error = "Enter a layout name.";
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

    function moveLayout(step: int): void {
        const n = root.savedLayouts.length;
        if (n > 0) root.layoutIndex = (root.layoutIndex + step + n) % n;
    }

    // Keys shared by every mode. Returns true when handled.
    function commonKey(event: var): bool {
        if (event.key === Qt.Key_Escape) {
            if (root.mode !== "arrange") root.setMode("arrange");
            else if (root.dirty) root.draft = JSON.parse(root.appliedJson);
            // Clean arrange: fall through to shell.qml (close, or back to
            // the SUPER+T hub).
            else return false;
        } else if (event.key === Qt.Key_Tab) {
            root.cycleMode(1);
        } else if (event.key === Qt.Key_Backtab) {
            root.cycleMode(-1);
        } else {
            return false;
        }
        return true;
    }

    function arrangeKey(event: var): bool {
        const dirs = {
            [Qt.Key_Left]: [-1, 0], [Qt.Key_H]: [-1, 0],
            [Qt.Key_Right]: [1, 0], [Qt.Key_L]: [1, 0],
            [Qt.Key_Up]: [0, -1], [Qt.Key_K]: [0, -1],
            [Qt.Key_Down]: [0, 1], [Qt.Key_J]: [0, 1]
        };
        const d = dirs[event.key];
        if (d) {
            if (event.modifiers & Qt.ShiftModifier) root.move(d[0], d[1]);
            else root.navigate(d[0], d[1]);
            return true;
        }
        switch (event.key) {
        case Qt.Key_R: root.rotate(event.modifiers & Qt.ShiftModifier ? -1 : 1); break;
        case Qt.Key_M: root.cycleMirror(); break;
        case Qt.Key_D: root.edit({ disabled: !root.sel?.disabled, mirror: "" }); break;
        case Qt.Key_O: if (root.draft.length) root.selIndex = (root.selIndex + 1) % root.draft.length; break;
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
        id: currentProc
        running: true
        command: ["python3", root.layoutScript, "--current"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keep = root.sel?.identity;
                    const list = JSON.parse(text).map(m => {
                        const [x, y] = m.position.split("x").map(Number);
                        delete m.position;
                        return Object.assign(m, { x: x, y: y });
                    });
                    root.appliedJson = JSON.stringify(list);
                    root.draft = list;
                    root.selIndex = Math.max(0, list.findIndex(m => keep
                        ? m.identity === keep : m.name === Hyprland.focusedMonitor?.name));
                } catch (e) {
                    root.error = "Could not read the display layout.";
                }
            }
        }
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
            currentProc.running = true;
            layoutsProc.running = true;
            if (root.mode === "save") {
                nameInput.text = "";
                root.setMode("arrange");
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: if (!root.busy) root.closeRequested()
    }

    // Lights up the real screen behind the selected tile: an accent flash when
    // the selection lands on it, then an outline and its name while it stays
    // selected. Overlay layer, no focus, empty input mask -- like the OSD.
    PanelWindow {
        id: highlight
        readonly property string target: root.mode === "arrange" ? (root.sel?.name ?? "") : ""
        readonly property var targetScreen: Quickshell.screens.find(s => s.name === highlight.target) ?? null
        screen: highlight.targetScreen
        visible: highlight.targetScreen !== null
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-monitor-highlight"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        onTargetChanged: if (highlight.target !== "") flash.restart()

        Rectangle {
            id: flashFill
            anchors.fill: parent
            color: Colors.accent
            opacity: 0
        }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: Math.round(6 * Theme.s)
            border.color: Colors.accent
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.osdBottom
            width: label.implicitWidth + Theme.pad * 2
            height: label.implicitHeight + Theme.pad
            radius: Theme.radius
            color: Theme.barPill
            border.width: 2
            border.color: Colors.accent
            Text {
                id: label
                anchors.centerIn: parent
                text: highlight.target
                color: Colors.accent
                font.family: Theme.font
                font.pixelSize: Math.round(40 * Theme.s)
                font.bold: true
            }
        }
        SequentialAnimation {
            id: flash
            NumberAnimation { target: flashFill; property: "opacity"; from: 0; to: 0.35; duration: 90 }
            NumberAnimation { target: flashFill; property: "opacity"; to: 0; duration: 450; easing.type: Easing.OutCubic }
        }
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
                || (root.mode === "arrange" && root.arrangeKey(event))
                || (root.mode === "layouts" && root.layoutsKey(event));
        }
        Component.onCompleted: card.forceActiveFocus()

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.pad / 2
            spacing: Math.round(8 * Theme.s)

            // ---- arrange ----
            SectionLabel {
                modeName: "arrange"
                text: "Arrange displays" + (root.dirty ? "  ·  unapplied changes" : "")
            }

            Rectangle {
                id: map
                width: col.width
                height: Theme.menuMapH
                radius: Theme.radius / 2
                color: Theme.barPill
                border.width: 1
                border.color: Theme.divider

                readonly property int margin: Math.round(14 * Theme.s)
                // Bounding box of every output in layout coordinates.
                readonly property var box: {
                    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
                    for (const m of root.draft) {
                        const s = root.size(m);
                        x0 = Math.min(x0, m.x);
                        y0 = Math.min(y0, m.y);
                        x1 = Math.max(x1, m.x + s.w);
                        y1 = Math.max(y1, m.y + s.h);
                    }
                    return root.draft.length ? { x: x0, y: y0, w: x1 - x0, h: y1 - y0 } : { x: 0, y: 0, w: 1, h: 1 };
                }
                readonly property real k: Math.min((width - 2 * margin) / box.w, (height - 2 * margin) / box.h)
                readonly property real ox: (width - box.w * k) / 2
                readonly property real oy: (height - box.h * k) / 2

                // Indexed by count, not by the array, so delegates survive
                // edits and the Behaviors below animate each move.
                Repeater {
                    model: root.draft.length

                    delegate: Rectangle {
                        id: screen
                        required property int index
                        readonly property var m: root.draft[screen.index] ?? {}
                        readonly property var dims: root.size(screen.m)
                        readonly property bool picked: screen.index === root.selIndex
                        readonly property string rotation: (screen.m.transform & 3) ? " · " + (screen.m.transform & 3) * 90 + "°" : ""

                        x: map.ox + (screen.m.x - map.box.x) * map.k
                        y: map.oy + (screen.m.y - map.box.y) * map.k
                        width: Math.max(1, screen.dims.w * map.k)
                        height: Math.max(1, screen.dims.h * map.k)
                        z: screen.picked ? 1 : 0
                        radius: Math.round(4 * Theme.s)
                        color: screen.picked ? Colors.surface : Theme.surface
                        opacity: screen.m.disabled ? 0.45 : screen.m.mirror ? 0.7 : 1
                        border.width: screen.picked ? 2 : 1
                        border.color: root.overlapping.includes(screen.m.name) ? Theme.red
                            : screen.picked && root.mode === "arrange" ? Colors.accent : Theme.rule

                        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - Math.round(6 * Theme.s)
                            spacing: 1
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: screen.m.name ?? ""
                                color: screen.picked ? Colors.accent : Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.fsValue
                                font.bold: screen.picked
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: screen.m.disabled ? "off"
                                    : screen.m.mirror ? "mirrors " + root.nameOf(screen.m.mirror)
                                    : (screen.m.mode ?? "").split("@")[0] + screen.rotation
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fsLabel
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.busy
                            onClicked: {
                                root.setMode("arrange");
                                root.selIndex = screen.index;
                            }
                        }
                    }
                }
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
                        width: Math.round(3 * Theme.s)
                        height: parent.height - Math.round(8 * Theme.s)
                        radius: Math.round(2 * Theme.s)
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.accent
                        visible: layoutRow.current
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Math.round(10 * Theme.s)
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
                height: nameInput.implicitHeight + Math.round(16 * Theme.s)
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
                    anchors.leftMargin: Math.round(10 * Theme.s)
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextInput {
                    id: nameInput
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Math.round(10 * Theme.s)
                    anchors.rightMargin: Math.round(10 * Theme.s)
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
                readonly property bool bad: root.error !== "" || MonitorLayouts.error !== "" || root.overlapping.length > 0
                width: col.width
                text: root.error || MonitorLayouts.error || (root.busy ? "Applying…"
                    : root.overlapping.length ? "Overlapping: " + root.overlapping.join(", ")
                    : root.dirty ? "Enter applies the draft, Esc reverts it."
                    : MonitorLayouts.status || (root.sel?.description ?? ""))
                visible: text !== ""
                color: bad ? Theme.red : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
                wrapMode: Text.Wrap
            }

            KeyHints {
                width: col.width
                hints: {
                    switch (root.mode) {
                    case "layouts": return [["↑↓", "pick"], ["↵", "restore"], ["tab", "next"], ["esc", "back"]];
                    case "save": return [["↵", "save"], ["tab", "next"], ["esc", "back"]];
                    default: return [["←→↑↓", "select"], ["shift+←→↑↓", "move"], ["r/R", "rotate"],
                        ["m", "mirror"], ["d", "disable"], ["↵", "apply"],
                        ["esc", root.dirty ? "revert" : "close"], ["/", "layouts"], ["s", "save"]];
                    }
                }
            }
        }
    }
}
