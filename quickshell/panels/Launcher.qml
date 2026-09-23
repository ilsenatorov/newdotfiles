import QtQuick
import Quickshell
import ".."
import "../services"
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
    // offer (mime handlers, settings shims) -- rofi hid them too.
    //
    // Ordered by how often each app has actually been launched from here
    // (LauncherUsage), most-used first, so the common few sit under the
    // cursor and Enter alone runs them. Ties go to whichever was used more
    // recently, and apps never launched from here fall back to alphabetical
    // -- without that last step an untouched launcher would open in
    // filesystem-walk order, which looks random.
    //
    // ui/Picker.qml's filter preserves this order, so typing narrows the
    // list without disturbing the ranking.
    items: {
        const apps = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        return apps.filter(a => !a.noDisplay).sort((a, b) => {
            const ca = LauncherUsage.countFor(a.id);
            const cb = LauncherUsage.countFor(b.id);
            if (ca !== cb)
                return cb - ca;
            const la = LauncherUsage.lastFor(a.id);
            const lb = LauncherUsage.lastFor(b.id);
            if (la !== lb)
                return lb - la;
            return a.name.localeCompare(b.name);
        }).map(a => ({
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
        LauncherUsage.record(item.key.id);
        item.key.execute();
        root.closeRequested();
    }
}
