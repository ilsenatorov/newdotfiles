import QtQuick
import ".."
import "../services"

// Replaces rofi-bluetooth (SUPER+Y). Live Bluez state via
// Quickshell.Bluetooth -- no bluetoothctl scraping.
// Fully keyboard-drivable: Up/Down move the selection, Enter/Return acts on
// it (connect/disconnect/pair, mirroring a left click), F forgets the
// selected device (mirroring a right click). shell.qml grabs keyboard focus
// onto this root the moment the panel is toggled open.
Column {
    id: root
    width: parent ? parent.width : Theme.panelW
    spacing: 8
    focus: true

    property int currentIndex: -1

    Keys.onDownPressed: {
        const count = Bt.powered ? Bt.devices.length : 0;
        if (count > 0) root.currentIndex = (root.currentIndex + 1) % count;
    }
    Keys.onUpPressed: {
        const count = Bt.powered ? Bt.devices.length : 0;
        if (count > 0) root.currentIndex = (root.currentIndex - 1 + count) % count;
    }
    Keys.onReturnPressed: activateCurrent()
    Keys.onEnterPressed: activateCurrent()
    Keys.onPressed: event => {
        if ((event.key === Qt.Key_F || event.key === Qt.Key_Delete) && root.currentIndex >= 0 && Bt.powered) {
            Bt.devices[root.currentIndex].forget();
            event.accepted = true;
        }
    }

    function activateCurrent(): void {
        if (root.currentIndex < 0 || !Bt.powered || root.currentIndex >= Bt.devices.length) return;
        const dev = Bt.devices[root.currentIndex];
        if (dev.connected) dev.disconnect();
        else if (dev.paired) dev.connect();
        else dev.pair();
    }

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
            required property int index
            width: root.width
            height: 34
            radius: 8
            color: (devArea.containsMouse || devRow.index === root.currentIndex) ? Colors.surface : "transparent"
            border.width: devRow.index === root.currentIndex ? 1 : 0
            border.color: Colors.accent

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
                    root.currentIndex = devRow.index;
                    if (mouse.button === Qt.RightButton) {
                        devRow.modelData.forget();
                        return;
                    }
                    root.activateCurrent();
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
        text: "Right-click (or F) a device to forget it"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel - 1
    }
}
