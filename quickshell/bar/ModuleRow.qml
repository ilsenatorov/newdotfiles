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

    // The loaded module item for `name`, or null -- how Bar.qml finds where a
    // dropdown's droplet should hang from.
    function find(name: string): var {
        for (let i = 0; i < rep.count; i++) {
            if (root.names[i] === name) {
                const row = rep.itemAt(i);
                return row ? row.children[1].item : null;
            }
        }
        return null;
    }

    Repeater {
        id: rep
        model: root.names
        delegate: Row {
            spacing: root.spacing
            Sep { visible: index > 0 }
            Loader { sourceComponent: root.registry[modelData] }
        }
    }
}
