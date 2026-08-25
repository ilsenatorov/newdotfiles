pragma Singleton

import QtQuick
import Quickshell

// Hand-written half of the palette and all geometry. Mirrors waybar/style.css,
// mako/config and rofi/styles/base.rasi -- radius 12, #141C21 base, #93A1A1 text,
// Iosevka everywhere, no bold. Colors.qml holds the matugen-generated other half.
Singleton {
    readonly property string font: "Iosevka"

    // Type scale, in one place. This panel is 1920x1080 on a 340mm-wide screen
    // (~143 DPI), so anything under 14px is genuinely hard to read at a glance.
    readonly property int fsClock: 64
    readonly property int fsPill: 24
    readonly property int fsDate: 15
    readonly property int fsLabel: 14
    readonly property int fsValue: 15

    // The PanelWindow is fixed at cardW+inset*2 x cardH+inset*2. The inset is
    // headroom so the hover scale and the drop shadow have somewhere to bleed
    // without being clipped at the surface edge.
    readonly property int cardW: 420
    readonly property int cardH: 430
    // The now-playing row only exists while something is playing, so the card
    // grows by this much when it appears. The window is sized for the maximum.
    readonly property int npRow: 28
    readonly property int footerRow: 22
    readonly property int barRow: 22
    readonly property int pillW: 120
    readonly property int pillH: 44
    readonly property int inset: 12

    readonly property int radius: 12
    readonly property int pad: 22

    // QML hex is #AARRGGBB, not #RRGGBBAA. Lower than waybar's 0xD9 on purpose:
    // this is a big surface, so it can carry a real frosted-glass read where a
    // thin bar pill cannot. Hyprland blurs it via the quickshell-dashboard layer
    // rule in hypr/hyprland.lua -- keep this above that rule's ignore_alpha (0.2)
    // or the blur stops being applied at all.
    readonly property color surface: "#66141C21"
    readonly property color fg: "#93A1A1"
    readonly property color dim: "#6D8895"
    readonly property color rule: "#3C4449"
    readonly property color track: "#593C4449"
    readonly property color divider: "#803C4449"

    // Fixed semantics -- matugen never regenerates these, same values as waybar.
    readonly property color red: "#EC7875"
    readonly property color yellow: "#FDD835"

    // hyprland.lua's easeOutQuint bezier, in the 6-real form easing.bezierCurve wants.
    readonly property var easeOutQuint: [0.23, 1.0, 0.32, 1.0, 1.0, 1.0]

    readonly property int durFast: 140
    readonly property int durHover: 180
    readonly property int durFade: 220
    readonly property int durRow: 260
    readonly property int durExpand: 380
    readonly property int durBar: 450
    readonly property int durStagger: 40
}
