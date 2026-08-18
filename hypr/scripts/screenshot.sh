#!/usr/bin/env bash
# Wayland screenshots for Hyprland. Replaces i3-scrot (Print) and i3/scrot.sh (Shift+Print).
# Saves to ~/Pictures like the i3 setup did, and also copies to the clipboard.
set -euo pipefail

DIR="${HOME}/Pictures"
NAME="${DIR}/screenshot-$(date +%Y%m%d-%H%M%S).png"
mkdir -p "$DIR"

case "${1:-full}" in
    region)
        # slurp returns non-zero if the selection is cancelled with Escape
        geom=$(slurp) || exit 0
        grim -g "$geom" "$NAME"
        ;;
    full)
        grim "$NAME"
        ;;
    *)
        echo "usage: $0 [full|region]" >&2
        exit 1
        ;;
esac

wl-copy < "$NAME"
notify-send "Screenshot saved" "$NAME"
