#!/usr/bin/env bash
# Wayland screenshots for Hyprland. Replaces i3-scrot (Print) and i3/scrot.sh.
#
# Modes (see the Print binds in hypr/hyprland.lua):
#   full    whole output          -> file + clipboard
#   region  drag a rectangle      -> file + clipboard
#   window  click a window        -> file + clipboard   (needs hyprshot)
#   active  the focused window    -> file + clipboard   (needs hyprshot, no clicking)
#   clip    drag a rectangle      -> clipboard only, no file
#   edit    drag a rectangle      -> swappy for annotation
#
# hyprshot is used for `window` because picking a window beats guessing its
# rectangle; everything else stays on plain grim/slurp so the script keeps
# working with nothing but the base packages installed.
set -euo pipefail

DIR="${HOME}/Pictures/Screenshots"
NAME="${DIR}/screenshot-$(date +%Y%m%d-%H%M%S).png"

# wl-copy guesses the type from the byte stream otherwise, and some apps only
# accept a declared image/png target.
copy() { wl-copy -t image/png; }

need() {
    command -v "$1" >/dev/null && return 0
    notify-send "Screenshot: $1 not installed" "pacman -S $2"
    exit 1
}

case "${1:-full}" in
    full)
        mkdir -p "$DIR"
        grim "$NAME"
        copy < "$NAME"
        notify-send -i "$NAME" "Screenshot saved" "$NAME"
        ;;
    region)
        mkdir -p "$DIR"
        # slurp exits non-zero when the selection is cancelled with Escape
        geom=$(slurp) || exit 0
        grim -g "$geom" "$NAME"
        copy < "$NAME"
        notify-send -i "$NAME" "Screenshot saved" "$NAME"
        ;;
    window|active)
        need hyprshot hyprshot
        mkdir -p "$DIR"
        # hyprshot exits 1 even on success (it writes the file, then its cleanup
        # path returns nonzero), so `set -e` would abort here. Judge the result
        # by whether the file landed, not by the exit status.
        #
        # -z freezes the screen while picking so hover menus stay put; `active`
        # needs a second --mode naming what to grab, per `hyprshot --help`.
        if [ "$1" = "active" ]; then
            hyprshot -m active -m window -o "$DIR" -f "$(basename "$NAME")" || true
        else
            hyprshot -z -m window -o "$DIR" -f "$(basename "$NAME")" || true
        fi

        if [ ! -s "$NAME" ]; then
            notify-send -u critical "Screenshot failed" "hyprshot wrote nothing to $NAME"
            exit 1
        fi
        # hyprshot handles the clipboard and its own notification
        ;;
    clip)
        geom=$(slurp) || exit 0
        grim -g "$geom" - | copy
        notify-send "Screenshot copied" "Clipboard only -- nothing written to disk"
        ;;
    edit)
        need swappy swappy
        geom=$(slurp) || exit 0
        mkdir -p "$DIR"
        grim -g "$geom" - | swappy -f - -o "$NAME"
        ;;
    *)
        echo "usage: $0 [full|region|window|active|clip|edit]" >&2
        exit 1
        ;;
esac
