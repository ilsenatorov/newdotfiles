import QtQuick
import ".."

// Open/close motion for every popup window: the bar dropdowns, the menus,
// the dashboard and Ask. One component so the overlays move as one family
// -- change the feel here, not per window.
//
// It lives in the window permanently and wraps that window's Loader. The
// window binds `visible` to `live` (not to its own open flag), so on close
// the surface stays mapped until the exit motion finishes, and the Loader
// binds `active` to `live` so the content is still there to animate out.
// Hyprland's own layer animation is off for these namespaces (no_anim in
// hypr/hyprland.lua) -- two animations on one surface fight each other.
//
// Styles:
//   "drop" -- unfolds from the bar: scales up from `transformOrigin` while
//             sliding down a few pixels. For the dropdown panels.
//   "pop"  -- scales up from the centre with a slight overshoot, like
//             hyprland.lua's `popin` windows. For the centred overlays.
//   "morph" -- no motion of its own: `progress` runs linearly in time and
//             the content shapes itself from it (ui/Panel.qml's droplet).
Item {
    id: root

    property bool shown: false
    property string style: "pop"

    // 0 = fully closed, 1 = fully open. Everything visual derives from it,
    // so opening and closing are the same motion run with different curves.
    property real progress: shown ? 1 : 0

    readonly property bool live: shown || progress > 0

    Behavior on progress {
        NumberAnimation {
            duration: root.style === "morph" ? (root.shown ? Theme.durMorphIn : Theme.durMorphOut)
                : root.shown ? (root.style === "drop" ? Theme.durRow : Theme.durFade) : Theme.durFast
            easing.type: root.style === "morph" ? Easing.Linear
                : root.shown && root.style === "pop" ? Easing.OutBack : Easing.BezierSpline
            easing.overshoot: 1.2
            easing.bezierCurve: root.shown ? Theme.easeOutQuint : [0.4, 0.0, 1.0, 1.0, 1.0, 1.0]
        }
    }

    // Opacity reaches full well before the motion ends. Hyprland only blurs
    // pixels above the layer rule's ignore_alpha (0.2), so a slow fade shows
    // the blur snapping on halfway through; a fast one hides that inside
    // the first few frames.
    opacity: style === "morph" ? 1 : Math.min(1, Math.max(0, progress * 2.5))

    scale: style === "morph" ? 1 : (style === "drop" ? 0.95 : 0.94) + (style === "drop" ? 0.05 : 0.06) * progress

    transform: Translate {
        y: root.style === "drop" ? -10 * (1 - root.progress) : 0
    }
}
