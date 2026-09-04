pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Thin summary over Quickshell.Bluetooth for the bar module and the
// Bluetooth panel. Replaces rofi-bluetooth's bluetoothctl scraping --
// everything here is a live D-Bus binding.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool powered: available && adapter.enabled
    readonly property bool discovering: available && adapter.discovering

    readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var connectedDevices: devices.filter(d => d.connected)
    readonly property bool anyConnected: connectedDevices.length > 0
    // Bar label shows one alias, same as waybar's format-connected did.
    readonly property string primaryConnectedName: anyConnected ? connectedDevices[0].name : ""

    function togglePower(): void {
        if (available) adapter.enabled = !adapter.enabled;
    }

    function toggleDiscovery(): void {
        if (available) adapter.discovering = !adapter.discovering;
    }
}
