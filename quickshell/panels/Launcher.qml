import QtQuick
import Quickshell
import ".."
import "../ui"

// SUPER+D. Replaces `rofi -show drun -theme rofi/styles/launcher.rasi`
// (rofi/launcher.sh), the last thing rofi was still doing on this machine.
//
// Quickshell indexes the XDG .desktop files itself via DesktopEntries, so
// there is nothing here that parses /usr/share/applications -- the whole
// component is a model source plus one activation, which is the point of
// ui/Picker.qml owning everything else.
Picker {
    id: root

    placeholder: "Programs"
    showIcons: true
    cardWidth: Theme.menuW

    // NoDisplay entries are the ones a desktop is explicitly told not to
    // offer (mime handlers, settings shims) -- rofi hid them too. Sorted by
    // name so an unfiltered launcher opens on a predictable list rather than
    // whatever order the filesystem walk produced.
    items: {
        const apps = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        return apps.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name)).map(a => ({
                    label: a.name,
                    // genericName/comment are what make "browser" find Firefox.
                    sublabel: a.genericName || a.comment || "",
                    icon: a.icon,
                    key: a
                }));
    }

    // execute() re-parses the entry's own Exec field codes (%U, %f, terminal
    // handling) -- the reason this hands the DesktopEntry back rather than a
    // command string it would have to re-implement.
    onAccepted: item => {
        item.key.execute();
        root.closeRequested();
    }
}
