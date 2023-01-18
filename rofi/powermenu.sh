#!/usr/bin/env bash

dir="~/dotfiles/rofi"
uptime=$(uptime -p | sed -e 's/up //g')

rofi_command="rofi -theme ~/dotfiles/rofi/styles/powermenu.rasi"

# Options
shutdown="Shutdown"
reboot="Restart"
lock="Lock"
suspend="Sleep"
logout="Logout"

# Variable passed to rofi
options="$lock\n$suspend\n$logout\n$reboot\n$shutdown"

chosen="$(echo -e "$options" | $rofi_command -dmenu -selected-row 0)"
case $chosen in
    $shutdown)
		systemctl poweroff
		;;
    $reboot)
		systemctl reboot
		;;
    $lock)	
	    	rm /tmp/scrot.png
	    	scrot /tmp/scrot.png
		convert /tmp/scrot.png -blur 0x8 /tmp/scrot_resize.png
		i3lock -i /tmp/scrot_resize.png
		;;
    $suspend)
		mpc -q pause
		amixer set Master mute
		systemctl suspend
		;;
    $logout)
		i3-msg exit
		;;
esac
