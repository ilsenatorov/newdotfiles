#!/usr/bin/env bash
# (Re)start hyprpaper on whatever hypr/wallpaper.conf points at.
#
# Stills only. A video wallpaper (mpvpaper) used to live here; it kept the
# iGPU pinned at max clock and made the whole desktop sluggish with an external
# monitor attached, because every new frame also re-ran the blur behind every
# translucent surface. Not worth it.
#
# Called at session start from hypr/hyprland.lua and again by set-wallpaper.sh.
# Idempotent: it kills any running instance first.
set -u

DOTS="${HOME}/dotfiles"
STATE="${DOTS}/hypr/wallpaper.conf"
# Generated, so kept out of ~/.config/hypr -- that is a symlink into this repo.
CONF="${XDG_RUNTIME_DIR:-/tmp}/hyprpaper.conf"

# Read, not sourced: set-wallpaper.sh writes the path unquoted, so sourcing
# would split a path with spaces and run the tail as a command.
WALLPAPER=$(sed -n 's/^WALLPAPER=//p' "$STATE" 2>/dev/null | tail -1)

wall="${1:-$WALLPAPER}"
if [ ! -f "$wall" ]; then
	notify-send -u critical "Wallpaper" "Not a file: ${wall:-<unset>}" 2>/dev/null || true
	exit 1
fi

command -v hyprpaper >/dev/null || {
	notify-send "Wallpaper" "hyprpaper not installed -- skipping wallpaper daemon" 2>/dev/null || true
	exit 0
}

# Empty monitor = every output, so an external monitor needs no second block.
cat >"$CONF" <<PAPER
wallpaper {
    monitor =
    path = ${wall}
    fit_mode = cover
}
splash = false
PAPER

# hyprpaper 0.8.4 exposes only `listactive` over IPC -- no preload/reload/unload
# (they all return "invalid hyprpaper request") -- so changing the wallpaper
# means rewriting the config and restarting the daemon.
pkill -x mpvpaper 2>/dev/null || true # legacy: no longer started, may linger
pkill -x hyprpaper 2>/dev/null || true
sleep 0.3

setsid uwsm app -- hyprpaper -c "$CONF" >/dev/null 2>&1 </dev/null &
disown 2>/dev/null || true

# confirm it came up and took the new image
for _ in 1 2 3 4 5 6 7 8 9 10; do
	sleep 0.4
	case "$(hyprctl hyprpaper listactive 2>/dev/null)" in *"$wall"*) exit 0 ;; esac
done

notify-send -u critical "Wallpaper" \
	"hyprpaper did not load $(basename "$wall") -- is it a real JPEG/PNG/WebP?" 2>/dev/null || true
exit 1
