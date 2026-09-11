import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Full connection info for the active Wi-Fi network, plus a scannable share
// QR (SSID + password) -- the omarchy-style "network detail" card. Reached
// from Network.qml's share icon (or 'S') while connected to Wi-Fi.
// qrencode does the actual encoding; network-qr.sh (ported from omarchy's
// omarchy-network-qr) collapses its ASCII output into a 0/1 matrix this
// renders as native Rectangles -- crisp at any size, no image decode.
Column {
    id: root
    width: parent ? parent.width : Theme.panelW
    spacing: 10
    focus: true

    Keys.onEscapePressed: event => {
        if (root.passwordVisible) {
            root.passwordVisible = false;
            event.accepted = true;
        }
    }
    Keys.onPressed: event => {
        if ((event.key === Qt.Key_P || event.key === Qt.Key_Space) && root.secured) {
            root.togglePassword();
            event.accepted = true;
        }
    }

    property var qrRows: []
    property int qrSize: 0
    property string error: ""
    property string ssid: ""
    property string iface: ""
    property bool secured: false
    property string password: ""
    property bool passwordVisible: false
    property string passwordError: ""

    function togglePassword(): void {
        if (root.passwordVisible) { root.passwordVisible = false; return; }
        if (root.password !== "") { root.passwordVisible = true; return; }
        if (pwProc.running || !root.iface) return;
        root.passwordError = "";
        pwProc.command = [Qt.resolvedUrl("../scripts/network-password.sh").toString().replace("file://", ""), root.iface];
        pwProc.running = true;
    }

    Component.onCompleted: {
        qrProc.command = [Qt.resolvedUrl("../scripts/network-qr.sh").toString().replace("file://", "")];
        qrProc.running = true;
        Net.detailsActive = true;
    }
    Component.onDestruction: Net.detailsActive = false

    Process {
        id: qrProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const lines = text.trim().split(/\r?\n/).filter(l => l !== "");
                if (lines.length > 0 && lines[0].indexOf("meta\t") === 0) {
                    const fields = lines.shift().split("\t");
                    root.iface = fields[1] || "";
                    root.secured = (fields[2] || "") !== "" && fields[2] !== "nopass";
                    root.ssid = fields.slice(3).join("\t");
                }
                const size = lines.length > 0 ? lines[0].length : 0;
                if (size > 0 && lines.every(l => l.length === size && /^[01]+$/.test(l))) {
                    root.qrRows = lines;
                    root.qrSize = size;
                    root.error = "";
                } else {
                    root.qrRows = [];
                    root.qrSize = 0;
                }
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: if (text.trim() !== "") root.error = text.trim()
        }
    }

    Process {
        id: pwProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.password = text.trim()
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: if (text.trim() !== "") root.passwordError = text.trim()
        }
        onExited: exitCode => {
            if (exitCode === 0 && root.password !== "") root.passwordVisible = true;
            else if (root.passwordError === "") root.passwordError = "Could not read the Wi-Fi password";
        }
    }

    Text {
        text: root.ssid !== "" ? root.ssid : "Wi-Fi"
        font.family: Theme.font
        font.pixelSize: Theme.fsValue
        font.bold: true
        color: Theme.fg
        elide: Text.ElideRight
        width: parent.width
    }

    Grid {
        columns: 2
        columnSpacing: 12
        rowSpacing: 2
        width: parent.width

        Text { text: "IP"; color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fsLabel }
        Text { text: Net.ip !== "" ? Net.ip : "--"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fsLabel }

        Text { text: "Signal"; color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fsLabel }
        Text { text: Net.wifiConnected ? Math.round(Net.signalStrength) + "%" : "--"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fsLabel }
    }

    Rectangle {
        id: qrCanvas
        readonly property int moduleSize: root.qrSize > 0 ? Math.max(3, Math.floor((Theme.panelW - 24) / root.qrSize)) : 0

        visible: root.qrSize > 0 && root.error === ""
        width: root.qrSize * moduleSize
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        color: "white"
        radius: Theme.radius / 2

        Grid {
            anchors.fill: parent
            columns: root.qrSize

            Repeater {
                model: root.qrSize * root.qrSize

                Rectangle {
                    required property int index
                    readonly property int matrixRow: Math.floor(index / root.qrSize)
                    readonly property int matrixColumn: index % root.qrSize

                    width: qrCanvas.moduleSize
                    height: qrCanvas.moduleSize
                    color: root.qrRows[matrixRow].charAt(matrixColumn) === "1" ? "#111111" : "transparent"
                }
            }
        }
    }

    Text {
        visible: root.qrSize === 0 && root.error === ""
        text: "Generating QR code…"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
    }

    Text {
        visible: root.error !== ""
        text: root.error
        color: Theme.red
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
        wrapMode: Text.Wrap
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
    }

    Text {
        visible: root.qrSize > 0 && root.error === ""
        text: "Scan to join this network"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
    }

    Text {
        visible: root.qrSize > 0 && root.secured
        text: root.passwordError !== "" ? root.passwordError
            : root.passwordVisible ? root.password
            : "Show password (P)"
        color: root.passwordError !== "" ? Theme.red : Colors.accent
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
        width: parent.width
        horizontalAlignment: Text.AlignHCenter

        MouseArea { anchors.fill: parent; onClicked: root.togglePassword() }
    }
}
