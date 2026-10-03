import QtQuick
import Quickshell
import ".."
import "../services"
import "../ui"

// SUPER+SHIFT+S. Replaces rofi/powermenu-hypr.sh, which was
// `rofi -theme powermenu.rasi -dmenu -selected-row 0` over five lines plus a
// case statement. The option order and every command are carried over
// verbatim from that script -- this is a re-skin, not a redesign.
//
// Not searchable: five fixed choices, so an input box would only add a
// keystroke between the bind and the action. Enter on the pre-selected first
// row is exactly what `-selected-row 0` gave.
Picker {
    id: root

    searchable: false
    cardWidth: Theme.menuNarrowW

    // Commands and glyphs live in services/Power.qml, shared with the SUPER+D
    // search.
    items: Power.items

    onAccepted: item => {
        root.closeRequested();
        Power.run(item.key);
    }
}
