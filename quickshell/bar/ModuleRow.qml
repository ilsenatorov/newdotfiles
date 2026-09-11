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

    Repeater {
        model: root.names
        delegate: Row {
            spacing: root.spacing
            Sep { visible: index > 0 }
            Loader { sourceComponent: root.registry[modelData] }
        }
    }
}
