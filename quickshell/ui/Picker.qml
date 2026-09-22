import QtQuick
import Quickshell
import ".."

// The one search-and-pick card every ported rofi menu is built from --
// replaces `rofi -show drun` and every `rofi -dmenu` call this repo had
// (launcher, clipboard, wallpaper, power, exit, monitor output).
//
// rofi's themes did this job through rofi/styles/base.rasi: an inputbar, a
// listview, and a selected element with an accent left-border. That styling
// is reproduced here from Theme/Colors, so the menus look like they always
// did rather than like a new toolkit showed up.
//
// It owns *no data*: a caller hands it `items` and reacts to `accepted`.
// That is deliberate -- adding a launcher mode later (calculator, window
// switcher) means writing another model source, never touching this file.
// Filtering is likewise isolated in `filter()`, so swapping the rofi-style
// case-insensitive substring match (`rofi -i`) for a fuzzy/frecency ranker
// is a one-function change that no caller can notice.
Item {
    id: root

    // ---- in ----
    // Each item: { label, sublabel?, icon?, glyph?, key? }. `icon` is an XDG
    // icon name (the launcher's .desktop icons); `glyph` is a nerd-font
    // character, which is what the bar modules use and what a fixed menu of
    // known actions wants -- no icon theme to miss, no image to load.
    // `key` is the caller's
    // own handle (a DesktopEntry, a cliphist id, a path) -- passed straight
    // back on `accepted` and never interpreted here.
    property var items: []
    property string placeholder: ""
    property bool showIcons: false
    // false => a fixed set of choices (power, exit): no input box, and the
    // first row starts selected the way `rofi -selected-row 0` did.
    property bool searchable: true
    property int cardWidth: Theme.menuW
    // Shown in place of the list when there is nothing to pick. Callers that
    // shell out for their model (clipboard, wallpaper) override it so a
    // missing tool reads as an explanation instead of an empty card.
    property string emptyText: "No matches"

    // ---- out ----
    signal accepted(var item)
    signal closeRequested

    readonly property var filtered: root.filter(root.items, input.text)

    // rofi -i: case-insensitive substring, matched against the sublabel too
    // (that is what makes the wallpaper picker findable by subdirectory and
    // the launcher findable by a .desktop Comment).
    function filter(list: var, query: string): var {
        if (!list)
            return [];
        const q = query.trim().toLowerCase();
        if (q === "")
            return list;
        return list.filter(it => (String(it.label ?? "").toLowerCase().includes(q) || String(it.sublabel ?? "").toLowerCase().includes(q)));
    }

    function acceptCurrent(): void {
        const item = list.currentIndex >= 0 ? root.filtered[list.currentIndex] : null;
        if (item)
            root.accepted(item);
    }

    // Up/Down wrap, matching rofi's `cycle: true`. Shared by the input box
    // and, when there is no input box, by the card itself.
    function handleKey(event: var): void {
        const count = root.filtered.length;
        if (event.key === Qt.Key_Escape) {
            root.closeRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier))) {
            if (count > 0)
                list.currentIndex = (list.currentIndex + 1) % count;
            event.accepted = true;
        } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier))) {
            if (count > 0)
                list.currentIndex = (list.currentIndex - 1 + count) % count;
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.acceptCurrent();
            event.accepted = true;
        }
    }

    // Typing re-filters, so the old selection index means nothing -- go back
    // to the top hit, which is the row Enter should take.
    onFilteredChanged: list.currentIndex = root.filtered.length > 0 ? 0 : -1

    // The window is fixed at the widest/tallest a menu can be (see shell.qml)
    // so that typing never makes the layer-shell surface renegotiate its
    // size mid-keystroke. The card inside is what actually resizes, and this
    // fills the leftover space to catch a click-away dismiss.
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
        width: root.cardWidth
        // Bounded by the window (Theme.inset is shadow headroom), so a long
        // list scrolls instead of overflowing the layer-shell surface.
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
            spacing: 8

            Rectangle {
                id: inputBox

                visible: root.searchable
                height: root.searchable ? input.implicitHeight + 16 : 0
                width: col.width
                radius: Theme.radius / 2
                color: Theme.surface
                border.width: 1
                border.color: input.activeFocus ? Colors.accent : Theme.rule

                Text {
                    visible: input.text === ""
                    text: root.placeholder
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextInput {
                    id: input

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                    color: Theme.fg
                    clip: true

                    Keys.onPressed: event => root.handleKey(event)
                }
            }

            Text {
                visible: root.filtered.length === 0
                width: col.width
                text: root.emptyText
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fsValue
            }

            ListView {
                id: list

                width: col.width
                // Grow with the results, but never past the window: beyond
                // that the ListView scrolls, which is why this is a ListView
                // and not the Repeater-in-a-Column the bar panels use.
                //
                // Snapped down to a whole number of rows, so a capped list
                // ends on a row boundary instead of slicing one in half --
                // rofi did the same by counting `lines: 15` rather than pixels.
                readonly property int avail: root.height - Theme.inset * 2 - (root.searchable ? inputBox.height + col.spacing : 0) - Theme.pad
                height: Math.min(contentHeight, Math.max(1, Math.floor(avail / Theme.menuRowH)) * Theme.menuRowH)
                visible: root.filtered.length > 0
                clip: true
                model: root.filtered
                currentIndex: 0
                highlightMoveDuration: Theme.durFast
                boundsBehavior: Flickable.StopAtBounds
                // Keep the selected row on screen when arrowing past the edge.
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: height

                delegate: Rectangle {
                    id: row

                    required property int index
                    required property var modelData

                    width: list.width
                    height: Theme.menuRowH
                    radius: Theme.radius / 2
                    color: row.index === list.currentIndex ? Colors.surface : "transparent"

                    // base.rasi's `element selected` accent left-border.
                    Rectangle {
                        width: 3
                        height: parent.height - 8
                        radius: 2
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.accent
                        visible: row.index === list.currentIndex
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            id: glyph

                            visible: glyph.text !== ""
                            text: row.modelData.glyph ?? ""
                            width: glyph.visible ? Theme.menuIconSize : 0
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter
                            font.family: Theme.font
                            font.pixelSize: Theme.fsValue
                            color: row.index === list.currentIndex ? Colors.accent : Theme.dim
                        }

                        Image {
                            visible: root.showIcons
                            width: root.showIcons ? Theme.menuIconSize : 0
                            height: Theme.menuIconSize
                            anchors.verticalCenter: parent.verticalCenter
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            // iconPath(name, check) returns "" for a missing
                            // icon instead of warning, so a .desktop naming an
                            // icon this theme lacks degrades quietly.
                            source: root.showIcons ? Quickshell.iconPath(row.modelData.icon ?? "", true) : ""
                        }

                        Text {
                            width: parent.width - (root.showIcons ? Theme.menuIconSize + 8 : 0) - (glyph.visible ? glyph.width + 8 : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.sublabel ? row.modelData.label + "   " + row.modelData.sublabel : row.modelData.label
                            elide: Text.ElideRight
                            color: row.index === list.currentIndex ? Colors.accent : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fsValue
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            list.currentIndex = row.index;
                            root.acceptCurrent();
                        }
                    }
                }
            }
        }
    }

    // A Loader (shell.qml's menuLoader) can settle its FocusScope's focus
    // chain before this item exists, so `focus: true` alone loses the race --
    // the same kick panels/Ask.qml and panels/Network.qml already need.
    Component.onCompleted: {
        if (root.searchable)
            input.forceActiveFocus();
        else
            root.forceActiveFocus();
    }

    // Only reached when there is no input box to own the keys.
    focus: !root.searchable
    Keys.onPressed: event => root.handleKey(event)
}
