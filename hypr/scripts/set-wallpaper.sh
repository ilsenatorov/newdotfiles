#!/usr/bin/env bash
# Set the wallpaper and regenerate the accent colour from it.
#
#   set-wallpaper.sh <file>          -> use that image or video directly
#   set-wallpaper.sh --set <rel>     -> path relative to ~/Pictures/Wallpapers
#   set-wallpaper.sh --list          -> print the wallpapers, one per line
#   set-wallpaper.sh --palette <rel> -> print a thumbnail path + its palette
#
# Picking one interactively is quickshell's job now (SUPER+W ->
# quickshell/panels/Wallpaper.qml); this script no longer prompts. --list is
# what that picker reads, so the set of wallpaper extensions below stays in
# one place instead of being duplicated in QML. --palette is what draws the
# colourbar under each slide: the picker shows the real scheme a wallpaper
# would produce, not an approximation of it, because it asks matugen the same
# question --set does -- same config, same -t, same --prefer.
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
# Per-wallpaper, so browsing the picker cannot clobber what --set is using.
FRAMEDIR="${CACHE}/wallpaper-frames"
PALDIR="${CACHE}/wallpaper-palettes"
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

# A stable filename for anything cached about one wallpaper. The absolute
# path is hashed rather than slugified: a path can contain anything, a hash
# cannot, and two wallpapers with the same basename stay apart.
cache_key() { printf '%s' "$1" | sha1sum | cut -d' ' -f1; }

# A path that can be read as an image: a still is itself, a video is a frame
# pulled out with ffmpeg at 00:03 (past any fade-in from black, which would
# otherwise yield a grey accent). Used both to feed matugen and as the
# picker's thumbnail, which is why video frames are kept rather than
# overwritten -- the picker shows several at once.
#
# Prints the path; returns non-zero (silently) if there is no getting one,
# so --palette can skip a wallpaper instead of dying on the whole listing.
still_frame() {
    local wall="$1" out
    if ! is_video "$wall"; then
        printf '%s\n' "$wall"
        return 0
    fi
    command -v ffmpeg >/dev/null || return 1
    out="${FRAMEDIR}/$(cache_key "$wall").png"
    mkdir -p "$FRAMEDIR"
    if [ ! -s "$out" ] || [ "$wall" -nt "$out" ]; then
        ffmpeg -y -loglevel error -ss 3 -i "$wall" -frames:v 1 -vf 'scale=1280:-1' "$out" \
            </dev/null >/dev/null 2>&1 \
            || ffmpeg -y -loglevel error -i "$wall" -frames:v 1 -vf 'scale=1280:-1' "$out" \
                </dev/null >/dev/null 2>&1 \
            || return 1
    fi
    printf '%s\n' "$out"
}

# The colourbar under a slide, as the picker wants it: line 1 is a thumbnail
# path, then one hex per line. The keys are exactly the ones
# matugen/templates/colors-quickshell.qml fills in, in bar order, so what the
# picker draws is what Colors.qml ends up holding.
#
# matugen takes ~0.4s per image, so the answer is cached and only recomputed
# when the wallpaper itself is newer than the cache entry.
palette_keys=(primary tertiary rainbow_red rainbow_orange rainbow_green rainbow_cyan rainbow_blue rainbow_purple)

print_palette() {
    local wall="$1" cache src json filter
    cache="${PALDIR}/$(cache_key "$wall")"
    if [ -s "$cache" ] && [ ! "$wall" -nt "$cache" ]; then
        cat "$cache"
        return 0
    fi
    src=$(still_frame "$wall") || return 1
    json=$(matugen -c "${DOTS}/matugen/config.toml" --dry-run -q -j hex \
        image "$src" -t "$SCHEME" --prefer "$PREFER" 2>/dev/null) || return 1
    # .dark.color, not .hex: that is the json shape, while the templates use
    # their own {{...hex}} spelling for the same value.
    filter=$(printf '.colors.%s.dark.color, ' "${palette_keys[@]}")
    mkdir -p "$PALDIR"
    {
        printf '%s\n' "$src"
        printf '%s' "$json" | jq -er "${filter%, }"
    } > "${cache}.tmp" || { rm -f "${cache}.tmp"; return 1; }
    # Renamed into place so a killed run cannot leave a half-written palette
    # that the next open would happily read back.
    mv -f "${cache}.tmp" "$cache"
    cat "$cache"
}

# Recursive on purpose, and each entry is printed RELATIVE to WALLDIR: find
# descends, so a bare basename is ambiguous the moment a wallpaper lives in a
# subfolder -- "nature/forest.mp4" would come back as "forest.mp4" and the
# path rebuilt from it would not exist. A relative path is unique per file and
# maps straight back by concatenation.
list_wallpapers() {
    [ -d "$WALLDIR" ] || die "No wallpaper directory at $WALLDIR"
    local files=()
    mapfile -t files < <(find "$WALLDIR" -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \
           -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' -o -iname '*.mov' \
           -o -iname '*.m4v' -o -iname '*.gif' \) \
        | sort)
    [ "${#files[@]}" -gt 0 ] || die "No wallpapers in $WALLDIR"
    printf '%s\n' "${files[@]#"${WALLDIR}"/}"
}

case "${1:-}" in
    --list)
        list_wallpapers
        exit 0
        ;;
    --palette)
        [ -n "${2:-}" ] || die "--palette needs a path relative to $WALLDIR"
        print_palette "${WALLDIR}/${2}" || exit 1
        exit 0
        ;;
    --set)
        [ -n "${2:-}" ] || die "--set needs a path relative to $WALLDIR"
        wall="${WALLDIR}/${2}"
        ;;
    "")
        # No interactive fallback any more -- failing loudly beats silently
        # doing nothing if something still calls this the old way.
        die "Usage: set-wallpaper.sh <file> | --set <rel> | --list | --palette <rel>"
        ;;
    *)
        wall="$1"
        ;;
esac

[ -f "$wall" ] || die "Not a file: $wall"

# ---- 1. a still frame for matugen ----------------------------------------
# matugen only reads images; still_frame() is what makes a video wallpaper
# theme exactly like a still does, and the picker draws its thumbnail from
# the same cached frame.
src=$(still_frame "$wall") \
    || die "could not get a still frame from $(basename "$wall") (ffmpeg missing?)"

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
# hyprlock picks it up on next lock.
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
