#!/usr/bin/env bash
# (Re)start the wallpaper daemon on whatever hypr/wallpaper.conf points at.
#
# mpvpaper replaced hyprpaper here because the wallpaper is a video
# (Disco-Elysium-4k.mp4) and hyprpaper only does still images. mpvpaper handles
# stills too -- an image is just a one-frame mpv playlist held open by
# image-display-duration=inf -- so it is the single wallpaper daemon for both,
# and hyprpaper is no longer started at all.
#
# Called at session start from hypr/hyprland.lua and again by set-wallpaper.sh.
# Idempotent: it kills any running instance first.
set -u

DOTS="${HOME}/dotfiles"
STATE="${DOTS}/hypr/wallpaper.conf"

WALLPAPER=""
# shellcheck source=/dev/null
[ -f "$STATE" ] && . "$STATE"

wall="${1:-$WALLPAPER}"
if [ ! -f "$wall" ]; then
    notify-send -u critical "Wallpaper" "Not a file: ${wall:-<unset>}" 2>/dev/null || true
    exit 1
fi

command -v mpvpaper >/dev/null || {
    notify-send -u critical "Wallpaper" "mpvpaper is not installed" 2>/dev/null || true
    exit 1
}

# mpv options, in mpvpaper's -o form (no leading dashes needed):
#   no-audio            the desktop must never make noise
#   loop-file=inf       seamless loop for video; harmless for stills
#   image-display-duration=inf  a still stays up instead of ending the file
#   hwdec=auto          VAAPI via iHD (see ~/.config/environment.d/20-va.conf).
#                       Without this a 4K clip decodes on the CPU permanently.
#   panscan=1.0         fill the output, crop the overflow -- hyprpaper's
#                       fit_mode = cover
#   video-sync=display-resample  no judder against the 60Hz panel
#   vo=libmpv           mpvpaper's own render path
#   input-ipc-server    lets you inspect the wallpaper without guessing, e.g.
#       echo '{"command":["get_property","pause"]}' | socat - "$XDG_RUNTIME_DIR/mpvpaper.sock"
OPTS="no-audio loop-file=inf image-display-duration=inf hwdec=auto panscan=1.0 video-sync=display-resample"
OPTS="$OPTS input-ipc-server=${XDG_RUNTIME_DIR:-/tmp}/mpvpaper.sock"

# -p (auto-pause) stops decoding whenever the wallpaper is hidden, and
# -a MAX extends that to any fullscreen or maximised window -- without it the
# video keeps decoding behind a fullscreen game. That pair is what keeps a
# looping video off the battery. -f forks so this script can return.
#
# '*' targets every output, so an external monitor is covered without a second
# invocation.
pkill -x mpvpaper 2>/dev/null || true
pkill -x hyprpaper 2>/dev/null || true   # legacy: no longer started, may linger
sleep 0.3

setsid uwsm app -- mpvpaper -f -p -a MAX -o "$OPTS" '*' "$wall" >/dev/null 2>&1 </dev/null &
disown 2>/dev/null || true

# confirm it came up; mpvpaper exits silently on an unreadable file
for _ in 1 2 3 4 5 6; do
    sleep 0.4
    pgrep -x mpvpaper >/dev/null && exit 0
done

notify-send -u critical "Wallpaper" \
    "mpvpaper did not stay up on $(basename "$wall")" 2>/dev/null || true
exit 1
