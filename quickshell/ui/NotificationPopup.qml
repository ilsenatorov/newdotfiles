import QtQuick
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import ".."

// One toast. Geometry/behavior ported 1:1 from mako/config: 380 wide, radius
// 12, border 2, padding 10/14, markup+icons on, left-click dismiss,
// right-click dismiss-all (handled by the stack, see NotificationStack.qml),
// left-click takes you to the sender (see activate()),
// middle-click invokes the default action. Per-urgency border/text color and
// timeout mirror mako's [urgency=low]/[urgency=critical] rules; critical
// never auto-expires, same as mako's default-timeout=0 there.
Rectangle {
    id: root

    required property var notification
    signal dismissAll

    readonly property int urgency: notification.urgency
    readonly property bool low: urgency === NotificationUrgency.Low
    readonly property bool critical: urgency === NotificationUrgency.Critical

    width: Theme.notifWidth
    implicitHeight: Math.max(Theme.notifMinHeight, col.implicitHeight + Math.round(20 * Theme.s))
    radius: Theme.radius
    color: Theme.barPill
    border.width: Theme.notifBorder
    border.color: critical ? Theme.red : low ? Theme.rule : Colors.accent

    // mako's default-timeout: 6000 normal, 4000 low, critical never expires.
    // Notification.expireTimeout is read-only (server-negotiated) so this is
    // applied here rather than on the model object; a sender that asked for
    // its own positive timeout is honored instead.
    Timer {
        running: !critical
        interval: notification.expireTimeout > 0 ? notification.expireTimeout
            : (low ? Theme.notifLowTimeout : Theme.notifDefaultTimeout)
        onTriggered: notification.expire()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) root.dismissAll();
            else if (mouse.button === Qt.MiddleButton && notification.actions.length > 0)
                notification.actions[0].invoke();
            else
                root.activate();
        }
    }

    // Focus the window the notification came from, then run its default
    // action (opens the chat/tab in Slack, Telegram, browsers) or dismiss.
    // x-hyprland-address is our own hint: ~/.claude/notify.sh sets it to the
    // exact kitty window Claude runs in. It's Lua-eval'd by Hyprland, hence
    // the strict pattern. Otherwise match the app's window by class.
    function activate(): void {
        const addr = String(notification.hints["x-hyprland-address"] ?? "");
        if (/^0x[0-9a-f]+$/.test(addr)) {
            Hyprland.dispatch("hl.dsp.focus({window='address:" + addr + "'})");
        } else {
            const want = [notification.desktopEntry, notification.appName]
                .filter(n => n).map(n => n.toLowerCase());
            // ponytail: first window of the app wins; several windows of one
            // app (browsers) may focus the wrong one -- the default action
            // usually corrects that by raising its own window.
            const win = ToplevelManager.toplevels.values.find(t => {
                const id = t.appId.toLowerCase();
                return want.some(n => id === n || id.endsWith("." + n) || n.includes(id));
            });
            if (win) win.activate();
        }
        const def = notification.actions.find(a => a.identifier === "default");
        if (def) def.invoke();
        else notification.dismiss();
    }

    Row {
        id: outer
        anchors.fill: parent
        anchors.margins: Math.round(14 * Theme.s)
        spacing: Math.round(10 * Theme.s)

        Image {
            id: icon
            visible: notification.image !== "" || notification.appIcon !== ""
            source: notification.image !== "" ? notification.image : notification.appIcon
            width: Theme.notifIconSize
            height: Theme.notifIconSize
            anchors.top: parent.top
            fillMode: Image.PreserveAspectFit
        }

        Column {
            id: col
            width: outer.width - (icon.visible ? Theme.notifIconSize + outer.spacing : 0)
            spacing: Math.round(4 * Theme.s)

            Text {
                width: parent.width
                text: notification.summary
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
                font.bold: true
                color: Theme.fg
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
            }

            Text {
                visible: notification.body !== ""
                width: parent.width
                text: notification.body
                textFormat: Text.RichText
                font.family: Theme.font
                font.pixelSize: Theme.fsValue
                color: Theme.dim
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 4
            }

            Row {
                visible: notification.actions.length > 0
                spacing: Math.round(6 * Theme.s)
                topPadding: Math.round(4 * Theme.s)

                Repeater {
                    model: notification.actions

                    Rectangle {
                        required property var modelData
                        width: actionLabel.implicitWidth + Math.round(16 * Theme.s)
                        height: Math.round(26 * Theme.s)
                        radius: Math.round(8 * Theme.s)
                        color: actionArea.containsMouse ? Colors.surface : "transparent"
                        border.width: 1
                        border.color: Theme.rule

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            font.family: Theme.font
                            font.pixelSize: Theme.fsLabel
                            color: Colors.accent
                        }

                        MouseArea {
                            id: actionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: parent.modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
