import QtQuick
import ".."
import "../services"
import "../ui"

// `?` in the SUPER+D hub. A searchable list of every Hyprland
// bind -- the data and its formatting live in services/KeybindList.qml, which
// the SUPER+D search's `?` mode shares.
//
// Read-only: Enter just closes. Most binds are Lua closures (dispatcher
// "__lua"), which hyprctl can't re-run from outside anyway.
Picker {
    id: root

    placeholder: "Keybinds · type to search"
    cardWidth: Theme.menuW
    emptyText: "No keybinds reported by hyprctl"
    items: KeybindList.items

    Component.onCompleted: KeybindList.refresh()

    onAccepted: root.closeRequested()
}
