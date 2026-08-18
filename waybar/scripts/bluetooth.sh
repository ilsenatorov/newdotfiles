#!/usr/bin/env bash
# Waybar version of ../polybar/scripts/bluetooth.sh.
# Same rofi-bluetooth --status source, but emits waybar JSON instead of polybar %{F#...} markup.
# The polybar original is left untouched so the i3 setup keeps working.
#
# rofi-bluetooth --status returns:
#   ""            -> bluetooth powered off
#   "\uF293"      -> powered on, nothing connected
#   "\uF293;NAME" -> connected to NAME

ICON_OFF=$'\uF294'
ICON_ON=$'\uF293'

STATUS=$("${HOME}/dotfiles/rofi-bluetooth/rofi-bluetooth" --status 2>/dev/null)

if [ -z "$STATUS" ]; then
    printf '{"text":"%s","class":"off","tooltip":"Bluetooth off"}\n' "$ICON_OFF"
elif [ "$STATUS" = "$ICON_ON" ]; then
    printf '{"text":"%s","class":"on","tooltip":"Bluetooth on"}\n' "$ICON_ON"
else
    device="${STATUS#*;}"
    printf '{"text":"%s %s","class":"connected","tooltip":"Connected: %s"}\n' \
        "$ICON_ON" "$device" "$device"
fi
