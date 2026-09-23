import QtQuick
import Quickshell
import ".."
import Quickshell.Io
import "../ui"

// SUPER+W. Replaces the `rofi -dmenu -i -p Wallpaper` prompt that used to
// live inside hypr/scripts/set-wallpaper.sh.
//
// The script keeps everything that matters -- the ffmpeg frame-grab for
// video wallpapers, the matugen run, the mpvpaper/swww handoff -- and now
// also owns the file listing behind `--list`. That is deliberate: the set of
// wallpaper extensions is one list, in the script, not duplicated here where
// the two could drift apart.
Picker {
    id: root

    placeholder: "Wallpaper"
    cardWidth: Theme.menuW
    items: []
    emptyText: "No wallpapers in ~/Pictures/Wallpapers"

    // shellPath(), not Qt.resolvedUrl(): Quickshell serves its QML from a qrc:
    // resource, so resolvedUrl() yields a qrc: path that Process cannot exec.
    // shellPath() resolves against the real shell root, so this works both via
    // the ~/.config/quickshell symlink and from the repo directly.
    readonly property string script: Quickshell.shellPath("../hypr/scripts/set-wallpaper.sh")

    Process {
        running: true
        command: [root.script, "--list"]

        stdout: StdioCollector {
            onStreamFinished: {
                // Paths are relative to WALLDIR and recursive, so a row can be
                // "nature/forest.mp4". Showing the whole relative path (not a
                // basename) is what keeps two same-named files apart -- the
                // same reasoning the script's own comment gives.
                root.items = text.split("\n").filter(l => l.trim() !== "").map(l => ({
                            label: l,
                            key: l
                        }));
            }
        }
    }

    onAccepted: item => {
        root.closeRequested();
        // --set takes the WALLDIR-relative path and does the rest.
        Quickshell.execDetached([root.script, "--set", item.key]);
    }
}
