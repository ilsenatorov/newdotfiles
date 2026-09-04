pragma Singleton

import QtQuick
import Quickshell
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
    readonly property string ip: primaryDevice ? primaryDevice.address : ""

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property int connectivity: Networking.connectivity

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
