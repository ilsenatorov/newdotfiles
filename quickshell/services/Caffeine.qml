pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// "Keep the screen awake" switch. The inhibitor itself is an IdleInhibitor in
// shell.qml, attached to the primary bar's window (it has to hang off a
// mapped surface, and the bar always is). hypridle honours Wayland idle
// inhibitors, so dim/lock/suspend all hold off while this is on.
//
// Not persisted on purpose: a forgotten caffeine toggle surviving a reboot is
// how a laptop ends up never sleeping.
Singleton {
    id: root

    property bool enabled: false

    function toggle(): void { root.enabled = !root.enabled; }

    IpcHandler {
        target: "caffeine"

        function toggle(): void { root.toggle(); }
        function get(): string { return root.enabled ? "on" : "off"; }
    }
}
