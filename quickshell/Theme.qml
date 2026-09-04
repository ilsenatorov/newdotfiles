pragma Singleton

import QtQuick
import Quickshell

// Hand-written half of the palette and all geometry. Mirrors rofi/styles/base.rasi
// and hyprlock.conf -- radius 12, #141C21 base, #93A1A1 text, MesloLGS NF
// everywhere, no bold. Colors.qml holds the matugen-generated other half.
// This shell is now the single source of truth for the bar and notification
// palette that waybar/style.css and mako/config used to own -- see the
// per-module color roles below, ported straight from waybar/style.css.
Singleton {
    readonly property string font: "MesloLGS NF"

    // Type scale, in one place. This panel is 1920x1080 on a 340mm-wide screen
    // (~143 DPI), so anything under 14px is genuinely hard to read at a glance.
    readonly property int fsClock: 64
    readonly property int fsDate: 15
    readonly property int fsLabel: 14
    readonly property int fsValue: 15

    // The dashboard PanelWindow (SUPER+G) is fixed at cardW+inset*2 x
    // cardH+inset*2 -- sized for its tallest state (GPU rows + now-playing +
    // top processes all present) so it never renegotiates layer-shell
    // geometry while open. The inset is headroom for the drop shadow.
    readonly property int cardW: 420
    readonly property int cardH: 720
    readonly property int footerRow: 22
    readonly property int barRow: 22
    readonly property int inset: 12

    readonly property int radius: 12
    readonly property int pad: 22

    // ---- bar ----------------------------------------------------------
    // Geometry ported from waybar/style.css/config.jsonc: three floating
    // pills, no fixed bar height, margin-top 6 / sides 8. hyprland.lua's
    // gaps_out (8) is tuned to this margin -- keep them matching.
    readonly property int barHeight: 40
    readonly property int barMarginTop: 6
    readonly property int barMarginSide: 8
    readonly property int barPillPadH: 16
    readonly property int barPillPadV: 6
    readonly property int barPillGap: 10
    readonly property int barModulePad: 6
    readonly property int fsBar: 16

    // #141C21 @ 85%, matches the old waybar pill exactly (QML hex is #AARRGGBB).
    readonly property color barPill: "#D9141C21"

    // ---- notifications --------------------------------------------------
    readonly property int notifWidth: 380
    readonly property int notifMinHeight: 76
    readonly property int notifMaxVisible: 5
    readonly property int notifMargin: 6
    readonly property int notifBorder: 2
    readonly property int notifIconSize: 48
    readonly property int notifDefaultTimeout: 6000
    readonly property int notifLowTimeout: 4000

    // ---- panels -----------------------------------------------------------
    readonly property int panelW: 340
    readonly property int panelGap: 8

    // ---- per-module bar colors, ported 1:1 from waybar/style.css ---------
    // Fixed semantics: matugen never touches these, same values the bar and
    // notifications have always used.
    readonly property color pink: "#EC407A"
    readonly property color purple: "#BA68C8"
    readonly property color blue: "#42A5F5"
    readonly property color cyan: "#4DD0E1"
    readonly property color teal: "#00B19F"
    readonly property color green: "#61C766"
    readonly property color orange: "#E57C46"
    readonly property color blueGray: "#6D8895"

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
