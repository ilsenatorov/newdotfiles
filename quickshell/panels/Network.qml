import QtQuick
import Quickshell.Networking
import ".."
import "../services"

// Replaces the SUPER+N networkmanager_dmenu rofi menu. Live NetworkManager
// state via Quickshell.Networking -- no omarchy-network-status polling.
Column {
    id: root
    width: parent ? parent.width : Theme.panelW
    spacing: 8

    property var wifiDevice: Net.wifiDevice ?? findAnyWifiDevice()
    property var pendingPskNetwork: null

    function findAnyWifiDevice(): var {
        const devices = Networking.devices ? Networking.devices.values : [];
        for (const d of devices) if (d instanceof WifiDevice) return d;
        return null;
    }

    Row {
        width: parent.width

        Text {
            width: parent.width - toggle.width
            text: "Wi-Fi"
            font.family: Theme.font
            font.pixelSize: Theme.fsValue
            color: Theme.fg
            verticalAlignment: Text.AlignVCenter
            height: toggle.height
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
            width: root.width
            visible: Networking.wifiEnabled
            spacing: 4

            Rectangle {
                width: row.width
                height: 34
                radius: 8
                color: netArea.containsMouse ? Colors.surface : "transparent"

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
                        if (row.modelData.connected) {
                            row.modelData.disconnect();
                        } else if (row.modelData.known) {
                            row.modelData.connect();
                        } else {
                            root.pendingPskNetwork = row.modelData;
                        }
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
