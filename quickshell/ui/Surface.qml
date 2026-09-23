import QtQuick
import QtQuick.Effects
import ".."

// The background every popup window draws: dropdown panels, menus, the
// dashboard, Ask. One component so fill, border and shadow cannot drift
// apart again -- change the look in Theme's `window*` tokens, not here.
//
// Place it *behind* the content (declare it first) and size it with anchors.
// It draws no children: the shadow is sourced from a hidden background only,
// never from the content, or the content renders twice (a shrunken ghost copy
// showing through the translucent fill).
Item {
    id: root

    Rectangle {
        id: bg

        anchors.fill: parent
        radius: Theme.radius
        color: Theme.windowSurface
        border.width: Theme.windowBorderW
        border.color: Theme.windowBorder
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        source: bg
        anchors.fill: bg
        shadowEnabled: true
        shadowColor: Theme.windowShadow
        shadowBlur: 0.7
        shadowVerticalOffset: 4
        shadowOpacity: 0.6
    }
}
