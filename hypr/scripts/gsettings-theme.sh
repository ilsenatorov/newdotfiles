#!/usr/bin/env bash
# Push the GTK look onto the gsettings channel.
#
# Why this exists: under Wayland there is no XSettings daemon, and libadwaita
# (GTK4) plus xdg-desktop-portal-gtk read org.gnome.desktop.interface rather
# than gtk-4.0/settings.ini. Without this, GTK4 apps and portal file dialogs
# stay light even though the ini files say dark. GTK3 apps read the ini
# directly, so they are already correct -- these keys just keep the two stores
# from disagreeing.
#
# Idempotent; run at every session start from hypr/hyprland.lua.
set -u

command -v gsettings >/dev/null 2>&1 || exit 0

# first theme in the list that is actually installed wins
pick() {
    for name in "$@"; do
        if [ -d "/usr/share/$SUBDIR/$name" ] \
           || [ -d "$HOME/.local/share/$SUBDIR/$name" ] \
           || [ -d "$HOME/.icons/$name" ]; then
            echo "$name"; return
        fi
    done
    echo "$1"   # nothing found: fall back to the first candidate
}

SUBDIR=themes
# adw-gtk3-dark is the better match for modern apps but is not in the base
# install; Adwaita-dark always exists.
GTK_THEME=$(pick adw-gtk3-dark Adwaita-dark)

SUBDIR=icons
ICON_THEME=$(pick Papirus-Dark Papirus Adwaita)
# Bibata is the intended cursor (see hypr/hyprland.lua, which sets the matching
# XCURSOR_THEME); Adwaita is the always-present fallback.
CURSOR_THEME=$(pick Bibata-Modern-Ice Bibata-Modern-Classic Adwaita)

set -- \
    color-scheme          "prefer-dark" \
    gtk-theme             "$GTK_THEME" \
    icon-theme            "$ICON_THEME" \
    cursor-theme          "$CURSOR_THEME" \
    cursor-size           "24" \
    font-name             "Cantarell 11" \
    monospace-font-name   "MesloLGS NF 11" \
    font-antialiasing     "grayscale" \
    font-hinting          "slight"

while [ "$#" -gt 0 ]; do
    gsettings set org.gnome.desktop.interface "$1" "$2" 2>/dev/null || true
    shift 2
done

# Apply to the running compositor too, so the cursor changes without a relogin.
# (hl.env in hyprland.lua only affects clients started after it.)
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl setcursor "$CURSOR_THEME" 24 >/dev/null 2>&1 || true
fi
