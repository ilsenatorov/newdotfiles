pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../ui"
import "../services"

// SUPER+T, m. Every action is a key in one of four modes, and the hint line
// always lists the keys for the current mode.
//   arrange    -- a scaled map of every output. Arrows/hjkl select a screen,
//                 Shift+arrows step it to the next edge/centre of the others,
//                 or drag it with the mouse to the nearest of them. r/R rotate,
//                 m cycles mirroring, d disables. Edits stay a draft until
//                 Enter applies them all at once; Esc reverts.
//   workspaces -- same map and draft. Arrows select a screen (no hjkl: L and J
//                 are workspace letters), a workspace's SUPER letter pulls it
//                 onto that screen, or drag its letter onto one with the mouse.
//                 r drops the assignment for the default split right away.
//   layouts    -- saved layouts; Up/Down pick, Enter restores
//   save       -- type a name, Enter saves the current layout
// Tab / Shift+Tab (or w, / and s from arrange) switch modes; Esc backs out to
// arrange, then closes. monitor-layout.py does the reading (--current) and
// applying (--set), and remembers what was applied for this display set.
Item {
    id: root

    signal closeRequested

    readonly property string layoutScript: Quickshell.shellPath("../hypr/scripts/monitor-layout.py")
    readonly property bool busy: MonitorLayouts.busy
    readonly property var modes: ["arrange", "workspaces", "layouts", "save"]
    property string mode: "arrange"
    // Both draw the screen map as live: selection outlined, real screen lit.
    readonly property bool onMap: root.mode === "arrange" || root.mode === "workspaces"
    // The live layout as JSON, and the copy being edited. Entries are
    // monitor-layout.py --current's, with position split into numeric x/y.
    property string appliedJson: ""
    property var draft: []
    property int selIndex: 0
    // Workspace id whose letter is being dragged, 0 for none.
    property int dragWorkspace: 0
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

    // Snap stops for the selection along one axis: flush outside either edge
    // of another screen, aligned with either edge, or centred on it.
    function stops(horizontal: bool): var {
        const len = horizontal ? root.size(root.sel).w : root.size(root.sel).h;
        const all = [];
        for (const o of root.others()) {
            const start = horizontal ? o.x : o.y;
            const olen = horizontal ? root.size(o).w : root.size(o).h;
            all.push(start - len, start, start + Math.round((olen - len) / 2), start + olen - len, start + olen);
        }
        return all;
    }

    // Step to the closest stop in that direction.
    function move(dx: int, dy: int): void {
        if (!root.sel) return;
        const horizontal = dx !== 0, dir = dx + dy;
        const pos = horizontal ? root.sel.x : root.sel.y;
        let best = null;
        for (const c of root.stops(horizontal)) {
            if ((c - pos) * dir > 0 && (best === null || Math.abs(c - pos) < Math.abs(best - pos)))
                best = c;
        }
        if (best !== null) root.edit(horizontal ? { x: best } : { y: best });
    }

    // The stop nearest to wanted, or home: where a drag started may not be a
    // stop, and a click's jitter shouldn't move the screen off it.
    function snap(horizontal: bool, home: real, wanted: real): real {
        return root.stops(horizontal).reduce((best, c) =>
            Math.abs(c - wanted) < Math.abs(best - wanted) ? c : best, home);
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

    // Move workspace id onto the selected screen. Hyprland would invent a new
    // workspace for a screen left with none, so the last one has to stay.
    function pullWorkspace(id: int): void {
        root.error = "";
        const target = root.sel;
        if (!target) return;
        const from = root.draft.find(m => m.workspaces.includes(id));
        if (!root.independent(target))
            root.error = target.name + " is " + (target.disabled ? "off" : "mirroring") + ", so it can't hold workspaces.";
        else if (from === target)
            return;
        else if (from?.workspaces.length === 1)
            root.error = from.name + " has to keep at least one workspace.";
        else
            root.draft = root.draft.map(m => Object.assign({}, m, {
                workspaces: m === target ? m.workspaces.concat(id).sort((a, b) => a - b)
                    : m.workspaces.filter(w => w !== id)
            }));
    }

    // Applied at once: no pins left means Lua's split follows the screens again.
    // Discards unapplied workspace moves, but not unapplied screen edits.
    function resetWorkspaces(): void {
        if (!root.sel) return;
        const geometry = list => JSON.stringify(list.map(m => Object.assign({}, m, { workspaces: [] })));
        if (geometry(root.draft) !== geometry(JSON.parse(root.appliedJson)))
            root.error = "Apply (Enter) or revert (Esc) the screen changes first.";
        else
            root.run(["python3", root.layoutScript, "--reset-workspaces"], "Workspaces reset to default");
    }

    function apply(): void {
        if (!root.dirty) return;
        const layout = root.draft.map(m => ({
            identity: m.identity, mode: m.mode, position: m.x + "x" + m.y,
            scale: m.scale, transform: m.transform, disabled: m.disabled, mirror: m.mirror,
            workspaces: m.workspaces
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
        case Qt.Key_W: root.setMode("workspaces"); break;
        case Qt.Key_S: root.setMode("save"); break;
        case Qt.Key_Slash: root.setMode("layouts"); break;
        case Qt.Key_Return: case Qt.Key_Enter: root.apply(); break;
        default: return false;
        }
        return true;
    }

    function workspacesKey(event: var): bool {
        switch (event.key) {
        case Qt.Key_Left: root.navigate(-1, 0); return true;
        case Qt.Key_Right: root.navigate(1, 0); return true;
        case Qt.Key_Up: root.navigate(0, -1); return true;
        case Qt.Key_Down: root.navigate(0, 1); return true;
        case Qt.Key_R: root.resetWorkspaces(); return true;
        case Qt.Key_Return: case Qt.Key_Enter: root.apply(); return true;
        }
        const i = Theme.wsKeys.indexOf(event.text.toUpperCase());
        if (i < 0) return false;
        root.pullWorkspace(i + 1);
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
                    root.dragWorkspace = 0;
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
        readonly property string target: root.onMap ? (root.sel?.name ?? "") : ""
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
            // A drag's chip must outlive the drag, so nothing edits the draft meanwhile.
            if (root.busy || root.dragWorkspace || map.frozenBox) { event.accepted = true; return; }
            event.accepted = root.commonKey(event)
                || (root.mode === "arrange" && root.arrangeKey(event))
                || (root.mode === "workspaces" && root.workspacesKey(event))
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

            // ---- arrange / workspaces ----
            SectionLabel {
                modeName: root.mode === "workspaces" ? "workspaces" : "arrange"
                text: (root.mode === "workspaces" ? "Assign workspaces" : "Arrange displays")
                    + (root.dirty ? "  ·  unapplied changes" : "")
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
                // Set while a screen is dragged: rescaling the map under the
                // cursor would make the screen run away from it.
                property var frozenBox: null
                // Bounding box of every output in layout coordinates.
                readonly property var box: {
                    if (map.frozenBox) return map.frozenBox;
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
                property point dragPos

                // Index of the tile under a map point, -1 for none. Off and
                // mirroring screens can share space with one holding workspaces,
                // which wins.
                function screenAt(px: real, py: real): int {
                    const x = (px - map.ox) / map.k + map.box.x, y = (py - map.oy) / map.k + map.box.y;
                    const hits = root.draft.map((m, i) => i).filter(i => {
                        const m = root.draft[i], s = root.size(m);
                        return x >= m.x && x < m.x + s.w && y >= m.y && y < m.y + s.h;
                    });
                    return hits.find(i => root.independent(root.draft[i])) ?? hits[0] ?? -1;
                }

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
                            : screen.picked && root.onMap ? Colors.accent : Theme.rule

                        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        Column {
                            anchors.centerIn: parent
                            z: 1 // Above the tile's MouseArea, for the letters' own.
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
                            Flow {
                                id: letters
                                readonly property var ids: screen.m.workspaces ?? []
                                readonly property int chipSize: Theme.fsLabel + Math.round(8 * Theme.s)
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: letters.ids.length > 0
                                width: Math.min(parent.width, letters.ids.length * (letters.chipSize + letters.spacing))
                                spacing: Math.round(2 * Theme.s)

                                Repeater {
                                    model: letters.ids

                                    delegate: Rectangle {
                                        id: chip
                                        required property int modelData
                                        readonly property bool active: root.mode === "workspaces"
                                        width: letters.chipSize
                                        height: letters.chipSize
                                        radius: Math.round(3 * Theme.s)
                                        color: "transparent"
                                        border.width: chip.active ? 1 : 0
                                        border.color: Colors.accent
                                        opacity: root.dragWorkspace === chip.modelData ? 0.3 : 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: Theme.wsKeys[chip.modelData - 1] ?? chip.modelData
                                            color: chip.active ? Colors.accent : Theme.dim
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fsLabel
                                            font.bold: chip.active
                                        }

                                        MouseArea {
                                            id: chipArea
                                            anchors.fill: parent
                                            enabled: chip.active && !root.busy
                                            cursorShape: chipArea.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                                            // Selecting the tile under the cursor outlines it and
                                            // lights the real screen, so that's the hover feedback.
                                            function track(mouse: var): int {
                                                map.dragPos = chipArea.mapToItem(map, mouse.x, mouse.y);
                                                const i = map.screenAt(map.dragPos.x, map.dragPos.y);
                                                if (i >= 0) root.selIndex = i;
                                                return i;
                                            }

                                            onPressed: mouse => {
                                                root.dragWorkspace = chip.modelData;
                                                chipArea.track(mouse);
                                            }
                                            onPositionChanged: mouse => chipArea.track(mouse)
                                            onCanceled: root.dragWorkspace = 0
                                            onReleased: mouse => {
                                                root.dragWorkspace = 0;
                                                if (chipArea.track(mouse) >= 0) root.pullWorkspace(chip.modelData);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: tileArea
                            // Where the drag started, on screen and on the map.
                            property var grab: null
                            anchors.fill: parent
                            enabled: !root.busy
                            cursorShape: root.mode !== "arrange" ? Qt.ArrowCursor
                                : tileArea.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                            function begin(mouse: var): void {
                                if (root.mode !== "arrange") return;
                                root.selIndex = screen.index;
                                map.frozenBox = map.box;
                                const p = tileArea.mapToItem(map, mouse.x, mouse.y);
                                tileArea.grab = { x: screen.m.x, y: screen.m.y, px: p.x, py: p.y };
                            }
                            function dragTo(mouse: var): void {
                                const g = tileArea.grab;
                                if (!g) return;
                                const p = tileArea.mapToItem(map, mouse.x, mouse.y);
                                root.edit({
                                    x: root.snap(true, g.x, g.x + (p.x - g.px) / map.k),
                                    y: root.snap(false, g.y, g.y + (p.y - g.py) / map.k)
                                });
                            }
                            function end(): void {
                                tileArea.grab = null;
                                map.frozenBox = null;
                            }

                            onPressed: mouse => tileArea.begin(mouse)
                            onPositionChanged: mouse => tileArea.dragTo(mouse)
                            onReleased: tileArea.end()
                            onCanceled: tileArea.end()
                            onClicked: {
                                if (!root.onMap) root.setMode("arrange");
                                root.selIndex = screen.index;
                            }
                        }
                    }
                }

                // The letter being dragged, following the cursor above the tiles.
                Rectangle {
                    visible: root.dragWorkspace > 0
                    z: 2
                    width: ghostLabel.implicitWidth + Math.round(12 * Theme.s)
                    height: ghostLabel.implicitHeight + Math.round(6 * Theme.s)
                    x: map.dragPos.x - width / 2
                    y: map.dragPos.y - height / 2
                    radius: Math.round(3 * Theme.s)
                    color: Theme.barPill
                    border.width: 2
                    border.color: Colors.accent

                    Text {
                        id: ghostLabel
                        anchors.centerIn: parent
                        text: Theme.wsKeys[root.dragWorkspace - 1] ?? root.dragWorkspace
                        color: Colors.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.fsValue
                        font.bold: true
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
                    case "workspaces": return [["←→↑↓", "screen"], ["letter/drag", "pull here"], ["r", "reset"],
                        ["↵", "apply"], ["tab", "next"], ["esc", "back"]];
                    default: return [["←→↑↓", "select"], ["shift+←→↑↓/drag", "move"], ["r/R", "rotate"],
                        ["m", "mirror"], ["d", "disable"], ["↵", "apply"],
                        ["esc", root.dirty ? "revert" : "close"], ["w", "workspaces"], ["/", "layouts"], ["s", "save"]];
                    }
                }
            }
        }
    }
}
