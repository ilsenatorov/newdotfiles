#!/usr/bin/env bash
# Set the wallpaper and regenerate the accent colour from it.
#
#   set-wallpaper.sh            -> rofi picker over ~/Pictures/Wallpapers
#   set-wallpaper.sh <image>    -> use that image directly
#
# matugen writes ONLY the generated colors.* files (see matugen/config.toml).
# Backgrounds, foregrounds and fixed semantic colours stay hand-written in the
# real configs, which import the generated files and override them freely.
set -euo pipefail

DOTS="${HOME}/dotfiles"
WALLDIR="${HOME}/Pictures/Wallpapers"
SCHEME="scheme-vibrant"
# matugen needs a tie-break when an image yields several candidate colours and
# there is no TTY to ask on; "saturation" keeps the accent punchy.
PREFER="saturation"

die() { notify-send -u critical "Wallpaper" "$1"; echo "$1" >&2; exit 1; }

wall="${1:-}"

if [ -z "$wall" ]; then
    [ -d "$WALLDIR" ] || die "No wallpaper directory at $WALLDIR"
    mapfile -t files < <(find "$WALLDIR" -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        | sort)
    [ "${#files[@]}" -gt 0 ] || die "No images in $WALLDIR"

    # show basenames, map back to full paths afterwards
    choice=$(printf '%s\n' "${files[@]##*/}" \
        | rofi -dmenu -i -p "Wallpaper" \
            -theme "${DOTS}/rofi/styles/launcher_scripts.rasi") || exit 0
    [ -n "$choice" ] || exit 0
    wall="${WALLDIR}/${choice}"
fi

[ -f "$wall" ] || die "Not a file: $wall"

# ---- 1. colours ----------------------------------------------------------
matugen -c "${DOTS}/matugen/config.toml" image "$wall" \
    -t "$SCHEME" --prefer "$PREFER" >/dev/null \
    || die "matugen failed on $(basename "$wall")"

# ---- 2. wallpaper --------------------------------------------------------
cat > "${DOTS}/hypr/hyprpaper.conf" <<PAPER
# Written by hypr/scripts/set-wallpaper.sh -- edit that, not this.
wallpaper {
    monitor =
    path = ${wall}
    fit_mode = cover
}
splash = false
PAPER

# hyprpaper 0.8.4 exposes only `listactive` over IPC -- no preload/reload/unload
# (verified: they all return "invalid hyprpaper request"). So the only way to
# change wallpaper is to rewrite the config and restart the daemon.
#
# setsid + </dev/null detaches it, otherwise it dies with this script.
pkill -x hyprpaper 2>/dev/null || true
sleep 0.5
setsid uwsm app -- hyprpaper >/dev/null 2>&1 </dev/null &
disown 2>/dev/null || true

# confirm it actually came back up and took the new image
for _ in 1 2 3 4 5 6 7 8 9 10; do
    sleep 0.5
    active=$(hyprctl hyprpaper listactive 2>/dev/null | head -1)
    case "$active" in *"$wall") break ;; esac
done
case "${active:-}" in
    *"$wall") ;;
    *) notify-send -u critical "Wallpaper" \
         "hyprpaper did not load $(basename "$wall") -- is it a real JPEG/PNG?" ;;
esac

# ---- 3. tell everything to re-read its colours ---------------------------
hyprctl reload >/dev/null 2>&1 || true
pkill -SIGUSR2 -x waybar 2>/dev/null || true   # waybar reloads CSS on SIGUSR2
makoctl reload 2>/dev/null || true
# rofi and alacritty pick the new colours up on next launch; hyprlock on next lock.

accent=$(grep -oE '#[0-9a-fA-F]{6}' "${DOTS}/waybar/colors.css" | head -1)
notify-send "Wallpaper set" "$(basename "$wall")\nAccent ${accent}"
