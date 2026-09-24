pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Summary of the machine's network state for the bar module and the Network
// panel. Replaces waybar's network#wired/network#wireless modules and
// omarchy-network-status/-band. Wi-Fi is live Quickshell.Networking
// bindings; Ethernet comes from nmcli (see "ethernet" below) because
// Quickshell 0.3's NetworkManager backend only exposes Wi-Fi devices.
Singleton {
    id: root

    // The device currently carrying traffic, best-effort: wired over wifi
    // (matches the old waybar behaviour where #network.wired hides itself
    // once idle and #network.wireless takes over).
    readonly property var wifiDevice: findDevice(true)
    // The Wi-Fi adapter whether or not it's connected -- what the Network
    // panel lists networks from and scans with.
    readonly property var wifiAdapter: wifiDevice ?? findAnyWifiDevice()

    readonly property var wiredDevice: {
        for (const d of root.ethernet) if (d.state === "connected") return d;
        return null;
    }
    readonly property bool wired: wiredDevice !== null
    readonly property bool wifiConnected: wifiDevice !== null
    readonly property bool connected: wired || wifiConnected
    // Interface name the details below (IP, gateway, rates) are sampled for.
    readonly property string primaryIface: wired ? wiredDevice.name : (wifiDevice ? wifiDevice.name : "")

    readonly property var activeWifiNetwork: wifiDevice ? findActiveNetwork(wifiDevice) : null
    readonly property string ssid: activeWifiNetwork ? activeWifiNetwork.name : ""
    readonly property real signalStrength: activeWifiNetwork ? activeWifiNetwork.signalStrength : 0
    // NetworkDevice.address is actually the interface's MAC, not an IP --
    // Quickshell.Networking has no IPv4 property at all, so the real address
    // is polled via `ip addr` below (ip/gateway/rates), gated on detailsActive.
    readonly property string mac: wired ? wiredDevice.mac : (wifiDevice ? wifiDevice.address : "")

    // ---- ethernet ------------------------------------------------------------
    // [{ name, state, connection, speed, mac }] for every NM-managed ethernet
    // interface (unmanaged docker veths and bridges are skipped). state is
    // nmcli's: "connected", "connecting", "disconnected" (cable in, idle),
    // "unavailable" (no cable), ... Refreshed on every `nmcli monitor` event
    // rather than polled.
    property var ethernet: []

    Process {
        id: ethProc
        command: ["sh", "-c",
            "LC_ALL=C nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status | while IFS= read -r line; do "
            + "  dev=${line%%:*}; rest=${line#*:}; type=${rest%%:*}; [ \"$type\" = ethernet ] || continue; "
            + "  printf '%s\\t%s\\t%s\\n' \"$line\" \"$(cat /sys/class/net/$dev/speed 2>/dev/null)\" \"$(cat /sys/class/net/$dev/address 2>/dev/null)\"; "
            + "done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const devs = [];
                for (const line of text.split("\n")) {
                    if (line === "") continue;
                    const [status, speed, mac] = line.split("\t");
                    // DEVICE:TYPE:STATE:CONNECTION -- only the connection
                    // name can contain ':' (escaped as '\:' by terse mode).
                    const i1 = status.indexOf(":");
                    const i2 = status.indexOf(":", i1 + 1);
                    const i3 = status.indexOf(":", i2 + 1);
                    if (i3 < 0) continue;
                    const state = status.slice(i2 + 1, i3).split(" ")[0];
                    if (state === "unmanaged") continue;
                    devs.push({
                        name: status.slice(0, i1),
                        state: state,
                        connection: status.slice(i3 + 1).replace(/\\:/g, ":"),
                        speed: Number(speed) > 0 ? Number(speed) : 0,
                        mac: (mac || "").toUpperCase(),
                    });
                }
                root.ethernet = devs;
            }
        }
    }

    function refreshEthernet(): void {
        if (!ethProc.running) ethProc.running = true;
        else ethRefresh.restart();
    }

    Timer {
        id: ethRefresh
        interval: 300
        onTriggered: root.refreshEthernet()
    }

    // Long-lived: emits a line on every NM device/connection state change.
    Process {
        id: monitorProc
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: ethRefresh.restart()
        }
        onExited: monitorRestart.start()
    }

    Timer {
        id: monitorRestart
        interval: 5000
        onTriggered: monitorProc.running = true
    }

    Component.onCompleted: refreshEthernet()

    Process {
        id: ethActionProc
        onExited: root.refreshEthernet()
    }

    // Plug-and-go ethernet autoconnects on its own; these are for the panel's
    // Ethernet rows (and bring the link back after a manual disconnect).
    function ethernetConnect(name: string): void {
        ethActionProc.command = ["nmcli", "device", "connect", name];
        ethActionProc.running = true;
    }
    function ethernetDisconnect(name: string): void {
        ethActionProc.command = ["nmcli", "device", "disconnect", name];
        ethActionProc.running = true;
    }

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property int connectivity: Networking.connectivity

    // ---- connection details, polled only while the Network panel is open --
    // (detailsActive, set by panels/Network.qml) -- gateway/throughput/totals
    // aren't exposed by Quickshell.Networking, so these come from `ip route`
    // and /proc/net/dev the same way SysMon already samples system-wide
    // network stats, just scoped to whichever interface is primaryIface.
    property bool detailsActive: false
    // Whether the panel shows the details block ('i' toggles); lives here so
    // it survives the panel being closed and reopened.
    property bool detailsShown: true
    property string ip: ""
    property string gateway: ""
    property real rxTotalBytes: 0
    property real txTotalBytes: 0
    property real rxRate: 0
    property real txRate: 0
    property real prevRxTotal: -1
    property real prevTxTotal: -1
    property real prevSampleAt: 0

    onPrimaryIfaceChanged: {
        root.prevRxTotal = -1;
        root.prevTxTotal = -1;
        root.rxRate = 0;
        root.txRate = 0;
        root.rxTotalBytes = 0;
        root.txTotalBytes = 0;
        root.ip = "";
        root.gateway = "";
    }

    FileView {
        id: netDevView
        path: "/proc/net/dev"
        blockLoading: true
        watchChanges: false
    }

    Process {
        id: ipProc
        stdout: StdioCollector {
            onStreamFinished: { root.ip = text.trim(); }
        }
    }

    Process {
        id: gatewayProc
        stdout: StdioCollector {
            onStreamFinished: { root.gateway = text.trim(); }
        }
    }

    function sampleDetails(): void {
        const iface = root.primaryIface;
        if (iface === "") {
            root.ip = "";
            root.gateway = "";
            root.rxTotalBytes = 0;
            root.txTotalBytes = 0;
            root.rxRate = 0;
            root.txRate = 0;
            root.prevRxTotal = -1;
            return;
        }

        ipProc.command = ["sh", "-c", "ip -4 -o addr show dev " + iface + " | awk '{ print $4; exit }' | cut -d/ -f1"];
        ipProc.running = true;

        gatewayProc.command = ["sh", "-c", "ip route show dev " + iface + " | awk '/default/ { print $3; exit }'"];
        gatewayProc.running = true;

        netDevView.reload();
        const line = netDevView.text().split("\n").find(l => l.slice(0, l.indexOf(":")).trim() === iface);
        if (!line) return;

        const f = line.slice(line.indexOf(":") + 1).trim().split(/\s+/).map(Number);
        const rx = f[0];
        const tx = f[8];
        root.rxTotalBytes = rx;
        root.txTotalBytes = tx;

        const now = Date.now() / 1000;
        if (root.prevRxTotal >= 0 && rx >= root.prevRxTotal && tx >= root.prevTxTotal && now > root.prevSampleAt) {
            const dt = now - root.prevSampleAt;
            root.rxRate = Math.max(0, (rx - root.prevRxTotal) / dt);
            root.txRate = Math.max(0, (tx - root.prevTxTotal) / dt);
        } else {
            root.rxRate = 0;
            root.txRate = 0;
        }
        root.prevRxTotal = rx;
        root.prevTxTotal = tx;
        root.prevSampleAt = now;
    }

    Timer {
        running: root.detailsActive
        repeat: true
        triggeredOnStart: true
        interval: 2000
        onTriggered: root.sampleDetails()
    }

    function findDevice(wifi: bool): var {
        const devices = Networking.devices ? Networking.devices.values : [];
        for (const d of devices) {
            const isWifi = d instanceof WifiDevice;
            if (isWifi !== wifi) continue;
            if (d.connected) return d;
        }
        return null;
    }

    function findAnyWifiDevice(): var {
        const devices = Networking.devices ? Networking.devices.values : [];
        for (const d of devices) if (d instanceof WifiDevice) return d;
        return null;
    }

    function findActiveNetwork(device: var): var {
        const nets = device.networks ? device.networks.values : [];
        for (const n of nets) if (n.connected) return n;
        return null;
    }

    // Signal-strength glyph, four bars over Material Design icons -- mirrors
    // the four-bar convention the old bluetooth glyph set already used.
    // WifiNetwork.signalStrength is 0.0-1.0, not a percentage.
    function signalGlyph(strength: real): string {
        if (strength >= 0.80) return "";
        if (strength >= 0.55) return "";
        if (strength >= 0.30) return "";
        if (strength > 0) return "";
        return "";
    }

    function toggleWifi(): void {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    // ---- scanning ----------------------------------------------------------
    // NetworkManager only rescans on its own every couple of minutes; the
    // panel sets scannerEnabled while open and calls rescan() for the refresh
    // button. `scanning` is held for at least scanMinMs so the spinner reads
    // as "something happened" even when NM answers instantly.
    readonly property string connectScript: Qt.resolvedUrl("../scripts/wifi-connect.sh").toString().replace("file://", "")
    readonly property int scanMinMs: 1500
    readonly property bool scanning: rescanProc.running || scanHold.running

    Process {
        id: rescanProc
    }

    Timer {
        id: scanHold
        interval: root.scanMinMs
    }

    function rescan(): void {
        const dev = root.wifiAdapter;
        if (dev === null || !Networking.wifiEnabled || root.scanning) return;
        dev.scannerEnabled = true;
        rescanProc.command = [root.connectScript, "rescan", dev.name];
        rescanProc.running = true;
        scanHold.restart();
    }

    // ---- security ----------------------------------------------------------
    // What a network needs from the user to join: nothing, a password, or
    // an enterprise (802.1X) username + password.
    function securityKind(net: var): string {
        switch (net.security) {
        case WifiSecurityType.Open:
        case WifiSecurityType.Owe:
            return "open";
        case WifiSecurityType.WpaEap:
        case WifiSecurityType.Wpa2Eap:
        case WifiSecurityType.Wpa3SuiteB192:
        case WifiSecurityType.DynamicWep:
        case WifiSecurityType.Leap:
            return "eap";
        default:
            return "psk";
        }
    }

    function securityLabel(net: var): string {
        switch (net.security) {
        case WifiSecurityType.Open: return "Open";
        case WifiSecurityType.Owe: return "Enhanced Open";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep: return "WEP";
        case WifiSecurityType.WpaPsk: return "WPA";
        case WifiSecurityType.Wpa2Psk: return "WPA2";
        case WifiSecurityType.Sae: return "WPA3";
        case WifiSecurityType.WpaEap:
        case WifiSecurityType.Wpa2Eap:
        case WifiSecurityType.Wpa3SuiteB192:
        case WifiSecurityType.Leap: return "Enterprise";
        default: return "Secured";
        }
    }

    // ---- joining -----------------------------------------------------------
    // Anything Quickshell.Networking can't join by itself (unknown open
    // networks, a new/wrong password, WPA-Enterprise, hidden SSIDs) goes
    // through scripts/wifi-connect.sh. The process lives here rather than in
    // the panel so closing the panel mid-connect doesn't kill nmcli.
    property string joiningSsid: ""
    property string lastError: ""
    property string lastErrorSsid: ""

    // A join failed in a way the user can fix by (re)typing credentials --
    // the panel reopens that network's password form. `kind` is
    // "psk" / "eap" / "hidden".
    signal credentialsRejected(string ssid, string kind, string message)

    readonly property bool joining: joinProc.running

    Process {
        id: joinProc

        property string secret: ""
        property string ssid: ""
        property string kind: ""

        stdinEnabled: true
        stderr: StdioCollector {
            id: joinErr
            waitForEnd: true
        }

        onStarted: {
            write(secret + "\n");
            secret = "";
        }

        onExited: exitCode => {
            root.joiningSsid = "";
            if (exitCode === 0) return;
            const msg = joinErr.text.trim().split("\n").pop() || "Connection failed";
            root.lastErrorSsid = ssid;
            root.lastError = msg;
            if (kind !== "open" && (msg === "Wrong password" || msg.indexOf("Enter ") === 0))
                root.credentialsRejected(ssid, kind, msg);
        }
    }

    // kind: "open" | "psk" | "eap" | "hidden"; extra: trailing script args
    // (EAP method + identity); secret: written to the script's stdin.
    function join(kind: string, ssid: string, extra: var, secret: string): bool {
        const dev = root.wifiAdapter;
        if (dev === null || joinProc.running) return false;
        clearError();
        joinProc.command = [root.connectScript, kind, dev.name, ssid].concat(extra);
        joinProc.secret = secret;
        joinProc.ssid = ssid;
        joinProc.kind = kind;
        root.joiningSsid = ssid;
        joinProc.running = true;
        return true;
    }

    function clearError(): void {
        root.lastError = "";
        root.lastErrorSsid = "";
    }

    // Saved networks are connected through Quickshell directly; failures
    // (wrong saved password, AP gone, ...) come back as connectionFailed on
    // the network object, listened to here for every network on the adapter.
    Instantiator {
        model: root.wifiAdapter ? root.wifiAdapter.networks : null

        delegate: Connections {
            required property var modelData
            target: modelData

            function onConnectionFailed(reason: int): void {
                const net = modelData;
                // Script-driven joins report their own errors.
                if (root.joiningSsid === net.name) return;
                root.lastErrorSsid = net.name;
                root.lastError = root.failReasonText(reason);
                const kind = root.securityKind(net);
                const authProblem = reason === ConnectionFailReason.NoSecrets
                    || reason === ConnectionFailReason.WifiClientFailed
                    || reason === ConnectionFailReason.WifiAuthTimeout;
                if (authProblem && kind !== "open")
                    root.credentialsRejected(net.name, kind, root.lastError);
            }
        }
    }

    function failReasonText(reason: int): string {
        switch (reason) {
        case ConnectionFailReason.NoSecrets: return "Wrong password";
        case ConnectionFailReason.WifiClientFailed: return "Authentication failed";
        case ConnectionFailReason.WifiAuthTimeout: return "Authentication timed out";
        case ConnectionFailReason.WifiNetworkLost: return "Network went out of range";
        case ConnectionFailReason.WifiClientDisconnected: return "Disconnected by the network";
        default: return "Connection failed";
        }
    }
}
