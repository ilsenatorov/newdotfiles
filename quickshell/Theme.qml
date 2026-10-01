pragma Singleton

import QtQuick
import Quickshell

// Colour roles and all geometry. Mirrors hyprlock.conf -- radius 12, MesloLGS
// NF everywhere, no bold. Every colour value comes from Colors.qml (generated
// by matugen): the wallpaper accent, plus the fixed base from matugen/base.json
// exposed below under its role names.
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
    // cardH+inset*2 -- sized for its tallest state (GPU rows + graph +
    // now-playing + top processes all present) so it never renegotiates layer-shell
    // geometry while open. The inset is headroom for the drop shadow.
    readonly property int cardW: Local.dashboardW > 0 ? Local.dashboardW : Math.round(500 * s)
    readonly property int cardH: Local.dashboardH > 0 ? Local.dashboardH : Math.round(980 * s)

    // SUPER+M i's ask-a-quick-question overlay. Fixed size like the dashboard,
    // sized to show a full back-and-forth conversation, not just one answer.
    readonly property int askW: Math.round(760 * s)
    readonly property int askH: Math.round(640 * s)
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
    readonly property int barPillPadH: Math.round(10 * s)
    readonly property int barPillPadV: Math.round(6 * s)
    readonly property int barPillGap: Math.round(6 * s)
    readonly property int barModulePad: Math.round(6 * s)
    readonly property int fsBar: Local.fsBar > 0 ? Local.fsBar : Math.round(16 * s)

    // Base @ 85%, matches the old waybar pill exactly.
    readonly property color barPill: Qt.alpha(Colors.baseBg, 0.85)

    // ---- notifications --------------------------------------------------
    readonly property int notifWidth: Math.round(380 * s)
    readonly property int notifMinHeight: Math.round(76 * s)
    readonly property int notifMaxVisible: 5
    readonly property int notifMargin: Math.round(6 * s)
    readonly property int notifBorder: 2
    readonly property int notifIconSize: Math.round(48 * s)
    readonly property int notifDefaultTimeout: 6000
    readonly property int notifLowTimeout: 4000

    // ---- menus ------------------------------------------------------------
    // The ported rofi menus (SUPER+D launcher, clipboard, wallpaper, power,
    // exit, monitor). rofi sized its window per-theme -- launcher.rasi was
    // 500px, powermenu.rasi 300px -- so the same split is kept here: a wide
    // card for searching long lists, a narrow one for a handful of fixed
    // choices. menuMaxH caps the list so a 400-app launcher cannot grow
    // taller than the screen; the ListView scrolls past it.
    readonly property int menuW: Math.round(560 * s)
    readonly property int menuNarrowW: Math.round(340 * s)
    readonly property int menuMaxH: Math.round(520 * s)
    readonly property int menuRowH: Math.round(38 * s)
    readonly property int menuIconSize: Math.round(26 * s)
    // One tile in the SUPER+M m monitor diagram (Left/Right/Above/Below
    // around the anchor). Wide and short, so a tile reads as a screen.
    readonly property int menuTileW: Math.round(104 * s)
    readonly property int menuTileH: Math.round(58 * s)

    // SUPER+M w's wallpaper carousel is the one menu that is not a list of
    // rows: it shows a 16:9 slide with its neighbours peeking in at the
    // edges, which does not fit menuW. The menu window widens for it (see
    // shell.qml) -- on open only, never mid-keystroke, so the "don't
    // renegotiate layer-shell geometry while typing" rule still holds.
    readonly property int menuWideW: Math.round(1200 * s)
    readonly property int menuWideH: Math.round(620 * s)
    readonly property int wallSlideW: Math.round(760 * s)
    readonly property int wallSlideH: Math.round(428 * s)
    // How far apart two slides sit. Well under a slide's width, so the
    // neighbours are overlapped by the current one rather than sitting
    // beside it -- a stack of wallpapers with the chosen one on top.
    readonly property int wallSlideStep: Math.round(460 * s)
    readonly property int wallSwatchH: Math.round(18 * s)

    // ---- panels -----------------------------------------------------------
    readonly property int panelW: Math.round(340 * s)
    readonly property int panelGap: Math.round(8 * s)

    // ---- per-module bar colors, ported 1:1 from waybar/style.css ---------
    // Fixed semantics from matugen/base.json: the wallpaper never moves these,
    // same values the bar and notifications have always used.
    readonly property color pink: Colors.baseRedBright
    readonly property color purple: Colors.baseMagenta
    readonly property color blue: Colors.baseBlue
    readonly property color cyan: Colors.baseCyan
    readonly property color teal: Colors.baseCyanBright
    readonly property color green: Colors.baseGreen
    readonly property color orange: Colors.baseOrange
    readonly property color blueGray: Colors.baseDim

    // Base @ 40% -- lower than the bar pill's 85% on purpose:
    // this is a big surface, so it can carry a real frosted-glass read where a
    // thin bar pill cannot. Hyprland blurs it via the quickshell-dashboard layer
    // rule in hypr/hyprland.lua -- keep this above that rule's ignore_alpha (0.2)
    // or the blur stops being applied at all.
    readonly property color surface: Qt.alpha(Colors.baseBg, 0.4)

    // Every popup window -- dropdown panels, menus, dashboard, Ask -- drawn
    // by ui/Surface.qml. They can pop up over arbitrary windows, so the
    // frosted-glass `surface` above reads poorly over bright content: nearly
    // solid instead. Hyprland still blurs the little that shows through (the
    // quickshell-* layer rules in hypr/hyprland.lua).
    readonly property color windowSurface: Qt.alpha(Colors.baseBg, 0.95)
    readonly property int windowBorderW: 1
    readonly property color windowBorder: rule
    readonly property color windowShadow: Colors.baseShadow
    readonly property color fg: Colors.baseFg
    readonly property color dim: Colors.baseDim
    readonly property color rule: Colors.baseBorder
    readonly property color track: Qt.alpha(Colors.baseBorder, 0.35)
    readonly property color divider: Qt.alpha(Colors.baseBorder, 0.5)

    // Fixed semantics from matugen/base.json, same values as waybar.
    readonly property color red: Colors.baseRed
    readonly property color yellow: Colors.baseYellow

    // hyprland.lua's easeOutQuint bezier, in the 6-real form easing.bezierCurve wants.
    readonly property var easeOutQuint: [0.23, 1.0, 0.32, 1.0, 1.0, 1.0]

    readonly property int durFast: 140
    readonly property int durHover: 180
    readonly property int durFade: 220
    readonly property int durRow: 260
    readonly property int durExpand: 380
    readonly property int durBar: 450
    readonly property int durStagger: 40
    // ui/Panel.qml's droplet: long enough to read as liquid, not a flicker.
    readonly property int durMorphIn: 620
    readonly property int durMorphOut: 300
}
