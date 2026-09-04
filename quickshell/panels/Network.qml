import QtQuick
import Quickshell.Networking
import ".."
import "../services"

// Replaces the SUPER+N networkmanager_dmenu rofi menu. Live NetworkManager
// state via Quickshell.Networking -- no omarchy-network-status polling.
// Fully keyboard-drivable: Up/Down move the selection, Enter/Return acts on
// it (same as a click), Left/Right toggle the Wi-Fi radio. shell.qml grabs
// keyboard focus onto this root the moment the panel is toggled open.
Column {
    id: root
    width: parent ? parent.width : Theme.panelW
    spacing: 8
    focus: true

    signal shareRequested

    property var wifiDevice: Net.wifiDevice ?? findAnyWifiDevice()
    property var pendingPskNetwork: null
    property int currentIndex: -1

    function findAnyWifiDevice(): var {
        const devices = Networking.devices ? Networking.devices.values : [];
        for (const d of devices) if (d instanceof WifiDevice) return d;
        return null;
    }

    function networkCount(): int {
        return root.wifiDevice && root.wifiDevice.networks ? root.wifiDevice.networks.values.length : 0;
    }

    function activateNetwork(net: var): void {
        if (net.connected) {
            net.disconnect();
        } else if (net.known) {
            net.connect();
        } else {
            root.pendingPskNetwork = net;
        }
    }

    Keys.onDownPressed: {
        if (root.pendingPskNetwork !== null) return;
        const count = networkCount();
        if (count > 0) root.currentIndex = (root.currentIndex + 1) % count;
    }
    Keys.onUpPressed: {
        if (root.pendingPskNetwork !== null) return;
        const count = networkCount();
        if (count > 0) root.currentIndex = (root.currentIndex - 1 + count) % count;
    }
    Keys.onLeftPressed: Networking.wifiEnabled = false
    Keys.onRightPressed: Networking.wifiEnabled = true
    Keys.onReturnPressed: activateCurrent()
    Keys.onEnterPressed: activateCurrent()
    Keys.onEscapePressed: event => {
        if (root.pendingPskNetwork !== null) {
            root.pendingPskNetwork = null;
            event.accepted = true;
        }
    }
    Keys.onPressed: event => {
        if ((event.key === Qt.Key_S) && root.pendingPskNetwork === null && Net.wifiConnected) {
            root.shareRequested();
            event.accepted = true;
        }
    }

    function activateCurrent(): void {
        if (root.pendingPskNetwork !== null || root.currentIndex < 0) return;
        const nets = root.wifiDevice && root.wifiDevice.networks ? root.wifiDevice.networks.values : [];
        if (root.currentIndex < nets.length) activateNetwork(nets[root.currentIndex]);
    }

    Row {
        width: parent.width

        Text {
            width: parent.width - toggle.width - (shareIcon.visible ? shareIcon.width + 8 : 0)
            text: "Wi-Fi"
            font.family: Theme.font
            font.pixelSize: Theme.fsValue
            color: Theme.fg
            verticalAlignment: Text.AlignVCenter
            height: toggle.height
        }

        Text {
            id: shareIcon
            visible: Net.wifiConnected
            text: "󰐲"
            font.family: Theme.font
            font.pixelSize: Theme.fsValue
            color: Colors.accent
            anchors.verticalCenter: parent.verticalCenter
            rightPadding: 8

            MouseArea { anchors.fill: parent; onClicked: root.shareRequested() }
        }

        Rectangle {
            id: toggle
            width: 40
            height: 20
            radius: 10
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

    Repeater {
        model: root.wifiDevice ? root.wifiDevice.networks : null

        Column {
            id: row
            required property var modelData
            required property int index
            width: root.width
            visible: Networking.wifiEnabled
            spacing: 4

            Rectangle {
                width: row.width
                height: 34
                radius: 8
                color: (netArea.containsMouse || row.index === root.currentIndex) ? Colors.surface : "transparent"
                border.width: row.index === root.currentIndex ? 1 : 0
                border.color: Colors.accent

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: Net.signalGlyph(row.modelData.signalStrength)
                        font.family: Theme.font
                        font.pixelSize: Theme.fsValue
                        color: row.modelData.connected ? Colors.accent : Theme.fg
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        width: parent.width - 60
                        text: row.modelData.name
                        font.family: Theme.font
                        font.pixelSize: Theme.fsValue
                        color: row.modelData.connected ? Colors.accent : Theme.fg
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        visible: row.modelData.connected
                        text: "✓"
                        color: Colors.accent
                        font.pixelSize: Theme.fsValue
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: netArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.currentIndex = row.index;
                        root.activateNetwork(row.modelData);
                    }
                }
            }

            // Password entry, shown only for the network just clicked when
            // it isn't already known to NetworkManager.
            Row {
                visible: root.pendingPskNetwork === row.modelData
                width: row.width
                spacing: 6

                Rectangle {
                    width: row.width - connectBtn.width - 6
                    height: 30
                    radius: 6
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.rule

                    TextInput {
                        id: pskInput
                        anchors.fill: parent
                        anchors.margins: 8
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fsValue
                        focus: root.pendingPskNetwork === row.modelData
                        onAccepted: connectBtn.doConnect()
                    }
                }

                Rectangle {
                    id: connectBtn
                    width: 60
                    height: 30
                    radius: 6
                    color: Colors.accent

                    function doConnect(): void {
                        row.modelData.connectWithPsk(pskInput.text);
                        root.pendingPskNetwork = null;
                        pskInput.text = "";
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Join"
                        color: Theme.surface
                        font.family: Theme.font
                        font.pixelSize: Theme.fsLabel
                    }
                    MouseArea { anchors.fill: parent; onClicked: connectBtn.doConnect() }
                }
            }
        }
    }

    Text {
        visible: !root.wifiDevice
        text: "No Wi-Fi adapter found"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsValue
    }
}
