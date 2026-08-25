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
# GPU-specific mpv hwdec settings, generated per-machine by install.sh (see
# there for the detection logic) -- NOT tracked in git, since the right values
# differ between this box's NVIDIA-only desktop and an Intel/NVIDIA Optimus
# laptop. Defaults below are the safe choice if the file is missing.
GPUCONF="${HOME}/.config/environment.d/20-va.conf"

WALLPAPER=""
MPV_HWDEC="auto"
MPV_HWDEC_INTEROP="auto"
# shellcheck source=/dev/null
[ -f "$STATE" ] && . "$STATE"
# shellcheck source=/dev/null
[ -f "$GPUCONF" ] && . "$GPUCONF"

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
#   hwdec=$MPV_HWDEC             Hardware decode, picked per-machine by
#   gpu-hwdec-interop=$MPV_HWDEC_INTEROP  install.sh into 20-va.conf (see
#                       there and see GPUCONF above). Without hw decode a 4K
#                       clip decodes on the CPU permanently -- but the right
#                       backend is GPU-vendor-specific and picking the wrong
#                       one doesn't just fail slow, it can crash mpvpaper
#                       outright (e.g. NVIDIA's bundled nvidia_drv_video.so
#                       SIGFPEs inside vaInitialize when hwdec=auto probes
#                       VAAPI on an NVIDIA-only box -- mpvpaper dies silently
#                       and the wallpaper is just black; `coredumpctl info
#                       mpvpaper` shows it). "auto"/"auto" is the safe
#                       default when 20-va.conf hasn't set anything.
#   panscan=1.0         fill the output, crop the overflow -- hyprpaper's
#                       fit_mode = cover
#   video-sync=display-resample  no judder against the 60Hz panel
#   vo=libmpv           mpvpaper's own render path
#   input-ipc-server    lets you inspect the wallpaper without guessing, e.g.
#       echo '{"command":["get_property","pause"]}' | socat - "$XDG_RUNTIME_DIR/mpvpaper.sock"
OPTS="no-audio loop-file=inf image-display-duration=inf hwdec=${MPV_HWDEC} gpu-hwdec-interop=${MPV_HWDEC_INTEROP} panscan=1.0 video-sync=display-resample"
OPTS="$OPTS input-ipc-server=${XDG_RUNTIME_DIR:-/tmp}/mpvpaper.sock"

# -p (auto-pause) stops decoding whenever the wallpaper is hidden, which is what
# keeps a looping video off the battery. -f forks so this script can return.
#
# Deliberately NO -a MAX/-a FULL here. That flag extends auto-pause to *any*
# maximised or fullscreen toplevel, on any workspace, visible or not -- and
# mpvpaper only re-evaluates on toplevel state events, so once it pauses it
# never resumes on its own. One maximised window parked on another workspace
# (Telegram, here) left the wallpaper frozen at frame 1, and even a restart came
# up already paused because mpvpaper sees that window at startup. -p alone
# already handles the real case: a fullscreen window covering the wallpaper
# stops the frame callbacks, so decoding stops anyway.
#
# ALL targets every output, so an external monitor is covered without a second
# invocation. (mpvpaper does not accept '*' for this -- that matches no output
# and mpv exits immediately, leaving the screen black.)
pkill -x mpvpaper 2>/dev/null || true
pkill -x hyprpaper 2>/dev/null || true   # legacy: no longer started, may linger
sleep 0.3

setsid uwsm app -- mpvpaper -f -p -o "$OPTS" ALL "$wall" >/dev/null 2>&1 </dev/null &
disown 2>/dev/null || true

# confirm it came up; mpvpaper exits silently on an unreadable file
for _ in 1 2 3 4 5 6; do
    sleep 0.4
    pgrep -x mpvpaper >/dev/null && exit 0
done

notify-send -u critical "Wallpaper" \
    "mpvpaper did not stay up on $(basename "$wall")" 2>/dev/null || true
exit 1
