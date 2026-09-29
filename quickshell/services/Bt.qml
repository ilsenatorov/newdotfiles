pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Summary over Quickshell.Bluetooth for the bar module and the Bluetooth
// panel. Replaces rofi-bluetooth's bluetoothctl scraping -- everything here
// is a live D-Bus binding. Covers what bluetoothctl does: power, pairable,
// discoverable, scan, pair/cancel-pair, trust, block, connect, remove,
// set-alias, system-alias, select (multiple controllers). PIN/passkey
// prompts during pairing go to the session's default agent (blueman-applet).
Singleton {
    id: root

    // Which controller the panel drives -- Bluez's default unless another was
    // picked (bluetoothctl's `select`). Falls back if that one goes away.
    property string selectedPath: ""
    readonly property var adapters: Bluetooth.adapters ? Bluetooth.adapters.values : []
    readonly property var adapter: {
        for (const a of root.adapters) if (a.dbusPath === root.selectedPath) return a;
        return Bluetooth.defaultAdapter;
    }
    readonly property bool available: adapter !== null
    readonly property bool powered: available && adapter.enabled
    readonly property bool discovering: available && adapter.discovering

    // Every device Bluez knows, across controllers -- the bar summary.
    readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
    // Just the selected controller's -- what the panel lists.
    readonly property var adapterDevices: available && adapter.devices ? adapter.devices.values : []
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

    function nextAdapter(): void {
        if (root.adapters.length < 2) return;
        const i = root.adapters.indexOf(root.adapter);
        root.selectedPath = root.adapters[(i + 1) % root.adapters.length].dbusPath;
    }

    // BluetoothAdapter.name is read-only in Quickshell; Bluez's Alias isn't.
    function renameAdapter(name: string): void {
        if (!available) return;
        aliasProc.command = ["busctl", "--system", "set-property", "org.bluez", adapter.dbusPath,
                             "org.bluez.Adapter1", "Alias", "s", name];
        aliasProc.running = true;
    }

    Process {
        id: aliasProc
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") root.setError("", "Rename failed: " + text.trim())
        }
    }

    // ---- operations with feedback --------------------------------------------
    // Quickshell's connect()/pair() are fire-and-forget: a failure just shows
    // up as the device dropping back to idle. Watch the device after each
    // call and turn "fell back without getting there" into an error on its row.
    property string pendingAddress: ""
    property string pendingOp: ""          // "connect" | "pair"
    property double pendingSince: 0
    property string lastErrorAddress: ""
    property string lastError: ""

    function setError(address: string, message: string): void {
        root.lastErrorAddress = address;
        root.lastError = message;
    }

    function clearError(): void {
        root.lastErrorAddress = "";
        root.lastError = "";
    }

    function track(dev: var, op: string): void {
        if (root.lastErrorAddress === dev.address) clearError();
        root.pendingAddress = dev.address;
        root.pendingOp = op;
        root.pendingSince = Date.now();
        watchTimer.restart();
    }

    function findDevice(address: string): var {
        for (const d of root.devices) if (d.address === address) return d;
        return null;
    }

    function connectDevice(dev: var): void {
        if (dev.blocked) dev.blocked = false;
        track(dev, "connect");
        dev.connect();
    }

    // Pair, then trust and connect once bonded -- what you'd type in
    // bluetoothctl anyway (pair / trust / connect).
    function pairDevice(dev: var): void {
        if (dev.blocked) dev.blocked = false;
        track(dev, "pair");
        dev.pair();
    }

    function cancelPair(dev: var): void {
        if (root.pendingAddress === dev.address) root.pendingAddress = "";
        dev.cancelPair();
    }

    function forgetDevice(dev: var): void {
        if (root.pendingAddress === dev.address) root.pendingAddress = "";
        if (root.lastErrorAddress === dev.address) clearError();
        dev.forget();
    }

    Timer {
        id: watchTimer
        interval: 400
        repeat: true
        running: false
        onTriggered: {
            const dev = root.findDevice(root.pendingAddress);
            if (!dev) { root.pendingAddress = ""; stop(); return; }
            const elapsed = Date.now() - root.pendingSince;
            // Give Bluez a moment to flip into Connecting/pairing first.
            const settled = elapsed > 1500;

            if (root.pendingOp === "pair") {
                if (dev.paired) {
                    dev.trusted = true;
                    root.pendingOp = "connect";
                    root.pendingSince = Date.now();
                    if (!dev.connected) dev.connect();
                    return;
                }
                if ((settled && !dev.pairing) || elapsed > 60000) {
                    root.setError(dev.address, "Pairing failed");
                    root.pendingAddress = "";
                    stop();
                }
                return;
            }

            if (dev.connected) { root.pendingAddress = ""; stop(); return; }
            if ((settled && dev.state === BluetoothDeviceState.Disconnected) || elapsed > 30000) {
                root.setError(dev.address, "Couldn't connect");
                root.pendingAddress = "";
                stop();
            }
        }
    }

    function busy(dev: var): bool {
        return root.pendingAddress === dev.address;
    }

    // ---- presentation ---------------------------------------------------------
    // Bluez's Icon property (freedesktop icon names) to an MD glyph.
    function glyph(dev: var): string {
        const icon = dev.icon || "";
        if (icon.startsWith("audio-headset") || icon.startsWith("audio-headphones")) return "󰋋";
        if (icon.startsWith("audio")) return "󰓃";
        if (icon === "input-keyboard") return "󰌌";
        if (icon === "input-mouse") return "󰍽";
        if (icon === "input-gaming") return "󰊴";
        if (icon === "input-tablet") return "󰓶";
        if (icon.startsWith("phone")) return "󰏲";
        if (icon === "computer") return "󰟀";
        if (icon.startsWith("video")) return "󰍹";
        if (icon === "printer") return "󰐪";
        if (icon.startsWith("camera")) return "󰄀";
        return dev.connected ? "󰂱" : "󰂯";
    }

    function kindLabel(dev: var): string {
        const icon = dev.icon || "";
        if (icon.startsWith("audio-headset")) return "Headset";
        if (icon.startsWith("audio-headphones")) return "Headphones";
        if (icon.startsWith("audio")) return "Audio";
        if (icon === "input-keyboard") return "Keyboard";
        if (icon === "input-mouse") return "Mouse";
        if (icon === "input-gaming") return "Controller";
        if (icon === "input-tablet") return "Tablet";
        if (icon.startsWith("phone")) return "Phone";
        if (icon === "computer") return "Computer";
        if (icon.startsWith("video")) return "Display";
        if (icon === "printer") return "Printer";
        if (icon.startsWith("camera")) return "Camera";
        return icon;
    }

    function status(dev: var): string {
        if (dev.pairing || (busy(dev) && root.pendingOp === "pair")) return "Pairing…";
        if (dev.state === BluetoothDeviceState.Connecting || (busy(dev) && !dev.connected)) return "Connecting…";
        if (dev.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…";
        if (root.lastErrorAddress === dev.address && root.lastError !== "") return root.lastError;
        if (dev.blocked) return "Blocked";
        if (dev.connected) return "Connected";
        if (dev.paired) return dev.trusted ? "Paired" : "Paired · untrusted";
        if (dev.trusted) return "Trusted";
        return "";
    }
}
