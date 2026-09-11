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
    // font: local.conf FONT is empty by default (MesloLGS NF everywhere); set
    // it to switch fonts on a machine without MesloLGS NF installed, the same
    // reasoning hyprland.lua's cursor_theme() probe uses for cursors.
    readonly property string font: Local.values["FONT"] || "MesloLGS NF"

    // Every geometry/font value below scales with local.conf's UI_SCALE
    // (default 1.0, unchanged from today) -- the "make it fit the small
    // screen" lever. A same-named local.conf key (BAR_HEIGHT, FONT_SIZE_BAR,
    // DASHBOARD_W/H) overrides its derived value outright instead of scaling
    // it, for a machine that needs one dimension tuned independently.
    readonly property real s: Local.uiScale

    // Type scale, in one place. At scale 1.0 this panel is 1920x1080 on a
    // 340mm-wide screen (~143 DPI), so anything under 14px is genuinely hard
    // to read at a glance -- a smaller/closer panel is exactly what UI_SCALE
    // is for.
    readonly property int fsClock: Math.round(64 * s)
    readonly property int fsDate: Math.round(15 * s)
    readonly property int fsLabel: Math.round(14 * s)
    readonly property int fsValue: Math.round(15 * s)

    // The dashboard PanelWindow (SUPER+G) is fixed at cardW+inset*2 x
    // cardH+inset*2 -- sized for its tallest state (GPU rows + now-playing +
    // top processes all present) so it never renegotiates layer-shell
    // geometry while open. The inset is headroom for the drop shadow.
    readonly property int cardW: Local.dashboardW > 0 ? Local.dashboardW : Math.round(420 * s)
    readonly property int cardH: Local.dashboardH > 0 ? Local.dashboardH : Math.round(720 * s)
    readonly property int footerRow: Math.round(22 * s)
    readonly property int barRow: Math.round(22 * s)
    readonly property int inset: Math.round(12 * s)

    readonly property int radius: 12
    readonly property int pad: Math.round(22 * s)

    // ---- bar ----------------------------------------------------------
    // Geometry ported from waybar/style.css/config.jsonc: three floating
    // pills, no fixed bar height, margin-top 6 / sides 8. hyprland.lua's
    // gaps_out (8) is tuned to this margin -- keep them matching (M.gaps_out
    // in local.lua overrides that side if this margin is scaled).
    readonly property int barHeight: Local.barHeight > 0 ? Local.barHeight : Math.round(40 * s)
    readonly property int barMarginTop: Math.round(6 * s)
    readonly property int barMarginSide: Math.round(8 * s)
    readonly property int barPillPadH: Math.round(16 * s)
    readonly property int barPillPadV: Math.round(6 * s)
    readonly property int barPillGap: Math.round(10 * s)
    readonly property int barModulePad: Math.round(6 * s)
    readonly property int fsBar: Local.fsBar > 0 ? Local.fsBar : Math.round(16 * s)

    // #141C21 @ 85%, matches the old waybar pill exactly (QML hex is #AARRGGBB).
    readonly property color barPill: "#D9141C21"

    // ---- notifications --------------------------------------------------
    readonly property int notifWidth: Math.round(380 * s)
    readonly property int notifMinHeight: Math.round(76 * s)
    readonly property int notifMaxVisible: 5
    readonly property int notifMargin: Math.round(6 * s)
    readonly property int notifBorder: 2
    readonly property int notifIconSize: Math.round(48 * s)
    readonly property int notifDefaultTimeout: 6000
    readonly property int notifLowTimeout: 4000

    // ---- panels -----------------------------------------------------------
    readonly property int panelW: Math.round(340 * s)
    readonly property int panelGap: Math.round(8 * s)

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

    // SUPER+G's dashboard specifically: it can pop up over arbitrary windows
    // (overlay layer, not just the desktop background), so the frosted-glass
    // `surface` above reads poorly over bright content. Solid instead.
    readonly property color dashboardSurface: "#F2141C21"
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
