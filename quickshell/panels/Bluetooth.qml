import QtQuick
import Quickshell.Bluetooth
import ".."
import "../services"

// Replaces rofi-bluetooth (SUPER+D, b). Live Bluez state via
// Quickshell.Bluetooth -- no bluetoothctl scraping -- and everything
// bluetoothctl itself does: power, scan, discoverable, pairable, pair /
// cancel, trust, block, wake, connect / disconnect, remove, device alias,
// controller alias, and picking between controllers. PIN/passkey prompts
// come from the session agent (blueman-applet), same as bluetoothctl would
// defer to.
//
// Keyboard-first, mirroring the Network panel -- the hint row at the bottom
// always shows what's live:
//   j/k ↑/↓ move   g/G Home/End   PgUp/PgDn   ↵/Space pair+connect / disconnect
//   c connect only   r/F5 scan   / filter   d/Del forget   t trust   b block
//   e wake   n rename   N rename controller   u unnamed devices   i details
//   w ←/→ power   v visible   p pairable   a next controller   Esc back/close
// shell.qml grabs keyboard focus onto this root the moment the panel opens.
Column {
    id: root
    width: parent ? parent.width : Theme.panelW
    spacing: 8
    focus: true

    readonly property var adapter: Bt.adapter
    readonly property int rowH: Math.round(42 * Theme.s)
    readonly property int maxRows: 7

    // Every selectable row in display order: { dev } per device, then an
    // { unnamed: n } row that reveals the nameless LE advertisers a scan
    // turns up by the dozen. Rebuilt imperatively (resort()) like Network's
    // list, so a device flipping state doesn't reshuffle under the cursor
    // unless the order actually changed.
    property var entries: []
    property int currentIndex: -1
    readonly property var current: currentIndex >= 0 && currentIndex < entries.length ? entries[currentIndex] : null
    readonly property var currentDev: current && current.dev ? current.dev : null
    property bool showUnnamed: false
    property string orderKey: ""
    // Until the user moves, keep re-picking the default row -- devices
    // trickle in after the panel opens, and the first build is often just
    // the connected ones.
    property bool userMoved: false

    // Disconnecting takes a second ↵/click within a few seconds, same as
    // Network -- a stray Enter shouldn't drop your headphones.
    property string confirmKey: ""

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root.confirmKey = ""
    }

    property bool filtering: false
    property string filter: ""
    property bool detailsShown: false

    // Inline rename form. formKind: "" (closed) / "device" / "adapter".
    property string formKind: ""
    property string formAddress: ""
    property string formError: ""
    readonly property bool formOpen: formKind !== ""

    // Scan while the panel is open -- but only stop on close what we started
    // (a bluetoothctl `scan on` elsewhere keeps running).
    property bool startedScan: false

    // See Network.qml's Component.onCompleted for why forceActiveFocus() is
    // needed on top of `focus: true`.
    Component.onCompleted: {
        root.forceActiveFocus();
        startScan();
        resort();
    }
    Component.onDestruction: {
        if (root.startedScan && Bt.available && root.adapter.discovering) root.adapter.discovering = false;
    }

    function startScan(): void {
        if (!Bt.powered || root.adapter.discovering) return;
        root.adapter.discovering = true;
        root.startedScan = true;
    }

    function toggleScan(): void {
        if (!Bt.powered) return;
        if (root.adapter.discovering) {
            root.adapter.discovering = false;
            root.startedScan = false;
        } else {
            startScan();
        }
    }

    onAdapterChanged: resortTimer.restart()
    onShowUnnamedChanged: resort()
    onFilterChanged: {
        root.currentIndex = -1;
        root.userMoved = false;
        resort();
    }

    Connections {
        target: Bt
        function onPoweredChanged(): void {
            if (Bt.powered) powerOnScan.restart();
            resortTimer.restart();
        }
    }
    Connections {
        target: root.adapter ? root.adapter.devices : null
        function onValuesChanged(): void { resortTimer.restart(); }
    }

    Timer {
        id: resortTimer
        interval: 150
        // Device objects may have been replaced under the same address
        // (forget, then rediscovered) -- force a real rebuild.
        onTriggered: {
            root.orderKey = "";
            root.resort();
        }
    }

    // Name resolution, pairing and connecting all move rows between groups
    // without touching the device list itself; resort() is a no-op unless
    // the order really changed.
    Timer {
        interval: 1000
        repeat: true
        running: Bt.powered
        onTriggered: root.resort()
    }

    // The controller refuses StartDiscovery for a moment after powering on.
    Timer {
        id: powerOnScan
        interval: 1500
        onTriggered: root.startScan()
    }

    function entryKey(e: var): string {
        if (!e) return "";
        if (e.unnamed !== undefined) return "unnamed";
        return e.dev.address;
    }

    function named(d: var): bool {
        return d.deviceName !== "" || d.paired || d.connected || d.trusted;
    }

    function matches(d: var): bool {
        if (root.filter === "") return true;
        const f = root.filter.toLowerCase();
        return d.name.toLowerCase().indexOf(f) >= 0 || d.address.toLowerCase().indexOf(f) >= 0;
    }

    function resort(): void {
        const selectedKey = entryKey(root.current);
        const next = [];

        if (Bt.powered) {
            const devs = [];
            let hidden = 0;
            for (const d of Bt.adapterDevices) {
                if (!matches(d)) continue;
                if (!named(d) && !root.showUnnamed && root.filter === "") { hidden++; continue; }
                devs.push(d);
            }
            devs.sort((a, b) => (b.connected - a.connected)
                || (b.paired - a.paired)
                || (b.trusted - a.trusted)
                || (named(b) - named(a))
                || a.name.localeCompare(b.name));
            for (const d of devs) next.push({ dev: d });
            if (hidden > 0 || root.showUnnamed) next.push({ unnamed: hidden });
        }

        const key = next.map(e => entryKey(e) + (e.unnamed ?? "")).join("|");
        if (key === root.orderKey) return;
        root.orderKey = key;
        root.entries = next;

        // Keep the same row selected across the reshuffle; on first build
        // (or after a filter change) start on the first idle device, so a
        // stray Enter doesn't drop a connection.
        let i = selectedKey === "" || !root.userMoved ? -1 : next.findIndex(e => entryKey(e) === selectedKey);
        if (i < 0) {
            i = next.findIndex(e => e.dev && !e.dev.connected);
            if (i < 0) i = next.length > 0 ? 0 : -1;
        }
        root.currentIndex = i;
    }

    // ↵: pair (then trust + connect) an unknown device, connect a paired
    // one, disconnect a connected one, cancel a pairing in progress.
    function activate(entry: var): void {
        if (!entry) return;
        if (entry.unnamed !== undefined) {
            root.showUnnamed = !root.showUnnamed;
            return;
        }
        const d = entry.dev;
        if (d.pairing) { Bt.cancelPair(d); return; }
        if (d.connected && root.confirmKey !== d.address) {
            root.confirmKey = d.address;
            confirmTimer.restart();
            return;
        }
        root.confirmKey = "";
        if (d.connected) d.disconnect();
        else if (d.paired) Bt.connectDevice(d);
        else Bt.pairDevice(d);
    }

    // c: bluetoothctl's bare `connect` -- no pairing (LE devices that don't
    // need a bond, or ones paired from the other side).
    function connectOnly(d: var): void {
        if (!d) return;
        if (d.connected) {
            root.confirmKey = d.address;
            activate({ dev: d });
        } else {
            Bt.connectDevice(d);
        }
    }

    function forget(d: var): void {
        if (!d) return;
        Bt.forgetDevice(d);
        resortTimer.restart();
    }

    function move(delta: int): void {
        root.userMoved = true;
        const count = root.entries.length;
        if (count === 0) return;
        if (root.currentIndex < 0) { root.currentIndex = 0; return; }
        root.currentIndex = Math.max(0, Math.min(count - 1, root.currentIndex + delta));
    }

    function wrapMove(delta: int): void {
        root.userMoved = true;
        const count = root.entries.length;
        if (count === 0) return;
        root.currentIndex = root.currentIndex < 0 ? 0 : (root.currentIndex + delta + count) % count;
    }

    function openFilter(): void {
        root.filtering = true;
        Qt.callLater(() => filterField.input.forceActiveFocus());
    }

    function closeFilter(): void {
        root.filtering = false;
        filterField.input.text = "";
        root.forceActiveFocus();
    }

    function openForm(kind: string): void {
        if (kind === "device" && !root.currentDev) return;
        if (kind === "adapter" && !Bt.available) return;
        root.formKind = kind;
        root.formAddress = kind === "device" ? root.currentDev.address : "";
        root.formError = "";
        nameField.input.text = kind === "device" ? root.currentDev.name : root.adapter.name;
        Qt.callLater(() => {
            nameField.input.forceActiveFocus();
            nameField.input.selectAll();
        });
    }

    function closeForm(): void {
        root.formKind = "";
        root.formError = "";
        if (root.filtering) filterField.input.forceActiveFocus();
        else root.forceActiveFocus();
    }

    // An empty device name resets the alias to what the device advertises
    // (Bluez's documented behaviour for an empty Alias).
    function submitForm(): void {
        const name = nameField.input.text.trim();
        if (root.formKind === "adapter") {
            if (name === "") { root.formError = "Enter a name"; return; }
            Bt.renameAdapter(name);
        } else {
            const d = Bt.findDevice(root.formAddress);
            if (!d) { root.formError = "Device went away"; return; }
            d.name = name;
            resortTimer.restart();
        }
        closeForm();
    }

    onCurrentIndexChanged: {
        root.confirmKey = "";
        if (currentIndex >= 0) list.positionViewAtIndex(currentIndex, ListView.Contain);
    }

    // ---- keys ----------------------------------------------------------------
    // One handler for everything, as in Network.qml: keys a focused
    // TextInput doesn't consume propagate up to here.
    Keys.onPressed: event => {
        const k = event.key;
        const mods = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
        const ctrl = event.modifiers & Qt.ControlModifier;
        const shift = event.modifiers & Qt.ShiftModifier;
        const done = () => { event.accepted = true; };
        const d = root.currentDev;

        if (root.formOpen) {
            if (k === Qt.Key_Escape) { root.closeForm(); done(); }
            return;
        }

        if (k === Qt.Key_Down || (ctrl && (k === Qt.Key_N || k === Qt.Key_J))) { root.wrapMove(1); done(); return; }
        if (k === Qt.Key_Up || (ctrl && (k === Qt.Key_P || k === Qt.Key_K))) { root.wrapMove(-1); done(); return; }
        if (k === Qt.Key_PageDown) { root.move(5); done(); return; }
        if (k === Qt.Key_PageUp) { root.move(-5); done(); return; }
        if (k === Qt.Key_Return || k === Qt.Key_Enter) { root.activate(root.current); done(); return; }
        if (k === Qt.Key_F5) { root.toggleScan(); done(); return; }
        if (k === Qt.Key_Escape) {
            if (root.filtering) { root.closeFilter(); done(); }
            return;
        }

        if (root.filtering) return;
        if (mods) return;

        switch (k) {
        case Qt.Key_J: root.wrapMove(1); break;
        case Qt.Key_K: root.wrapMove(-1); break;
        case Qt.Key_Home: root.move(-root.entries.length); break;
        case Qt.Key_End: root.move(root.entries.length); break;
        case Qt.Key_G: root.move(shift ? root.entries.length : -root.entries.length); break;
        case Qt.Key_Space: root.activate(root.current); break;
        case Qt.Key_C: root.connectOnly(d); break;
        case Qt.Key_R: root.toggleScan(); break;
        case Qt.Key_Slash: if (Bt.powered) root.openFilter(); break;
        case Qt.Key_D:
        case Qt.Key_Delete: root.forget(d); break;
        case Qt.Key_T: if (d) d.trusted = !d.trusted; break;
        case Qt.Key_B: if (d) d.blocked = !d.blocked; break;
        case Qt.Key_E: if (d) d.wakeAllowed = !d.wakeAllowed; break;
        case Qt.Key_N: root.openForm(shift ? "adapter" : "device"); break;
        case Qt.Key_U: root.showUnnamed = !root.showUnnamed; break;
        case Qt.Key_I: root.detailsShown = !root.detailsShown; break;
        case Qt.Key_W: Bt.togglePower(); break;
        case Qt.Key_Left: if (Bt.available) root.adapter.enabled = false; break;
        case Qt.Key_Right: if (Bt.available) root.adapter.enabled = true; break;
        case Qt.Key_V: if (Bt.powered) root.adapter.discoverable = !root.adapter.discoverable; break;
        case Qt.Key_P: if (Bt.powered) root.adapter.pairable = !root.adapter.pairable; break;
        case Qt.Key_A: Bt.nextAdapter(); break;
        default: return;
        }
        done();
    }

    // ---- reusable bits (same look as Network.qml's) ----------------------------
    component DevRow: Rectangle {
        id: devRow

        property string glyph: ""
        property string title: ""
        property string subtitle: ""
        property bool subtitleIsError: false
        property bool active: false
        property bool selected: false
        property bool forgettable: false
        property string battery: ""

        signal activated
        signal secondary
        signal forgetRequested

        height: Math.round(42 * Theme.s)
        radius: 8
        color: (rowArea.containsMouse || selected) ? Colors.surface : "transparent"
        border.width: selected ? 1 : 0
        border.color: Colors.accent

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => mouse.button === Qt.RightButton ? devRow.secondary() : devRow.activated()
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Text {
                id: glyphText
                width: Math.round(Theme.fsValue * 1.4)
                text: devRow.glyph
                font.family: Theme.font
                font.pixelSize: Theme.fsValue
                color: devRow.active ? Colors.accent : Theme.fg
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - glyphText.width - trailing.width - parent.spacing * 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: devRow.title
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                    color: devRow.active ? Colors.accent : Theme.fg
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: devRow.subtitle
                    font.family: Theme.font
                    font.pixelSize: Math.round(Theme.fsLabel * 0.85)
                    color: devRow.subtitleIsError ? Colors.urgent : Theme.dim
                    elide: Text.ElideRight
                }
            }

            Row {
                id: trailing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    visible: devRow.battery !== ""
                    text: devRow.battery
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel
                    color: Theme.dim
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Forget: bluetoothctl `remove` -- unpairs and drops the device.
                Text {
                    visible: devRow.forgettable
                    text: "󰆴"
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                    color: forgetArea.containsMouse ? Colors.urgent : Theme.dim
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        id: forgetArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: devRow.forgetRequested()
                    }
                }

                Text {
                    visible: devRow.active
                    text: "✓"
                    color: Colors.accent
                    font.pixelSize: Theme.fsValue
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    component Field: Rectangle {
        id: field

        property alias input: textInput
        property string placeholder: ""
        signal accepted

        width: parent.width
        height: Math.round(32 * Theme.s)
        radius: 6
        color: Theme.surface
        border.width: 1
        border.color: textInput.activeFocus ? Colors.accent : Theme.rule

        TextInput {
            id: textInput
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fsValue
            clip: true
            onAccepted: field.accepted()
        }

        Text {
            anchors.fill: textInput
            verticalAlignment: Text.AlignVCenter
            visible: textInput.text === ""
            text: field.placeholder
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
            elide: Text.ElideRight
        }
    }

    component Chip: Rectangle {
        id: chip

        property string label: ""
        property string key: ""
        property bool active: false
        signal clicked

        width: chipRow.implicitWidth + 20
        height: Math.round(26 * Theme.s)
        radius: height / 2
        color: active ? Colors.accent : "transparent"
        border.width: 1
        border.color: active ? Colors.accent : Theme.rule

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5

            Text {
                visible: chip.key !== ""
                text: chip.key
                color: chip.active ? Theme.surface : Colors.accent
                opacity: 0.7
                font.family: Theme.font
                font.pixelSize: Math.round(Theme.fsLabel * 0.85)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: chip.label
                color: chip.active ? Theme.surface : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea { anchors.fill: parent; onClicked: chip.clicked() }
    }

    component SectionLabel: Text {
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
        font.bold: true
        color: Theme.dim
    }

    // ---- controller header: name, scan, power ------------------------------------
    Row {
        width: parent.width
        spacing: 12
        visible: !root.formOpen

        SectionLabel {
            width: parent.width - toggle.width - scanIcon.width - parent.spacing * 2
            text: !Bt.available ? "No adapter found"
                : root.adapter.name + (Bt.adapters.length > 1 ? " · " + root.adapter.adapterId : "")
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            height: toggle.height
        }

        // Scan on/off -- spins while discovering.
        Text {
            id: scanIcon
            visible: Bt.available
            text: "󰑐"
            font.family: Theme.font
            font.pixelSize: Theme.fsValue
            opacity: Bt.powered ? 1 : 0.4
            color: (Bt.discovering || scanArea.containsMouse) ? Colors.accent : Theme.fg
            anchors.verticalCenter: parent.verticalCenter

            NumberAnimation on rotation {
                running: Bt.discovering
                from: 0
                to: 360
                duration: 1400
                loops: Animation.Infinite
                onRunningChanged: if (!running) scanIcon.rotation = 0
            }

            MouseArea {
                id: scanArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                onClicked: root.toggleScan()
            }
        }

        Rectangle {
            id: toggle
            visible: Bt.available
            width: 40
            height: 20
            radius: 10
            color: Bt.powered ? Colors.accent : Theme.track

            Rectangle {
                width: 16
                height: 16
                radius: 8
                color: Theme.surface
                anchors.verticalCenter: parent.verticalCenter
                x: Bt.powered ? parent.width - width - 2 : 2
                Behavior on x { NumberAnimation { duration: Theme.durHover } }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Bt.togglePower()
            }
        }
    }

    // Controller modes (bluetoothctl discoverable / pairable / select).
    Flow {
        width: parent.width
        spacing: 6
        visible: Bt.powered && !root.formOpen

        Chip {
            key: "v"
            label: root.adapter && root.adapter.discoverable ? "Visible" : "Hidden"
            active: !!root.adapter && root.adapter.discoverable
            onClicked: root.adapter.discoverable = !root.adapter.discoverable
        }
        Chip {
            key: "p"
            label: "Pairable"
            active: !!root.adapter && root.adapter.pairable
            onClicked: root.adapter.pairable = !root.adapter.pairable
        }
        Chip {
            key: "N"
            label: "Rename"
            onClicked: root.openForm("adapter")
        }
        Chip {
            visible: Bt.adapters.length > 1
            key: "a"
            label: "Controller " + (Bt.adapters.indexOf(root.adapter) + 1) + "/" + Bt.adapters.length
            onClicked: Bt.nextAdapter()
        }
    }

    // ---- selected device details (i) ---------------------------------------------
    Column {
        id: details
        visible: root.detailsShown && root.currentDev !== null && !root.formOpen
        width: parent.width
        spacing: 2

        readonly property var dev: root.currentDev
        readonly property var rows: {
            const d = details.dev;
            if (!d) return [];
            const yn = b => b ? "yes" : "no";
            const r = [];
            r.push(["Name", d.deviceName !== "" && d.deviceName !== d.name ? d.name + " (" + d.deviceName + ")" : d.name]);
            r.push(["Address", d.address]);
            r.push(["Type", Bt.kindLabel(d) || "--"]);
            r.push(["State", BluetoothDeviceState.toString(d.state)]);
            r.push(["Paired", yn(d.paired) + (d.paired ? ", bonded " + yn(d.bonded) : "")]);
            if (d.batteryAvailable) r.push(["Battery", Math.round(d.battery * 100) + "%"]);
            return r;
        }

        Repeater {
            model: details.rows

            Row {
                width: details.width
                spacing: 8

                required property var modelData

                Text {
                    width: 56
                    text: modelData[0]
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel
                }
                Text {
                    width: parent.width - 64
                    text: modelData[1]
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel
                    elide: Text.ElideRight
                }
            }
        }

        Item { width: 1; height: 4 }

        Flow {
            width: details.width
            spacing: 6

            Chip {
                key: "t"
                label: "Trusted"
                active: !!details.dev && details.dev.trusted
                onClicked: details.dev.trusted = !details.dev.trusted
            }
            Chip {
                key: "b"
                label: "Blocked"
                active: !!details.dev && details.dev.blocked
                onClicked: details.dev.blocked = !details.dev.blocked
            }
            Chip {
                key: "e"
                label: "Wake"
                active: !!details.dev && details.dev.wakeAllowed
                onClicked: details.dev.wakeAllowed = !details.dev.wakeAllowed
            }
            Chip {
                key: "n"
                label: "Rename"
                onClicked: root.openForm("device")
            }
        }
    }

    Field {
        id: filterField
        visible: root.filtering && !root.formOpen
        placeholder: "Filter by name or address…"
        input.onTextChanged: root.filter = filterField.input.text
        onAccepted: root.activate(root.current)
    }

    // Errors with no row to land on (controller rename, a device that
    // vanished from the list).
    Text {
        width: parent.width
        visible: !root.formOpen && Bt.lastError !== ""
                 && !root.entries.some(e => e.dev && e.dev.address === Bt.lastErrorAddress)
        text: Bt.lastError
        color: Colors.urgent
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
        wrapMode: Text.Wrap
    }

    ListView {
        id: list

        width: parent.width
        height: Math.min(contentHeight, root.maxRows * (root.rowH + spacing))
        visible: Bt.powered && !root.formOpen && count > 0
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        model: root.entries

        delegate: DevRow {
            required property var modelData
            required property int index
            readonly property var dev: modelData.dev ?? null
            readonly property string status: dev ? Bt.status(dev) : ""
            readonly property bool confirming: dev !== null && root.confirmKey === dev.address

            width: list.width
            glyph: dev ? Bt.glyph(dev) : (root.showUnnamed ? "󰈈" : "󰈉")
            title: dev ? dev.name : (root.showUnnamed ? "Hide unnamed devices" : modelData.unnamed + " unnamed device" + (modelData.unnamed === 1 ? "" : "s"))
            subtitle: {
                if (!dev) return root.showUnnamed ? "" : "Nearby advertisers with no name -- show them";
                if (confirming) return "Press ↵ or click again to disconnect";
                const parts = [];
                if (status !== "") parts.push(status);
                if (dev.deviceName === "" || root.detailsShown) parts.push(dev.address);
                else if (Bt.kindLabel(dev) !== "") parts.push(Bt.kindLabel(dev));
                return parts.join(" · ");
            }
            subtitleIsError: confirming || (dev !== null && Bt.lastErrorAddress === dev.address && status === Bt.lastError)
                             || (dev !== null && dev.blocked)
            active: dev !== null && dev.connected
            forgettable: dev !== null && (dev.paired || dev.trusted || dev.blocked)
            battery: dev && dev.batteryAvailable ? Math.round(dev.battery * 100) + "%" : ""
            selected: index === root.currentIndex
            onActivated: {
                root.userMoved = true;
                root.currentIndex = index;
                root.activate(modelData);
            }
            // Right-click: select and show details (trust / block / wake / rename).
            onSecondary: {
                root.userMoved = true;
                root.currentIndex = index;
                if (dev) root.detailsShown = true;
            }
            onForgetRequested: root.forget(dev)
        }
    }

    Text {
        visible: root.filtering && root.entries.length === 0 && !root.formOpen
        text: "No devices match “" + root.filter + "”"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
    }

    Text {
        visible: Bt.powered && !root.filtering && root.entries.length === 0 && !root.formOpen
        text: Bt.discovering ? "Scanning…" : "No devices -- press r to scan"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
    }

    Text {
        visible: Bt.available && !Bt.powered && !root.formOpen
        text: root.adapter.state === BluetoothAdapterState.Blocked ? "Bluetooth is blocked (rfkill)" : "Bluetooth is off"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
    }

    // ---- rename form ---------------------------------------------------------------
    Column {
        visible: root.formOpen
        width: parent.width
        spacing: 8

        Text {
            width: parent.width
            text: root.formKind === "adapter" ? "Rename this computer" : "Rename device"
            font.family: Theme.font
            font.pixelSize: Theme.fsValue
            font.bold: true
            color: Theme.fg
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: {
                if (root.formKind === "adapter")
                    return "How other devices see " + (Bt.available ? root.adapter.adapterId : "it");
                const d = root.formOpen ? Bt.findDevice(root.formAddress) : null;
                return (d ? d.address + " · " : "") + "empty resets to the device's own name";
            }
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
            color: Theme.dim
            elide: Text.ElideRight
        }

        Field {
            id: nameField
            placeholder: root.formKind === "adapter" ? "Controller name" : "Device name"
            onAccepted: root.submitForm()
        }

        Text {
            width: parent.width
            visible: root.formError !== ""
            text: root.formError
            color: Colors.urgent
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
            wrapMode: Text.Wrap
        }

        Row {
            anchors.right: parent.right
            spacing: 6

            Rectangle {
                width: 70
                height: 30
                radius: 6
                color: "transparent"
                border.width: 1
                border.color: Theme.rule

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel
                }
                MouseArea { anchors.fill: parent; onClicked: root.closeForm() }
            }

            Rectangle {
                width: 70
                height: 30
                radius: 6
                color: Colors.accent

                Text {
                    anchors.centerIn: parent
                    text: "Save"
                    color: Theme.surface
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel
                }
                MouseArea { anchors.fill: parent; onClicked: root.submitForm() }
            }
        }
    }

    // ---- key hints -----------------------------------------------------------------
    Rectangle {
        width: parent.width
        height: 1
        color: Theme.rule
    }

    Flow {
        width: parent.width
        spacing: 10

        readonly property var hints: {
            if (root.formOpen) return [["↵", "save"], ["esc", "cancel"]];
            if (root.filtering) return [["↑↓", "select"], ["↵", "connect"], ["esc", "clear filter"]];

            const h = [];
            if (Bt.powered) {
                h.push(["j/k", "move"]);
                const c = root.current;
                const d = root.currentDev;
                if (c && !d) h.push(["↵", root.showUnnamed ? "hide unnamed" : "show unnamed"]);
                if (d) {
                    const label = d.pairing ? "cancel pairing"
                        : d.connected ? (root.confirmKey === d.address ? "confirm disconnect" : "disconnect")
                        : d.paired ? "connect" : "pair";
                    h.push(["↵", label]);
                    if (!d.connected && !d.paired) h.push(["c", "connect only"]);
                    if (d.paired || d.trusted || d.blocked) h.push(["d", "forget"]);
                    h.push(["t", d.trusted ? "untrust" : "trust"], ["b", d.blocked ? "unblock" : "block"], ["n", "rename"]);
                    h.push(["i", root.detailsShown ? "hide details" : "details"]);
                }
                h.push(["r", Bt.discovering ? "stop scan" : "scan"], ["/", "filter"], ["u", root.showUnnamed ? "hide unnamed" : "unnamed"]);
            }
            if (Bt.available) h.push(["w", Bt.powered ? "power off" : "power on"]);
            h.push(["esc", "close"]);
            return h;
        }

        Repeater {
            model: parent.hints

            Row {
                required property var modelData
                spacing: 4

                Text {
                    text: modelData[0]
                    color: Colors.accent
                    font.family: Theme.font
                    font.pixelSize: Math.round(Theme.fsLabel * 0.85)
                }
                Text {
                    text: modelData[1]
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Math.round(Theme.fsLabel * 0.85)
                }
            }
        }
    }
}
