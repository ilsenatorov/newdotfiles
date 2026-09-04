import QtQuick
import ".."
import "../services"

// Replaces rofi-bluetooth (SUPER+Y). Live Bluez state via
// Quickshell.Bluetooth -- no bluetoothctl scraping.
Column {
    id: root
    width: parent ? parent.width : Theme.panelW
    spacing: 8

    Row {
        width: parent.width

        Text {
            width: parent.width - toggle.width
            text: Bt.available ? "Bluetooth" : "No adapter found"
            font.family: Theme.font
            font.pixelSize: Theme.fsValue
            color: Theme.fg
            verticalAlignment: Text.AlignVCenter
            height: toggle.height
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

    Repeater {
        model: Bt.powered ? Bt.devices : []

        Rectangle {
            id: devRow
            required property var modelData
            width: root.width
            height: 34
            radius: 8
            color: devArea.containsMouse ? Colors.surface : "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                Text {
                    text: devRow.modelData.connected ? "󰂱" : "󰂯"
                    color: devRow.modelData.connected ? Colors.accent : Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    width: parent.width - 90
                    text: devRow.modelData.name
                    color: devRow.modelData.connected ? Colors.accent : Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    visible: devRow.modelData.batteryAvailable
                    text: Math.round(devRow.modelData.battery * 100) + "%"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: devArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        devRow.modelData.forget();
                        return;
                    }
                    if (devRow.modelData.connected) devRow.modelData.disconnect();
                    else if (devRow.modelData.paired) devRow.modelData.connect();
                    else devRow.modelData.pair();
                }
            }
        }
    }

    Text {
        visible: Bt.powered && Bt.devices.length === 0
        text: "No devices found"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
    }

    Text {
        visible: Bt.powered && Bt.devices.length > 0
        text: "Right-click a device to forget it"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel - 1
    }
}
