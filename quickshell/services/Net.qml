pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Thin summary over Quickshell.Networking for the bar module and the Network
// panel. Replaces waybar's network#wired/network#wireless modules and
// omarchy-network-status/-band -- everything here is a live binding, no
// subprocess.
Singleton {
    id: root

    // The device currently carrying the default route, best-effort: the
    // first connected device, preferring wired over wifi (matches the old
    // waybar behaviour where #network.wired hides itself once idle and
    // #network.wireless takes over).
    readonly property var wiredDevice: findDevice(false)
    readonly property var wifiDevice: findDevice(true)
    readonly property var primaryDevice: wiredDevice ?? wifiDevice

    readonly property bool wired: wiredDevice !== null
    readonly property bool wifiConnected: wifiDevice !== null
    readonly property bool connected: primaryDevice !== null

    readonly property var activeWifiNetwork: wifiDevice ? findActiveNetwork(wifiDevice) : null
    readonly property string ssid: activeWifiNetwork ? activeWifiNetwork.name : ""
    readonly property real signalStrength: activeWifiNetwork ? activeWifiNetwork.signalStrength : 0
    // NetworkDevice.address is actually the interface's MAC, not an IP --
    // Quickshell.Networking has no IPv4 property at all, so the real address
    // is polled via `ip addr` below (ip/gateway/rates), gated on detailsActive.
    readonly property string mac: primaryDevice ? primaryDevice.address : ""

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property int connectivity: Networking.connectivity

    // ---- connection details, polled only while the Network panel is open --
    // (detailsActive, set by panels/Network.qml) -- gateway/throughput/totals
    // aren't exposed by Quickshell.Networking, so these come from `ip route`
    // and /proc/net/dev the same way SysMon already samples system-wide
    // network stats, just scoped to whichever device is primaryDevice.
    property bool detailsActive: false
    property string ip: ""
    property string gateway: ""
    property real rxTotalBytes: 0
    property real txTotalBytes: 0
    property real rxRate: 0
    property real txRate: 0
    property real prevRxTotal: -1
    property real prevTxTotal: -1
    property real prevSampleAt: 0

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
        const dev = root.primaryDevice;
        if (dev === null) {
            root.ip = "";
            root.gateway = "";
            root.rxTotalBytes = 0;
            root.txTotalBytes = 0;
            root.rxRate = 0;
            root.txRate = 0;
            root.prevRxTotal = -1;
            return;
        }

        ipProc.command = ["sh", "-c", "ip -4 -o addr show dev " + dev.name + " | awk '{ print $4; exit }' | cut -d/ -f1"];
        ipProc.running = true;

        gatewayProc.command = ["sh", "-c", "ip route show dev " + dev.name + " | awk '/default/ { print $3; exit }'"];
        gatewayProc.running = true;

        netDevView.reload();
        const m = new RegExp("^\\s*" + dev.name + ":\\s*(.*)$", "m").exec(netDevView.text());
        if (!m) return;

        const f = m[1].trim().split(/\s+/).map(Number);
        const rx = f[0];
        const tx = f[8];
        root.rxTotalBytes = rx;
        root.txTotalBytes = tx;

        const now = Date.now() / 1000;
        if (root.prevRxTotal >= 0 && now > root.prevSampleAt) {
            const dt = now - root.prevSampleAt;
            root.rxRate = Math.max(0, (rx - root.prevRxTotal) / dt);
            root.txRate = Math.max(0, (tx - root.prevTxTotal) / dt);
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

    function findActiveNetwork(device: var): var {
        const nets = device.networks ? device.networks.values : [];
        for (const n of nets) if (n.connected) return n;
        return null;
    }

    // Signal-strength glyph, four bars over Material Design icons -- mirrors
    // the four-bar convention the old bluetooth glyph set already used.
    function signalGlyph(strength: real): string {
        if (strength >= 80) return "";
        if (strength >= 55) return "";
        if (strength >= 30) return "";
        if (strength > 0) return "";
        return "";
    }

    function toggleWifi(): void {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }
}
