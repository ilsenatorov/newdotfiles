#!/usr/bin/env bash
# Confirm before exiting Hyprland. Replaces i3-nagbar from the i3 config.
choice=$(printf 'Cancel\nExit Hyprland' | rofi -dmenu -i -p "Exit?" \
    -theme "${HOME}/dotfiles/rofi/styles/powermenu.rasi" -selected-row 0)

[ "$choice" = "Exit Hyprland" ] && hyprctl dispatch exit
exit 0
