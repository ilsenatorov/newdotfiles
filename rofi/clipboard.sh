#!/usr/bin/env bash
# cliphist history through the same rofi theme as the app launcher.
# Bound to SUPER+V in hypr/hyprland.lua.
set -euo pipefail

if ! command -v cliphist >/dev/null; then
    notify-send "Clipboard history unavailable" "Install cliphist: pacman -S cliphist"
    exit 1
fi

# `cliphist decode` needs the numeric id, which is the leading field of the line.
cliphist list \
    | rofi -dmenu -i -p "Clipboard" \
        -theme "${HOME}/dotfiles/rofi/styles/launcher_scripts.rasi" \
    | cliphist decode \
    | wl-copy
