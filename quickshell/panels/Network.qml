import QtQuick
import Quickshell.Networking
import ".."
import "../services"

// Replaces the SUPER+N networkmanager_dmenu rofi menu. Ethernet and Wi-Fi in
// one list: Ethernet state via Net's nmcli monitor, Wi-Fi live via
// Quickshell.Networking; joins that need more than a saved profile (open,
// new/wrong password, WPA-Enterprise, hidden SSIDs) go through Net.join() ->
// scripts/wifi-connect.sh.
//
// Keyboard-first -- the hint row at the bottom always shows what's live:
//   j/k ↑/↓ move   g/G Home/End   PgUp/PgDn   ↵/Space connect or disconnect
//   r/F5 rescan    / filter       d/Del forget    h hidden network
//   w ←/→ Wi-Fi radio    s share    i details    Esc back/close
// shell.qml grabs keyboard focus onto this root the moment the panel opens.
Column {
    id: root
    width: parent ? parent.width : Theme.panelW
    spacing: 8
    focus: true

    signal shareRequested

    readonly property var wifiDevice: Net.wifiAdapter
    readonly property bool wifiOn: !!wifiDevice && Networking.wifiEnabled
    readonly property int rowH: Math.round(42 * Theme.s)
    readonly property int maxRows: 7

    // Every selectable row, in display order: { wired } per ethernet device,
    // then { net } per visible Wi-Fi network, then a { hidden: true }
    // "Other network..." row. Rebuilt imperatively (resort()) rather than
    // bound, so signal-strength jitter doesn't reshuffle and reset the list
    // under the cursor every few seconds.
    property var entries: []
    property int currentIndex: -1
    readonly property var ethEntries: entries.filter(e => !!e.wired)
    readonly property var wifiEntries: entries.filter(e => !e.wired)
    readonly property int ethCount: ethEntries.length
    readonly property var current: currentIndex >= 0 && currentIndex < entries.length ? entries[currentIndex] : null

    // Disconnecting the active connection takes a second ↵/click within a
    // few seconds -- with only Ethernet around, the one selectable row *is*
    // the live link, and a stray Enter shouldn't drop it.
    property string confirmKey: ""

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root.confirmKey = ""
    }

    // Type-to-filter, opened with '/'.
    property bool filtering: false
    property string filter: ""

    // Inline join form. formKind: "" (closed) / "psk" / "eap" / "hidden".
    property string formKind: ""
    property string formSsid: ""
    property string formError: ""
    property string eapMethod: "peap"
    readonly property bool formOpen: formKind !== ""

    // `focus: true` alone only *requests* activeFocus once this branch's
    // enclosing FocusScope (shell.qml's panelFocus) is itself active -- with
    // a Loader (not a FocusScope) in between, that request can lose the race
    // against the scope activating, especially right after the panel's
    // WlrLayershell surface is mapped. Forcing it once this item actually
    // exists makes the key handling below reliable every time. Also only
    // poll gateway/throughput and keep NM scanning while the panel is open.
    Component.onCompleted: {
        root.forceActiveFocus();
        Net.detailsActive = true;
        if (root.wifiDevice) root.wifiDevice.scannerEnabled = true;
        Net.refreshEthernet();
        Net.rescan();
        resort();
    }
    Component.onDestruction: {
        Net.detailsActive = false;
        if (root.wifiDevice) root.wifiDevice.scannerEnabled = false;
    }

    // Deferred, not a direct resort(): these bindings first evaluate lazily
    // in the middle of other bindings (e.g. the key hints), and rewriting
    // `entries` from inside that evaluation is a binding loop.
    onWifiDeviceChanged: resortTimer.restart()
    onWifiOnChanged: resortTimer.restart()
    onFilterChanged: {
        root.currentIndex = -1;
        resort();
    }

    Connections {
        target: root.wifiDevice ? root.wifiDevice.networks : null
        function onValuesChanged(): void { resortTimer.restart(); }
    }
    Connections {
        target: Net
        function onSsidChanged(): void { resortTimer.restart(); }
        function onEthernetChanged(): void { resortTimer.restart(); }
        function onScanningChanged(): void { if (!Net.scanning) resortTimer.restart(); }
        function onCredentialsRejected(ssid: string, kind: string, message: string): void {
            root.openForm(ssid, kind, message);
        }
    }
    Connections {
        target: Networking
        function onWifiEnabledChanged(): void {
            if (Networking.wifiEnabled) radioOnRescan.restart();
        }
    }

    Timer {
        id: resortTimer
        interval: 150
        onTriggered: root.resort()
    }

    // The adapter takes a moment to come up after the radio is switched on;
    // a rescan fired immediately is refused.
    Timer {
        id: radioOnRescan
        interval: 1500
        onTriggered: Net.rescan()
    }

    function entryKey(e: var): string {
        if (!e) return "";
        if (e.wired) return "eth:" + e.wired.name;
        if (e.hidden) return "hidden";
        return "wifi:" + e.net.name;
    }

    function matches(name: string): bool {
        return root.filter === "" || name.toLowerCase().indexOf(root.filter.toLowerCase()) >= 0;
    }

    function resort(): void {
        const selectedKey = entryKey(root.current);
        const next = [];

        for (const d of Net.ethernet) {
            if (d.state === "unavailable") continue;   // no cable -- nothing to do with it
            if (matches("ethernet " + d.name + " " + d.connection)) next.push({ wired: d });
        }

        if (root.wifiOn) {
            const nets = [];
            for (const n of root.wifiDevice.networks.values)
                if (n.name !== "" && matches(n.name)) nets.push(n);
            const bucket = n => Math.min(3, Math.floor(n.signalStrength * 4));
            nets.sort((a, b) => (b.connected - a.connected)
                || (b.known - a.known)
                || (bucket(b) - bucket(a))
                || a.name.localeCompare(b.name));
            for (const n of nets) next.push({ net: n });
            if (root.filter === "") next.push({ hidden: true });
        }

        root.entries = next;

        // Keep the same row selected across the reshuffle; on first build
        // (or after a filter change) start on the first row that isn't
        // already connected, so a stray Enter doesn't drop the connection.
        let i = selectedKey === "" ? -1 : next.findIndex(e => entryKey(e) === selectedKey);
        if (i < 0) {
            i = next.findIndex(e => !isOn(e));
            if (i < 0) i = next.length > 0 ? 0 : -1;
        }
        root.currentIndex = i;
    }

    function findNetwork(ssid: string): var {
        const dev = root.wifiDevice;
        if (!dev || !dev.networks) return null;
        for (const n of dev.networks.values) if (n.name === ssid) return n;
        return null;
    }

    function isOn(e: var): bool {
        if (!e) return false;
        if (e.wired) return e.wired.state === "connected" || e.wired.state === "connecting";
        return e.net ? e.net.connected : false;
    }

    function activate(entry: var): void {
        if (!entry) return;
        if (isOn(entry) && root.confirmKey !== entryKey(entry)) {
            root.confirmKey = entryKey(entry);
            confirmTimer.restart();
            return;
        }
        root.confirmKey = "";
        if (entry.wired) {
            const d = entry.wired;
            if (isOn(entry)) Net.ethernetDisconnect(d.name);
            else Net.ethernetConnect(d.name);
            return;
        }
        if (entry.hidden) {
            openForm("", "hidden", "");
            return;
        }
        const net = entry.net;
        Net.clearError();
        if (net.connected) {
            net.disconnect();
        } else if (net.known) {
            net.connect();
        } else {
            const kind = Net.securityKind(net);
            if (kind === "open") Net.join("open", net.name, [], "");
            else openForm(net.name, kind, "");
        }
    }

    function forget(entry: var): void {
        if (!entry || !entry.net || !entry.net.known) return;
        if (Net.lastErrorSsid === entry.net.name) Net.clearError();
        entry.net.forget();
        resortTimer.restart();
    }

    function refresh(): void {
        Net.refreshEthernet();
        Net.rescan();
    }

    function move(delta: int): void {
        const count = root.entries.length;
        if (count === 0) return;
        if (root.currentIndex < 0) { root.currentIndex = 0; return; }
        root.currentIndex = Math.max(0, Math.min(count - 1, root.currentIndex + delta));
    }

    function wrapMove(delta: int): void {
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

    function openForm(ssid: string, kind: string, error: string): void {
        root.formSsid = ssid;
        root.formKind = kind;
        root.formError = error;
        secretField.revealed = false;
        ssidField.input.text = ssid;
        identityField.input.text = "";
        secretField.input.text = "";
        Qt.callLater(() => {
            if (kind === "hidden") ssidField.input.forceActiveFocus();
            else if (kind === "eap") identityField.input.forceActiveFocus();
            else secretField.input.forceActiveFocus();
        });
    }

    function closeForm(): void {
        root.formKind = "";
        root.formError = "";
        secretField.input.text = "";
        if (root.filtering) filterField.input.forceActiveFocus();
        else root.forceActiveFocus();
    }

    function submitForm(): void {
        const kind = root.formKind;
        const ssid = kind === "hidden" ? ssidField.input.text.trim() : root.formSsid;
        if (ssid === "") { root.formError = "Enter the network name"; return; }
        if (kind === "eap" && identityField.input.text.trim() === "") { root.formError = "Enter a username"; return; }
        if (kind !== "hidden" && secretField.input.text === "") { root.formError = "Enter a password"; return; }

        const extra = kind === "eap" ? [root.eapMethod, identityField.input.text.trim()] : [];
        if (!Net.join(kind, ssid, extra, secretField.input.text)) {
            root.formError = "Another connection is still in progress";
            return;
        }
        closeForm();
    }

    function wifiStatus(net: var): string {
        if (Net.joiningSsid === net.name || net.state === ConnectionState.Connecting) return "Connecting…";
        if (net.state === ConnectionState.Disconnecting) return "Disconnecting…";
        if (Net.lastErrorSsid === net.name && Net.lastError !== "") return Net.lastError;
        if (net.connected) return "Connected";
        if (net.known) return "Saved";
        return "";
    }

    function wiredStatus(d: var): string {
        switch (d.state) {
        case "connected": return "Connected";
        case "connecting": return "Connecting…";
        case "deactivating": return "Disconnecting…";
        case "disconnected": return "Disconnected";
        default: return d.state.charAt(0).toUpperCase() + d.state.slice(1);
        }
    }

    onCurrentIndexChanged: {
        root.confirmKey = "";
        if (currentIndex >= ethCount) list.positionViewAtIndex(currentIndex - ethCount, ListView.Contain);
    }

    // ---- keys ----------------------------------------------------------------
    // One handler for everything: keys a focused TextInput (filter / form
    // field) doesn't consume -- arrows, Enter from the filter, Esc, Alt+x --
    // propagate up to here.
    Keys.onPressed: event => {
        const k = event.key;
        const mods = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
        const alt = event.modifiers & Qt.AltModifier;
        const ctrl = event.modifiers & Qt.ControlModifier;
        const done = () => { event.accepted = true; };

        if (root.formOpen) {
            if (k === Qt.Key_Escape) { root.closeForm(); done(); }
            else if (alt && k === Qt.Key_V) { secretField.revealed = !secretField.revealed; done(); }
            else if (alt && k === Qt.Key_M && root.formKind === "eap") {
                root.eapMethod = root.eapMethod === "peap" ? "ttls" : "peap";
                done();
            }
            return;
        }

        // Navigation works both from the list and from inside the filter.
        if (k === Qt.Key_Down || (ctrl && (k === Qt.Key_N || k === Qt.Key_J))) { root.wrapMove(1); done(); return; }
        if (k === Qt.Key_Up || (ctrl && (k === Qt.Key_P || k === Qt.Key_K))) { root.wrapMove(-1); done(); return; }
        if (k === Qt.Key_PageDown) { root.move(5); done(); return; }
        if (k === Qt.Key_PageUp) { root.move(-5); done(); return; }
        if (k === Qt.Key_Return || k === Qt.Key_Enter) { root.activate(root.current); done(); return; }
        if (k === Qt.Key_F5) { root.refresh(); done(); return; }
        if (k === Qt.Key_Escape) {
            // Esc backs out of the filter first; otherwise it falls through
            // to shell.qml, which closes the panel.
            if (root.filtering) { root.closeFilter(); done(); }
            return;
        }

        if (root.filtering) return;   // letters belong to the filter field
        if (mods) return;

        switch (k) {
        case Qt.Key_J: root.wrapMove(1); break;
        case Qt.Key_K: root.wrapMove(-1); break;
        case Qt.Key_Home: root.move(-root.entries.length); break;
        case Qt.Key_End: root.move(root.entries.length); break;
        case Qt.Key_G:
            root.move(event.modifiers & Qt.ShiftModifier ? root.entries.length : -root.entries.length);
            break;
        case Qt.Key_Space: root.activate(root.current); break;
        case Qt.Key_R: root.refresh(); break;
        case Qt.Key_Slash: root.openFilter(); break;
        case Qt.Key_D:
        case Qt.Key_Delete: root.forget(root.current); break;
        case Qt.Key_H: if (root.wifiOn) root.openForm("", "hidden", ""); break;
        case Qt.Key_W: Networking.wifiEnabled = !Networking.wifiEnabled; break;
        case Qt.Key_Left: Networking.wifiEnabled = false; break;
        case Qt.Key_Right: Networking.wifiEnabled = true; break;
        case Qt.Key_S: if (Net.wifiConnected) root.shareRequested(); break;
        case Qt.Key_I: Net.detailsShown = !Net.detailsShown; break;
        default: return;
        }
        done();
    }

    // ---- reusable bits ---------------------------------------------------------
    component NetRow: Rectangle {
        id: netRow

        property string glyph: ""
        property string title: ""
        property string subtitle: ""
        property bool subtitleIsError: false
        property bool active: false      // connected -- accent colouring + check
        property bool selected: false
        property bool locked: false
        property bool forgettable: false

        signal activated
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
            onClicked: netRow.activated()
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Text {
                id: glyphText
                width: Math.round(Theme.fsValue * 1.4)
                text: netRow.glyph
                font.family: Theme.font
                font.pixelSize: Theme.fsValue
                color: netRow.active ? Colors.accent : Theme.fg
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - glyphText.width - trailing.width - parent.spacing * 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: netRow.title
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                    color: netRow.active ? Colors.accent : Theme.fg
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: netRow.subtitle
                    font.family: Theme.font
                    font.pixelSize: Math.round(Theme.fsLabel * 0.85)
                    color: netRow.subtitleIsError ? Colors.urgent : Theme.dim
                    elide: Text.ElideRight
                }
            }

            Row {
                id: trailing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    visible: netRow.locked
                    text: "󰌾"
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel
                    color: Theme.dim
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Forget: drops every saved profile for this SSID.
                Text {
                    visible: netRow.forgettable
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
                        onClicked: netRow.forgetRequested()
                    }
                }

                Text {
                    visible: netRow.active
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
        property bool secret: false
        property bool revealed: false
        // Tab / Shift+Tab targets -- the neighbouring fields in the form.
        property Item next: null
        property Item prev: null
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
            anchors.rightMargin: field.secret ? eye.width + 16 : 8
            verticalAlignment: TextInput.AlignVCenter
            echoMode: field.secret && !field.revealed ? TextInput.Password : TextInput.Normal
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fsValue
            clip: true
            KeyNavigation.tab: field.next
            KeyNavigation.backtab: field.prev
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

        Text {
            id: eye
            visible: field.secret
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: field.revealed ? "󰈉" : "󰈈"
            font.family: Theme.font
            font.pixelSize: Theme.fsValue
            color: eyeArea.containsMouse ? Colors.accent : Theme.dim

            MouseArea {
                id: eyeArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                onClicked: field.revealed = !field.revealed
            }
        }
    }

    component Chip: Rectangle {
        id: chip

        property string label: ""
        property bool active: false
        signal clicked

        width: chipText.implicitWidth + 20
        height: Math.round(26 * Theme.s)
        radius: height / 2
        color: active ? Colors.accent : "transparent"
        border.width: 1
        border.color: active ? Colors.accent : Theme.rule

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.active ? Theme.surface : Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
        }
        MouseArea { anchors.fill: parent; onClicked: chip.clicked() }
    }

    component SectionLabel: Text {
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
        font.bold: true
        color: Theme.dim
    }

    // ---- connection details ----------------------------------------------------
    // Whatever is carrying traffic (Ethernet preferred). One label/value row,
    // not a 2-column grid -- the MAC alone is wider than half the panel.
    // Toggled with 'i'.
    Column {
        visible: Net.connected && Net.detailsShown && !root.formOpen
        width: parent.width
        spacing: 2

        readonly property var rows: {
            const r = [];
            if (Net.wired) {
                const d = Net.wiredDevice;
                r.push(["Via", "Ethernet · " + d.name]);
                if (d.speed > 0) r.push(["Speed", d.speed >= 1000 ? (d.speed / 1000) + " Gb/s" : d.speed + " Mb/s"]);
            } else {
                r.push(["Via", "Wi-Fi · " + Net.ssid]);
                r.push(["Signal", Math.round(Net.signalStrength * 100) + "%"]);
            }
            r.push(["IP", Net.ip !== "" ? Net.ip : "--"]);
            r.push(["Gateway", Net.gateway !== "" ? Net.gateway : "--"]);
            r.push(["MAC", Net.mac !== "" ? Net.mac : "--"]);
            r.push(["Rate", SysMon.fmtBytes(Net.rxRate) + "/s down, " + SysMon.fmtBytes(Net.txRate) + "/s up"]);
            r.push(["Total", SysMon.fmtBytes(Net.rxTotalBytes) + " down, " + SysMon.fmtBytes(Net.txTotalBytes) + " up"]);
            return r;
        }

        Repeater {
            model: parent.rows

            Row {
                width: parent.width
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
    }

    // ---- ethernet ----------------------------------------------------------------
    Column {
        visible: root.ethCount > 0 && !root.formOpen
        width: parent.width
        spacing: 2

        SectionLabel { text: "Ethernet" }

        Repeater {
            model: root.ethEntries

            NetRow {
                required property var modelData
                required property int index
                readonly property var dev: modelData.wired

                width: parent.width
                glyph: "󰈀"
                title: dev.connection !== "" ? dev.connection : "Ethernet"
                readonly property bool confirming: root.confirmKey === root.entryKey(modelData)
                subtitleIsError: confirming
                subtitle: {
                    if (confirming) return "Press ↵ or click again to disconnect";
                    const parts = [root.wiredStatus(dev), dev.name];
                    if (dev.state === "connected" && dev.speed > 0)
                        parts.push(dev.speed >= 1000 ? (dev.speed / 1000) + " Gb/s" : dev.speed + " Mb/s");
                    return parts.join(" · ");
                }
                active: dev.state === "connected"
                selected: index === root.currentIndex
                onActivated: {
                    root.currentIndex = index;
                    root.activate(modelData);
                }
            }
        }
    }

    // ---- wi-fi header: label, rescan, share, radio toggle ------------------------
    Row {
        width: parent.width
        spacing: 12
        visible: !root.formOpen

        SectionLabel {
            width: parent.width - toggle.width - refreshIcon.width - parent.spacing
                   - (shareIcon.visible ? shareIcon.width + parent.spacing : 0) - parent.spacing
            text: "Wi-Fi"
            verticalAlignment: Text.AlignVCenter
            height: toggle.height
        }

        Text {
            id: refreshIcon
            text: "󰑐"
            font.family: Theme.font
            font.pixelSize: Theme.fsValue
            color: (Net.scanning || refreshArea.containsMouse) ? Colors.accent : Theme.fg
            anchors.verticalCenter: parent.verticalCenter

            NumberAnimation on rotation {
                running: Net.scanning
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                onRunningChanged: if (!running) refreshIcon.rotation = 0
            }

            MouseArea {
                id: refreshArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                onClicked: root.refresh()
            }
        }

        Text {
            id: shareIcon
            visible: Net.wifiConnected
            text: "󰐲"
            font.family: Theme.font
            font.pixelSize: Theme.fsValue
            color: Colors.accent
            anchors.verticalCenter: parent.verticalCenter

            MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.shareRequested() }
        }

        Rectangle {
            id: toggle
            width: 40
            height: 20
            radius: 10
            opacity: root.wifiDevice ? 1 : 0.4
            color: Networking.wifiEnabled ? Colors.accent : Theme.track

            Rectangle {
                width: 16
                height: 16
                radius: 8
                color: Theme.surface
                anchors.verticalCenter: parent.verticalCenter
                x: Networking.wifiEnabled ? parent.width - width - 2 : 2
                Behavior on x { NumberAnimation { duration: Theme.durHover } }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }
    }

    Field {
        id: filterField
        visible: root.filtering && !root.formOpen
        placeholder: "Filter networks…"
        input.onTextChanged: root.filter = filterField.input.text
        // TextInput swallows Enter (as `accepted`), so it never reaches
        // root's key handler -- connect to the highlighted row from here.
        // Arrows and Esc aren't consumed and do propagate up.
        onAccepted: root.activate(root.current)
    }

    // An error for a network that isn't in the list (e.g. a hidden SSID
    // that wasn't found) has no row to show up on.
    Text {
        width: parent.width
        visible: !root.formOpen && Net.lastError !== ""
                 && !root.entries.some(e => e.net && e.net.name === Net.lastErrorSsid)
        text: (Net.lastErrorSsid !== "" ? Net.lastErrorSsid + ": " : "") + Net.lastError
        color: Colors.urgent
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
        wrapMode: Text.Wrap
    }

    ListView {
        id: list

        width: parent.width
        height: Math.min(contentHeight, root.maxRows * (root.rowH + spacing))
        visible: root.wifiOn && !root.formOpen && count > 0
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        model: root.wifiEntries

        delegate: NetRow {
            required property var modelData
            required property int index
            readonly property var net: modelData.net ?? null
            readonly property string status: net ? root.wifiStatus(net) : ""

            width: list.width
            glyph: net ? Net.signalGlyph(net.signalStrength) : "󰐕"
            title: net ? net.name : "Other network…"
            readonly property bool confirming: root.confirmKey === root.entryKey(modelData)
            subtitle: {
                if (!net) return "Join a hidden network";
                if (confirming) return "Press ↵ or click again to disconnect";
                const parts = [];
                if (status !== "") parts.push(status);
                parts.push(Net.securityLabel(net));
                return parts.join(" · ");
            }
            subtitleIsError: confirming || net !== null && Net.lastErrorSsid === net.name && Net.lastError !== "" && status === Net.lastError
            active: net !== null && net.connected
            locked: net !== null && Net.securityKind(net) !== "open"
            forgettable: net !== null && net.known
            selected: index + root.ethCount === root.currentIndex
            onActivated: {
                root.currentIndex = index + root.ethCount;
                root.activate(modelData);
            }
            onForgetRequested: root.forget(modelData)
        }
    }

    Text {
        visible: root.filtering && root.entries.length === 0 && !root.formOpen
        text: "No networks match “" + root.filter + "”"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
    }

    Text {
        visible: !root.wifiDevice && !root.formOpen
        text: "No Wi-Fi adapter found"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
    }

    Text {
        visible: !!root.wifiDevice && !Networking.wifiEnabled && !root.formOpen
        text: "Wi-Fi is off"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
    }

    // ---- join form ---------------------------------------------------------------
    // Replaces the list while open (rather than expanding inline under a
    // row) so a rescan re-sorting the list can't tear down what's being typed.
    Column {
        visible: root.formOpen
        width: parent.width
        spacing: 8

        Text {
            width: parent.width
            text: root.formKind === "hidden" ? "Join a hidden network" : root.formSsid
            font.family: Theme.font
            font.pixelSize: Theme.fsValue
            font.bold: true
            color: Theme.fg
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.formKind !== "hidden"
            text: {
                const net = root.formOpen ? root.findNetwork(root.formSsid) : null;
                const sec = net ? Net.securityLabel(net) + " · " : "";
                return sec + (root.formKind === "eap"
                    ? "sign in with your username and password"
                    : "enter the network password");
            }
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
            color: Theme.dim
            elide: Text.ElideRight
        }

        Field {
            id: ssidField
            visible: root.formKind === "hidden"
            placeholder: "Network name (SSID)"
            next: secretField.input
            prev: secretField.input
            onAccepted: root.submitForm()
        }

        Row {
            visible: root.formKind === "eap"
            spacing: 6

            Chip { label: "PEAP"; active: root.eapMethod === "peap"; onClicked: root.eapMethod = "peap" }
            Chip { label: "TTLS"; active: root.eapMethod === "ttls"; onClicked: root.eapMethod = "ttls" }
        }

        Field {
            id: identityField
            visible: root.formKind === "eap"
            placeholder: "Username"
            next: secretField.input
            prev: secretField.input
            onAccepted: root.submitForm()
        }

        Field {
            id: secretField
            secret: true
            placeholder: root.formKind === "hidden" ? "Password (leave empty if open)" : "Password"
            next: root.formKind === "hidden" ? ssidField.input
                : root.formKind === "eap" ? identityField.input : null
            prev: next
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
                    text: "Join"
                    color: Theme.surface
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel
                }
                MouseArea { anchors.fill: parent; onClicked: root.submitForm() }
            }
        }
    }

    // ---- key hints -----------------------------------------------------------------
    // Context-sensitive: only what the current state/selection responds to.
    Rectangle {
        width: parent.width
        height: 1
        color: Theme.rule
    }

    Flow {
        width: parent.width
        spacing: 10

        readonly property var hints: {
            if (root.formOpen) {
                const h = [["↵", "join"], ["tab", "next field"], ["alt+v", "show password"]];
                if (root.formKind === "eap") h.push(["alt+m", "PEAP/TTLS"]);
                h.push(["esc", "cancel"]);
                return h;
            }
            if (root.filtering) return [["↑↓", "select"], ["↵", "connect"], ["esc", "clear filter"]];

            const c = root.current;
            const h = [["j/k", "move"]];
            if (c) {
                const label = c.hidden ? "join hidden"
                    : !root.isOn(c) ? "connect"
                    : root.confirmKey === root.entryKey(c) ? "confirm disconnect" : "disconnect";
                h.push(["↵", label]);
                if (c.net && c.net.known) h.push(["d", "forget"]);
            }
            h.push(["r", "rescan"]);
            if (root.wifiOn) h.push(["/", "filter"], ["h", "hidden"]);
            if (root.wifiDevice) h.push(["w", Networking.wifiEnabled ? "wifi off" : "wifi on"]);
            if (Net.wifiConnected) h.push(["s", "share"]);
            if (Net.connected) h.push(["i", Net.detailsShown ? "hide details" : "details"]);
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
