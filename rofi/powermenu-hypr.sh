#!/usr/bin/env bash
# Hyprland/Wayland version of powermenu.sh.
# Same rofi theme and same option order, but the X11 bits are swapped out:
#   Lock   : scrot + convert -blur + i3lock  ->  hyprlock (blurs a live screenshot itself)
#   Logout : i3-msg exit                     ->  hyprctl dispatch exit
#   Sleep  : dropped `mpc -q pause` (mpc is not installed on this machine)
# The original powermenu.sh is left alone so the i3 session keeps working.

rofi_command="rofi -theme ${HOME}/dotfiles/rofi/styles/powermenu.rasi"

shutdown="Shutdown"
reboot="Restart"
lock="Lock"
suspend="Sleep"
logout="Logout"

options="$lock\n$suspend\n$logout\n$reboot\n$shutdown"

chosen="$(echo -e "$options" | $rofi_command -dmenu -selected-row 0)"
case $chosen in
    "$shutdown")
        systemctl poweroff
        ;;
    "$reboot")
        systemctl reboot
        ;;
    "$lock")
        # avoid stacking instances if the bind is hit twice
        pidof hyprlock || hyprlock
        ;;
    "$suspend")
        amixer set Master mute
        systemctl suspend
        ;;
    "$logout")
        hyprctl dispatch exit
        ;;
esac
