import QtQuick
import QtQml
import Quickshell
import ".."
import Quickshell.Io
import "../ui"

// SUPER+W. Replaces the `rofi -dmenu -i -p Wallpaper` prompt that used to
// live inside hypr/scripts/set-wallpaper.sh.
//
// A carousel rather than the ui/Picker.qml list every other ported menu
// uses: a wallpaper is picked by looking at it, and the thing that actually
// changes when you pick one -- the whole colour scheme -- is a row of
// swatches under each slide, not something a filename can tell you. Picker
// still owns the launcher, clipboard, power, exit and monitor menus; with a
// handful of wallpapers a search box earned nothing here.
//
// The script keeps everything that matters -- the ffmpeg frame-grab for
// video wallpapers, the matugen run, the mpvpaper/swww handoff -- and also
// owns the file listing behind `--list` and the swatches behind `--palette`.
// That is deliberate: the set of wallpaper extensions is one list, in the
// script, and the colourbar is the real scheme matugen would generate rather
// than a second guess at it made here, where the two could drift apart.
Item {
    id: root

    signal closeRequested

    // Each entry: { label, key } -- key is the WALLDIR-relative path --set
    // takes, label is the same path shown to the reader. Relative and not a
    // basename, because the listing is recursive and two subfolders may hold
    // the same filename (the script's own comment spells this out).
    property var items: []
    // key -> { thumb: <path>, colors: [hex, ...] }, filled in lazily by the
    // queue below. `var` and replaced wholesale on every write: mutating a
    // JS object in place notifies nobody, so the delegates would never see it.
    property var palettes: ({})
    property string error: ""

    // shellPath(), not Qt.resolvedUrl(): Quickshell serves its QML from a qrc:
    // resource, so resolvedUrl() yields a qrc: path that Process cannot exec.
    // shellPath() resolves against the real shell root, so this works both via
    // the ~/.config/quickshell symlink and from the repo directly.
    readonly property string script: Quickshell.shellPath("../hypr/scripts/set-wallpaper.sh")

    readonly property var current: list.currentIndex >= 0 ? root.items[list.currentIndex] : null
    readonly property var currentPalette: root.current ? root.palettes[root.current.key] ?? null : null

    function apply(): void {
        if (!root.current)
            return;
        root.closeRequested();
        // --set takes the WALLDIR-relative path and does the rest.
        Quickshell.execDetached([root.script, "--set", root.current.key]);
    }

    function step(delta: int): void {
        const count = root.items.length;
        if (count > 0)
            list.currentIndex = (list.currentIndex + delta + count) % count;
    }

    Process {
        running: true
        command: [root.script, "--list"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.items = text.split("\n").filter(l => l.trim() !== "").map(l => ({
                            label: l,
                            key: l
                        }));
                if (root.items.length === 0)
                    root.error = "No wallpapers in ~/Pictures/Wallpapers";
                // The model arrives after the ListView exists, and a strictly
                // enforced highlight range derives currentIndex from the
                // scroll position -- which is meaningless until there is
                // something to scroll. Say where to start, explicitly.
                list.currentIndex = 0;
                list.positionViewAtBeginning();
            }
        }
    }

    // ---- palettes ---------------------------------------------------------
    // matugen costs ~0.4s per wallpaper the first time (the script caches it
    // after that), so palettes are fetched only for the slide in view and its
    // two neighbours -- the ones a step away from being looked at.
    //
    // One Process per wanted key rather than one shared Process working a
    // queue: a shared one has to be told which key its output belongs to, and
    // a Process signals its exit before its stdout is drained, so by the time
    // the text arrives the shared "currently loading" key has already moved
    // on -- every palette lands one slide off. A Process that owns its key
    // cannot make that mistake.
    readonly property var wanted: {
        const out = [];
        if (list.currentIndex < 0)
            return out;
        for (const offset of [0, 1, -1]) {
            const i = list.currentIndex + offset;
            if (i < 0 || i >= root.items.length)
                continue;
            const key = root.items[i].key;
            // Already answered (or answered with nothing) => never asked
            // again, so a file the script cannot read costs one run, not one
            // per time it scrolls past.
            if (!(key in root.palettes) && !out.includes(key))
                out.push(key);
        }
        return out;
    }

    // `var` and replaced wholesale: mutating a JS object in place notifies
    // nobody, so the delegates would never see the new palette.
    function record(key: string, entry: var): void {
        const next = Object.assign({}, root.palettes);
        next[key] = entry;
        root.palettes = next;
    }

    Instantiator {
        model: root.wanted

        delegate: Process {
            id: paletteProc

            required property string modelData

            running: true
            command: [root.script, "--palette", paletteProc.modelData]

            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.split("\n").filter(l => l.trim() !== "");
                    root.record(paletteProc.modelData, lines.length > 1 ? {
                        thumb: lines[0],
                        colors: lines.slice(1)
                    } : null);
                }
            }

            // No output at all (the script died before printing) still counts
            // as an answer, or `wanted` would keep asking forever.
            onExited: {
                if (!(paletteProc.modelData in root.palettes))
                    root.record(paletteProc.modelData, null);
            }
        }
    }

    // ---- input ------------------------------------------------------------
    // Left/Right and h/l step; the arrows are what the eye reaches for and
    // hjkl is what the rest of this setup is driven with. Enter applies,
    // Escape closes -- same contract every other menu has.
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested();
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            root.step(1);
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            root.step(-1);
        } else if (event.key === Qt.Key_Home) {
            list.currentIndex = 0;
        } else if (event.key === Qt.Key_End) {
            list.currentIndex = root.items.length - 1;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.apply();
        } else {
            return;
        }
        event.accepted = true;
    }

    focus: true

    // A Loader (shell.qml's menuLoader) can settle its FocusScope's focus
    // chain before this item exists, so `focus: true` alone loses the race --
    // the same kick panels/Ask.qml and panels/Network.qml already need.
    Component.onCompleted: root.forceActiveFocus()

    // The window is fixed at the widest/tallest a menu can be (see shell.qml)
    // so that a menu never makes the layer-shell surface renegotiate its size
    // while open. The card inside is what sizes itself, and this fills the
    // leftover space to catch a click-away dismiss.
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    Surface {
        anchors.fill: card
    }

    Item {
        id: card

        anchors.centerIn: parent
        width: Math.min(Theme.menuWideW, root.width - Theme.inset * 2)
        height: Math.min(col.implicitHeight + Theme.pad, root.height - Theme.inset * 2)

        // Swallow clicks on the card so the dismiss handler above only fires
        // for the empty space around it.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: col

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.pad / 2
            spacing: 10

            Text {
                visible: root.items.length === 0
                width: col.width
                text: root.error !== "" ? root.error : "Loading wallpapers..."
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fsValue
            }

            // ---- the slides --------------------------------------------
            ListView {
                id: list

                visible: root.items.length > 0
                width: col.width
                height: root.items.length > 0 ? Theme.wallSlideH : 0
                orientation: ListView.Horizontal
                model: root.items
                currentIndex: 0
                spacing: 0
                clip: true
                // A delegate occupies one step, which is narrower than the
                // slide drawn inside it -- that overlap is what puts the
                // neighbours *behind* the current wallpaper instead of
                // beside it. The list's own geometry stays on the step; only
                // the picture overflows it.
                //
                // The current slide is pinned to the middle of the strip and
                // the list scrolls under it, so the neighbours always come
                // out from the same place -- a flick cannot leave it half-way
                // between two slides.
                snapMode: ListView.SnapOneItem
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: (list.width - Theme.wallSlideStep) / 2
                preferredHighlightEnd: (list.width + Theme.wallSlideStep) / 2
                // Delegates are laid out on the step, so a slide whose
                // picture still reaches into view can have its own step well
                // outside it. Keep a couple of screens' worth alive or the
                // ones peeking out from behind pop in and out.
                cacheBuffer: Theme.wallSlideW * 2
                highlightMoveDuration: Theme.durFast
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: slide

                    required property int index
                    required property var modelData

                    readonly property bool isCurrent: slide.index === list.currentIndex
                    readonly property var entry: root.palettes[slide.modelData.key] ?? null

                    width: Theme.wallSlideStep
                    height: list.height

                    // Nearest to the front. Without this the stacking order
                    // is creation order, and which wallpaper covers which
                    // would depend on how you got there.
                    z: -Math.abs(slide.index - list.currentIndex)

                    // The neighbours are context, not choices: shrunk and
                    // faded so the eye lands on the middle one without a
                    // border or a highlight having to say so.
                    scale: slide.isCurrent ? 1.0 : 0.82
                    opacity: slide.isCurrent ? 1.0 : 0.5

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durFast
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durFast
                        }
                    }

                    // The picture itself, wider than the step it is laid out
                    // on and centred in it, so it reaches under its
                    // neighbours on both sides.
                    Rectangle {
                        id: picture

                        anchors.centerIn: parent
                        width: Theme.wallSlideW
                        height: parent.height
                        radius: Theme.radius / 2
                        color: Theme.surface
                        border.width: 1
                        border.color: slide.isCurrent ? Colors.accent : Theme.rule
                        clip: true

                        Image {
                            anchors.fill: parent
                            // The thumbnail comes from --palette, never built
                            // from a path spliced together here: a video has
                            // no frame QML can show, and WALLDIR is the
                            // script's to know. Until it arrives the slide is
                            // an empty surface, which is a fraction of a
                            // second for anything already cached.
                            source: slide.entry ? "file://" + slide.entry.thumb : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            // Decode at the size actually drawn: a 4K
                            // wallpaper held at full resolution per slide is
                            // hundreds of MB for a menu.
                            sourceSize.width: Theme.wallSlideW
                            sourceSize.height: Theme.wallSlideH
                        }
                    }

                    MouseArea {
                        // On the picture, not the step: the part of a
                        // neighbour you can see is the part sticking out
                        // from behind, and that is outside the step. Where
                        // two pictures overlap the front one wins, which is
                        // the z order above.
                        anchors.fill: picture
                        // A click on a neighbour brings it to the middle
                        // rather than applying it sight-unseen; a click on
                        // what is already centred is the confirmation.
                        onClicked: {
                            if (slide.isCurrent)
                                root.apply();
                            else
                                list.currentIndex = slide.index;
                        }
                    }
                }
            }

            // ---- the colourbar -----------------------------------------
            // The eight colours matugen/templates/colors-quickshell.qml fills
            // in, in the order --palette prints them: accent, accentAlt, then
            // the six harmonized module hues. This is the whole point of the
            // carousel -- what the desktop turns into, shown before choosing.
            Item {
                visible: root.items.length > 0
                width: col.width
                height: Theme.wallSwatchH

                Row {
                    id: bar

                    // Counted off the palette, not off `children`: a Row's
                    // children include the Repeater itself, so measuring the
                    // swatches that way is off by one.
                    readonly property var swatches: root.currentPalette ? root.currentPalette.colors : []

                    anchors.centerIn: parent
                    width: Theme.wallSlideW
                    height: parent.height
                    spacing: 4

                    Repeater {
                        model: bar.swatches

                        Rectangle {
                            required property var modelData

                            width: (bar.width - bar.spacing * (bar.swatches.length - 1)) / bar.swatches.length
                            height: bar.height
                            radius: 3
                            color: modelData
                        }
                    }
                }

                // Nothing to draw yet (or nothing to draw at all, for a file
                // matugen could not read) -- say which, rather than leaving a
                // gap that reads as a layout bug.
                Text {
                    // Answered already but with nothing in it => the script
                    // could not read that file. Not answered yet => still
                    // running.
                    readonly property bool answered: root.current ? (root.current.key in root.palettes) : false

                    anchors.centerIn: parent
                    visible: !root.currentPalette
                    text: answered ? "no palette for this file" : "reading colours..."
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel
                }
            }

            // ---- name and position --------------------------------------
            Item {
                visible: root.items.length > 0
                width: col.width
                height: Theme.fsValue + 6

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - counter.width - 12
                    text: root.current ? root.current.label : ""
                    elide: Text.ElideMiddle
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                }

                Text {
                    id: counter

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: (list.currentIndex + 1) + " / " + root.items.length
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                }
            }
        }
    }
}
