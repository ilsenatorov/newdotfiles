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
    property bool deletable: false
    // false => a fixed set of choices (power, exit): no input box, and the
    // first row starts selected the way `rofi -selected-row 0` did.
    property bool searchable: true
    property int cardWidth: Theme.menuW
    // Shown in place of the list when there is nothing to pick. Callers that
    // shell out for their model (clipboard, wallpaper) override it so a
    // missing tool reads as an explanation instead of an empty card.
    property string emptyText: "No matches"
    // Replaces filter() below when set: function(items, query) -> items. The
    // SUPER+D search uses it for ranking and its `=`/`?` prefix modes.
    property var filterFn: null
    // Query to start with (applied once, on creation) -- how the search
    // gets its text back when Esc returns to it from a page it opened.
    property string initialQuery: ""
    property int initialIndex: 0
    property alias currentIndex: list.currentIndex
    // >= 0: hang the card this far from the window's top instead of
    // centring it, so the input box stays put while the results grow and
    // shrink under it (the SUPER+D search, lined up with the hub's pill).
    property real topPin: -1
    // Room the card may use: the window minus shadow headroom (and the pin).
    readonly property real cardRoom: root.topPin >= 0 ? root.height - root.topPin - Theme.inset : root.height - Theme.inset * 2

    // ---- out ----
    signal accepted(var item)
    signal deleteRequested(var item)
    signal closeRequested
    // The user typed (not emitted for initialQuery).
    signal queryEdited(string text)

    readonly property var filtered: root.filterFn ? root.filterFn(root.items, input.text) : root.filter(root.items, input.text)

    // True for the opening moment only -- the window a delegate has to be
    // created in to play the row cascade. Long enough to cover items that
    // arrive a beat late from a Process (cliphist), short enough that the
    // first keystroke's re-filter never replays it.
    property bool intro: true
    Timer {
        running: true
        interval: 250
        onTriggered: root.intro = false
    }

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

    // Replace the query from outside (shell.qml's `menu search` IPC when the
    // search is already open). Counts as typing: the cursor goes to the top.
    function setQuery(text: string): void {
        input.text = text;
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
        // Esc is left unaccepted: it falls through to shell.qml's menu
        // window, which closes the menu -- or, for a page opened from the
        // SUPER+D hub, steps back to the hub.
        if (event.key === Qt.Key_Escape) {
            // A typed query is the innermost layer: Esc clears it first,
            // and only an empty box lets Esc close / step back.
            if (root.searchable && input.text !== "") {
                input.text = "";
                event.accepted = true;
            }
            return;
        } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier))) {
            if (count > 0)
                list.currentIndex = (list.currentIndex + 1) % count;
            event.accepted = true;
        } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier))) {
            if (count > 0)
                list.currentIndex = (list.currentIndex - 1 + count) % count;
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete && root.deletable) {
            const item = root.filtered[list.currentIndex];
            if (item) root.deleteRequested(item);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.acceptCurrent();
            event.accepted = true;
        }
    }

    // Typing re-filters, so the old selection index means nothing -- go back
    // to the top hit, which is the row Enter should take. Only on a query
    // change, though: when the items themselves update (a live status line,
    // a toggle flipped in place) the cursor stays where it was.
    function queryChanged(): void {
        list.currentIndex = root.filtered.length > 0 ? 0 : -1;
        if (!root.applyingInitial)
            root.queryEdited(input.text);
    }
    onFilteredChanged: {
        const n = root.filtered.length;
        if (list.currentIndex >= n) list.currentIndex = n - 1;
        else if (list.currentIndex < 0 && n > 0) list.currentIndex = 0;
    }
    property bool applyingInitial: false

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

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: root.topPin >= 0 ? undefined : parent.verticalCenter
        anchors.top: root.topPin >= 0 ? parent.top : undefined
        anchors.topMargin: Math.max(0, root.topPin)
        width: root.cardWidth
        // Bounded by the window (Theme.inset is shadow headroom), so a long
        // list scrolls instead of overflowing the layer-shell surface.
        height: Math.min(col.implicitHeight + Theme.pad, root.cardRoom)

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
                    onTextChanged: root.queryChanged()
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
                readonly property int avail: root.cardRoom - (root.searchable ? inputBox.height + col.spacing : 0) - Theme.pad
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

                    // Rows present while the menu is still opening cascade
                    // in behind ui/Reveal.qml's pop; rows created later by
                    // typing or scrolling just appear.
                    transform: Translate { id: rowShift }
                    Component.onCompleted: {
                        if (root.intro && row.index < 10)
                            rowIn.start();
                    }

                    SequentialAnimation {
                        id: rowIn

                        ScriptAction {
                            script: {
                                row.opacity = 0;
                                rowShift.y = 6;
                            }
                        }
                        PauseAnimation { duration: row.index * 18 }
                        ParallelAnimation {
                            NumberAnimation {
                                target: row
                                property: "opacity"
                                to: 1
                                duration: Theme.durRow
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.easeOutQuint
                            }
                            NumberAnimation {
                                target: rowShift
                                property: "y"
                                to: 0
                                duration: Theme.durRow
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.easeOutQuint
                            }
                        }
                    }

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
                        anchors.rightMargin: root.deletable ? 40 : 10
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
                            id: rowIcon
                            // Rows without an icon (glyph rows mixed into
                            // the launcher's app list) take no icon slot.
                            visible: root.showIcons && !!row.modelData.icon
                            width: rowIcon.visible ? Theme.menuIconSize : 0
                            height: Theme.menuIconSize
                            anchors.verticalCenter: parent.verticalCenter
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            // iconPath(name, check) returns "" for a missing
                            // icon instead of warning, so a .desktop naming an
                            // icon this theme lacks degrades quietly.
                            source: rowIcon.visible ? Quickshell.iconPath(row.modelData.icon, true) : ""
                        }

                        Text {
                            width: parent.width - (rowIcon.visible ? Theme.menuIconSize + 8 : 0) - (glyph.visible ? glyph.width + 8 : 0)
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

                    Text {
                        visible: root.deletable
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: parent.height
                        text: "×"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.red
                        font.pixelSize: Theme.fsValue

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.deleteRequested(row.modelData)
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
        // Read both first: setting the text moves the cursor, and a caller
        // that binds initialIndex to where the cursor is would see it reset.
        const q = root.initialQuery;
        const idx = root.initialIndex;
        if (q !== "") {
            root.applyingInitial = true;
            input.text = q;
            root.applyingInitial = false;
        }
        if (idx > 0)
            list.currentIndex = Math.min(idx, root.filtered.length - 1);
        if (root.searchable)
            input.forceActiveFocus();
        else
            root.forceActiveFocus();
    }

    // Only reached when there is no input box to own the keys.
    focus: !root.searchable
    Keys.onPressed: event => root.handleKey(event)
}
