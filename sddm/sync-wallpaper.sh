#!/usr/bin/env bash
# Point the installed SDDM theme at a static frame of the current desktop
# wallpaper and accent, so boot -> login -> desktop is one continuous look
# instead of three palettes. Always static -- see the note below on why.
#
#   sudo ./sync-wallpaper.sh              # use whatever hypr/wallpaper.conf says
#   sudo ./sync-wallpaper.sh <image>      # use that image
#
# Needs root: the theme lives in /usr/share/sddm/themes, outside $HOME. It is
# also called automatically at the end of hypr/scripts/set-wallpaper.sh, but ONLY
# when passwordless sudo is available -- a wallpaper change must never block on a
# password prompt that has no terminal to appear in.
#
# The repo's theme/Themes/main.conf stays the source of truth: this script edits
# the INSTALLED copy only, and is idempotent, so re-running install.sh resets it.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
DOTS="$(cd "$REPO/.." && pwd)"
# DST is overridable so the script can be exercised against a copy of the theme
# without touching /usr.
DST="${DST:-/usr/share/sddm/themes/sddm-astronaut-theme}"
CONF="$DST/Themes/main.conf"

[ -w "$DST" ] || [ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
[ -f "$CONF" ] || { echo "theme not installed; run sddm/install.sh first" >&2; exit 1; }

wall="${1:-$(grep -oP '^\s*WALLPAPER=\K.*' "$DOTS/hypr/wallpaper.conf" | head -1)}"
[ -f "$wall" ] || { echo "not a file: $wall" >&2; exit 1; }

# The greeter runs as the unprivileged "sddm" user and cannot traverse a 0700
# /home/<user>, so the image has to be copied inside the theme directory.
#
# The astronaut theme CAN play video/gif backgrounds natively (QtMultimedia /
# AnimatedImage), but that decode path segfaults sddm-greeter-qt6 inside
# libX11 on this machine's nvidia driver, especially right at boot while the
# driver is still settling -- it dropped the machine to a black screen / tty
# with no greeter at all. So SDDM always gets a static frame, regardless of
# what the desktop wallpaper is doing.
case "${wall,,}" in
    *.mp4|*.mkv|*.webm|*.mov|*.avi|*.m4v|*.gif)
        command -v ffmpeg >/dev/null || { echo "ffmpeg needed to extract a frame from $wall" >&2; exit 1; }
        tmp="$(mktemp --suffix=.png)"
        trap 'rm -f "$tmp"' EXIT
        ffmpeg -y -loglevel error -ss 3 -i "$wall" -frames:v 1 "$tmp" </dev/null >/dev/null 2>&1 \
            || ffmpeg -y -loglevel error -i "$wall" -frames:v 1 "$tmp" </dev/null >/dev/null 2>&1 \
            || { echo "ffmpeg could not read a frame from $(basename "$wall")" >&2; exit 1; }
        src="$tmp"
        ;;
    *)
        src="$wall"
        ;;
esac
ext="${src##*.}"
# Only copy when it actually differs, so a repeated wallpaper set does not
# rewrite /usr every time.
if ! cmp -s "$src" "$DST/Backgrounds/current.$ext"; then
    install -m 644 "$src" "$DST/Backgrounds/current.$ext"
fi
# Drop everything else: stale copies with another extension, and any leftover
# video/gif from older versions of this script that copied those through as-is.
# pixel_sakura.gif stays -- it is the theme's shipped fallback, but is never
# referenced once a static frame has been installed.
find "$DST/Backgrounds" -maxdepth 1 -type f \
    ! -name "current.$ext" ! -name 'pixel_sakura.gif' ! -name '.gitignore' -delete

# Accent: the same colour matugen just wrote for waybar.
accent=$(grep -oE '#[0-9a-fA-F]{6}' "$DOTS/waybar/colors.css" | head -1)
accent_dim=$(grep -oE '#[0-9a-fA-F]{6}' "$DOTS/waybar/colors.css" | sed -n 3p)

set_key() {  # set_key <Key> <value>
    sed -i "s|^$1=.*|$1=\"$2\"|" "$CONF"
}

set_key Background "Backgrounds/current.$ext"
set_key HeaderTextColor      "$accent"
set_key DateTextColor        "$accent"
set_key UserIconColor        "$accent"
set_key PasswordIconColor    "$accent"
set_key SystemButtonsIconsColor "$accent"
set_key SessionButtonTextColor  "$accent"
set_key VirtualKeyboardButtonTextColor "$accent"
set_key HighlightBorderColor "$accent"
set_key HighlightBackgroundColor "${accent_dim:-$accent}"
set_key LoginButtonBackgroundColor "${accent_dim:-$accent}"
# desktop base, so the login form matches waybar/hyprlock rather than the
# theme's stock Disco Elysium blues
set_key FormBackgroundColor  "#141C21"
set_key BackgroundColor      "#141C21"
set_key DimBackgroundColor   "#141C21"
set_key LoginFieldBackgroundColor    "#1E262B"
set_key PasswordFieldBackgroundColor "#1E262B"
set_key LoginFieldTextColor    "#93A1A1"
set_key PasswordFieldTextColor "#93A1A1"
set_key PlaceholderTextColor   "#6D8895"
set_key TimeTextColor          "#93A1A1"
set_key WarningColor           "#EC7875"
set_key Font                   "MesloLGS NF"
set_key RoundCorners           "12"

echo "sddm theme now uses $(basename "$wall") with accent $accent"
