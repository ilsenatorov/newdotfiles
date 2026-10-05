import QtQuick
import Quickshell
import ".."
import "../services"
import "../ui"

// History of every notification since it was last cleared, grouped by app,
// newest first -- the part mako never had. Toasts vanish after a few
// seconds; this is where they end up. Also the Do Not Disturb switch.
// Hosted as the bar dropdown (click the bell) and as a SUPER+D page (o).
//
// Keys: ↑/↓ move, Delete remove, d toggle DND, Shift+C clear all. Esc falls
// through to shell.qml.
Column {
    id: root
    width: parent ? parent.width : Theme.panelW
    spacing: Math.round(10 * Theme.s)
    focus: true

    property int currentIndex: 0

    // History regrouped by app: apps ordered by their newest notification,
    // each app's entries newest first. The first entry of a group carries
    // `header` so the delegate can draw the app name above it.
    readonly property var entries: {
        const groups = new Map();
        for (const e of Notifications.history) {
            if (!groups.has(e.appName)) groups.set(e.appName, []);
            groups.get(e.appName).push(e);
        }
        const out = [];
        for (const [app, list] of groups)
            list.forEach((e, i) => out.push(Object.assign({ header: i === 0 ? app : "" }, e)));
        return out;
    }
    // Refreshed once a minute so "3m ago" keeps moving while open.
    property real now: Date.now()

    Timer {
        running: true
        repeat: true
        interval: 30000
        onTriggered: root.now = Date.now()
    }

    Component.onCompleted: {
        root.forceActiveFocus();
        Notifications.markRead();
    }

    // Entries arriving while open count as read too -- you're looking at them.
    Connections {
        target: Notifications
        function onHistoryChanged() { Qt.callLater(Notifications.markRead); }
    }

    onCurrentIndexChanged: list.positionViewAtIndex(root.currentIndex, ListView.Contain)

    Keys.onPressed: event => {
        const n = root.entries.length;
        const k = event.key;
        if (k === Qt.Key_Down || k === Qt.Key_J) {
            if (n > 0) root.currentIndex = Math.min(n - 1, root.currentIndex + 1);
        } else if (k === Qt.Key_Up || k === Qt.Key_K) {
            if (n > 0) root.currentIndex = Math.max(0, root.currentIndex - 1);
        } else if (k === Qt.Key_Delete || k === Qt.Key_X) {
            const e = root.entries[root.currentIndex];
            if (e) Notifications.remove(e.uid);
            root.currentIndex = Math.max(0, Math.min(root.currentIndex, root.entries.length - 1));
        } else if (k === Qt.Key_D) {
            Notifications.toggleDnd();
        } else if (k === Qt.Key_C && (event.modifiers & Qt.ShiftModifier)) {
            // Shift: one stray key while this has the keyboard grab
            // shouldn't wipe the whole history.
            Notifications.clearHistory();
            root.currentIndex = 0;
        } else {
            return;
        }
        event.accepted = true;
    }

    function ago(t: real): string {
        const s = Math.max(0, Math.floor((root.now - t) / 1000));
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    function iconFor(e: var): string {
        if (e.image) return e.image;
        if (!e.appIcon) return "";
        if (e.appIcon.startsWith("/")) return "file://" + e.appIcon;
        if (e.appIcon.includes("://")) return e.appIcon;
        return Quickshell.iconPath(e.appIcon, true);
    }

    // ---- header: DND + clear ----------------------------------------------
    Item {
        width: parent.width
        height: Math.round(26 * Theme.s)

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(8 * Theme.s)

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: Notifications.dnd
                hue: Colors.red
                onToggled: Notifications.toggleDnd()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Notifications.dnd ? "󰂛  Do not disturb" : "Do not disturb"
                color: Notifications.dnd ? Theme.fg : Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
            }
        }

        Rectangle {
            visible: Notifications.history.length > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: clearLabel.implicitWidth + Math.round(16 * Theme.s)
            height: Math.round(24 * Theme.s)
            radius: Math.round(8 * Theme.s)
            color: clearArea.containsMouse ? Colors.surface : "transparent"
            border.width: 1
            border.color: Theme.rule

            Text {
                id: clearLabel
                anchors.centerIn: parent
                text: "Clear all"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel - 1
            }
            MouseArea {
                id: clearArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Notifications.clearHistory()
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.rule
    }

    Text {
        visible: Notifications.history.length === 0
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        topPadding: Math.round(12 * Theme.s)
        bottomPadding: Math.round(12 * Theme.s)
        text: "󰂜  No notifications"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsValue
    }

    ListView {
        id: list

        visible: Notifications.history.length > 0
        width: parent.width
        // Grows with content up to roughly half a 1080p screen, then scrolls.
        height: Math.min(contentHeight, Math.round(460 * Theme.s))
        clip: true
        spacing: Math.round(4 * Theme.s)
        boundsBehavior: Flickable.StopAtBounds
        model: root.entries

        delegate: Column {
            id: entry

            required property var modelData
            required property int index

            width: list.width
            spacing: Math.round(2 * Theme.s)

            Text {
                visible: entry.modelData.header !== ""
                width: list.width
                topPadding: entry.index > 0 ? 6 : 0
                text: entry.modelData.header
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel - Math.round(2 * Theme.s)
                font.bold: true
            }

            Rectangle {
                id: row

                readonly property var modelData: entry.modelData
                readonly property int index: entry.index
                readonly property bool current: index === root.currentIndex

                width: list.width
                height: inner.implicitHeight + Math.round(14 * Theme.s)
                radius: Math.round(8 * Theme.s)
                color: current || rowArea.containsMouse ? Colors.surface : "transparent"
                border.width: current ? 1 : 0
                border.color: Colors.accent

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.currentIndex = row.index
                }

                Row {
                    id: inner
                    x: Math.round(8 * Theme.s)
                    y: Math.round(7 * Theme.s)
                    width: parent.width - Math.round(16 * Theme.s)
                    spacing: Math.round(8 * Theme.s)

                    Image {
                        id: icon
                        readonly property string src: root.iconFor(row.modelData)
                        visible: src !== "" && status !== Image.Error
                        source: src
                        width: Math.round(28 * Theme.s)
                        height: width
                        sourceSize.width: width * 2
                        sourceSize.height: height * 2
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    Column {
                        width: inner.width - (icon.visible ? icon.width + inner.spacing : 0) - Math.round(26 * Theme.s)
                        spacing: Math.round(2 * Theme.s)

                        Item {
                            width: parent.width
                            height: summary.implicitHeight

                            Text {
                                id: summary
                                width: parent.width - when.implicitWidth - Math.round(8 * Theme.s)
                                text: row.modelData.summary
                                color: row.modelData.urgency === 2 ? Theme.red : Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.fsLabel
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                id: when
                                anchors.right: parent.right
                                text: root.ago(row.modelData.time)
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fsLabel - Math.round(2 * Theme.s)
                            }
                        }

                        Text {
                            visible: row.modelData.body !== ""
                            width: parent.width
                            text: row.modelData.body
                            textFormat: Text.StyledText
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fsLabel - 1
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(6 * Theme.s)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(22 * Theme.s)
                    horizontalAlignment: Text.AlignHCenter
                    text: "×"
                    color: closeArea.containsMouse ? Theme.red : Theme.dim
                    font.pixelSize: Theme.fsValue

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: Math.round(-4 * Theme.s)
                        hoverEnabled: true
                        onClicked: Notifications.remove(row.modelData.uid)
                    }
                }
            }
        }
    }

    Text {
        width: parent.width
        text: "↑↓ move · del remove · d dnd · shift+c clear"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel - 1
    }
}
