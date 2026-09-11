#!/usr/bin/env bash
# Set the wallpaper and regenerate the accent colour from it.
#
#   set-wallpaper.sh            -> rofi picker over ~/Pictures/Wallpapers
#   set-wallpaper.sh <file>     -> use that image or video directly
#
# Videos are first-class here: mpvpaper plays them (see wallpaper-daemon.sh) and
# matugen gets a frame pulled out with ffmpeg, so a video wallpaper drives the
# accent colour exactly like a still does.
#
# matugen writes ONLY the generated colors.* files (see matugen/config.toml).
# Backgrounds, foregrounds and fixed semantic colours stay hand-written in the
# real configs, which import the generated files and override them freely.
set -euo pipefail

DOTS="${HOME}/dotfiles"
WALLDIR="${HOME}/Pictures/Wallpapers"
STATE="${DOTS}/hypr/wallpaper.conf"
CACHE="${XDG_CACHE_HOME:-${HOME}/.cache}"
SCHEME="scheme-vibrant"
# matugen needs a tie-break when an image yields several candidate colours and
# there is no TTY to ask on; "saturation" keeps the accent punchy.
PREFER="saturation"

die() { notify-send -u critical "Wallpaper" "$1" 2>/dev/null || true; echo "$1" >&2; exit 1; }

is_video() {
    case "${1,,}" in
        *.mp4|*.mkv|*.webm|*.mov|*.avi|*.m4v|*.gif) return 0 ;;
        *) return 1 ;;
    esac
}

wall="${1:-}"

if [ -z "$wall" ]; then
    [ -d "$WALLDIR" ] || die "No wallpaper directory at $WALLDIR"
    mapfile -t files < <(find "$WALLDIR" -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \
           -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' -o -iname '*.mov' \
           -o -iname '*.m4v' -o -iname '*.gif' \) \
        | sort)
    [ "${#files[@]}" -gt 0 ] || die "No wallpapers in $WALLDIR"

    # Show each entry as its path RELATIVE to WALLDIR, not as a bare basename:
    # find recurses, so a basename is ambiguous the moment a wallpaper lives in
    # a subfolder -- "nature/forest.mp4" would come back as "forest.mp4" and the
    # path rebuilt below would not exist.
    #
    # A relative path is unique per file, so it maps straight back by
    # concatenation. Deliberately NOT using rofi's `-format i` to return a row
    # index: this box has rofi 2.0.0, a major version past the usual 1.7.x, and
    # a prompt that silently does nothing is far worse than one that cannot tell
    # a video from a still.
    choice=$(printf '%s\n' "${files[@]#"${WALLDIR}"/}" \
        | rofi -dmenu -i -p "Wallpaper" \
            -theme "${DOTS}/rofi/styles/launcher_scripts.rasi") || exit 0
    [ -n "$choice" ] || exit 0          # dismissed with Escape
    wall="${WALLDIR}/${choice}"
fi

[ -f "$wall" ] || die "Not a file: $wall"

# ---- 1. a still frame for matugen ----------------------------------------
# matugen only reads images, so a video wallpaper is sampled at 00:03 (past any
# fade-in from black, which would otherwise yield a grey accent).
src="$wall"
if is_video "$wall"; then
    command -v ffmpeg >/dev/null || die "ffmpeg is needed to theme from a video"
    src="${CACHE}/wallpaper-frame.png"
    ffmpeg -y -loglevel error -ss 3 -i "$wall" -frames:v 1 -vf 'scale=1280:-1' "$src" \
        </dev/null >/dev/null 2>&1 \
        || ffmpeg -y -loglevel error -i "$wall" -frames:v 1 -vf 'scale=1280:-1' "$src" \
            </dev/null >/dev/null 2>&1 \
        || die "ffmpeg could not read a frame from $(basename "$wall")"
fi

# ---- 2. colours ----------------------------------------------------------
matugen -c "${DOTS}/matugen/config.toml" image "$src" \
    -t "$SCHEME" --prefer "$PREFER" >/dev/null \
    || die "matugen failed on $(basename "$wall")"

# ---- 3. wallpaper --------------------------------------------------------
cat > "$STATE" <<STATEFILE
# Written by hypr/scripts/set-wallpaper.sh -- edit that, not this.
# Read by hypr/scripts/wallpaper-daemon.sh (mpvpaper) and sddm/sync-wallpaper.sh.
WALLPAPER=${wall}
STATEFILE

"${DOTS}/hypr/scripts/wallpaper-daemon.sh" "$wall" || echo "wallpaper daemon failed to start (non-fatal)" >&2

# ---- 4. tell everything to re-read its colours ---------------------------
# starship is the one config that is built rather than imported: its TOML has no
# include directive, so the generated palette has to be concatenated onto the
# hand-written base. starship re-reads its config on every prompt, so this
# recolours already-open shells with no restart -- same as kitty.
"${DOTS}/starship/build.sh" || echo "starship rebuild failed (non-fatal)" >&2

hyprctl reload >/dev/null 2>&1 || true
# No reload signal needed for the bar/notifications/panels any more --
# quickshell watches quickshell/Colors.qml itself and hot-reloads on write.
# kitty re-reads its config on save, so open terminals recolour themselves;
# rofi picks it up on next launch, hyprlock on next lock.
# GTK apps re-read gtk.css only on restart.

# ---- 5. login screen -----------------------------------------------------
# Keep SDDM on the same wallpaper and accent, so boot -> login -> desktop is one
# look -- including video wallpapers, which the astronaut theme plays natively.
# The theme lives in /usr/share, hence sudo -- and only the passwordless case,
# because a wallpaper change must not block on a password prompt with no
# terminal to show it in. Without passwordless sudo, run it by hand:
#   sudo ~/dotfiles/sddm/sync-wallpaper.sh
if [ -f /usr/share/sddm/themes/sddm-astronaut-theme/Themes/main.conf ]; then
    if sudo -n true 2>/dev/null; then
        sudo -n "${DOTS}/sddm/sync-wallpaper.sh" "$wall" >/dev/null 2>&1 \
            || echo "sddm sync failed (non-fatal)" >&2
    else
        echo "sddm not synced: needs 'sudo ${DOTS}/sddm/sync-wallpaper.sh'" >&2
    fi
fi

accent=$(grep -oE '#[0-9a-fA-F]{6}' "${DOTS}/quickshell/Colors.qml" | head -1)
notify-send "Wallpaper set" "$(basename "$wall")\nAccent ${accent}"
