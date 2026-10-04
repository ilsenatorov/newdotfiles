import QtQuick
import ".."
import "../ui"

// A module list with a Sep before every entry but the first -- same visual
// rhythm the old hardcoded Bar.qml had (a divider between distinct modules),
// without local.conf having to spell separators out itself. `registry` maps
// a module name to the Component to load; Bar.qml owns both.
Row {
    id: root

    required property var names
    required property var registry
    spacing: Theme.barPillGap

    // Names the registry doesn't know (a stale local.conf listing a retired
    // module) are dropped rather than leaving an empty slot behind a Sep.
    readonly property var known: names.filter(n => registry[n] !== undefined)

    // The loaded module item for `name`, or null -- how Bar.qml finds where a
    // dropdown's droplet should hang from.
    function find(name: string): var {
        for (let i = 0; i < rep.count; i++) {
            if (root.known[i] === name) {
                const row = rep.itemAt(i);
                return row ? row.children[1].item : null;
            }
        }
        return null;
    }

    Repeater {
        id: rep
        model: root.known
        // A module can hide itself (media with no player, status with
        // nothing to report) by declaring `shown`; the whole entry goes then,
        // its divider too, so the pill never shows a dangling Sep. Not
        // `visible`: that reads false for any child of a hidden Row, so the
        // entry could never come back.
        delegate: Row {
            spacing: root.spacing
            visible: loader.item && loader.item.shown !== undefined ? loader.item.shown : true
            Sep { visible: index > 0 }
            Loader { id: loader; sourceComponent: root.registry[modelData] }
        }
    }
}
