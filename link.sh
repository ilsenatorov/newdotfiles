#!/bin/sh
# Symlink every top-level config dir in this repo into ~/.config.
#
# Unlike the original version this does NOT `rm -r` the destination: anything real that
# is in the way is moved aside to <name>.bak-<timestamp> first, and correct symlinks are
# left alone. That matters because ~/.config/hypr can hold a live config.

stamp=$(date +%Y%m%d-%H%M%S)

# Dirs that are not ~/.config configs. sddm's theme goes to /usr/share and /etc
# (see sddm/install.sh), and graphify-out is generated output.
skip="sddm graphify-out"

for i in */; do
	bas=$(basename "$i")

	case " $skip " in
		*" $bas "*) echo "SKIP    $bas"; continue ;;
	esac
	src="$HOME/dotfiles/$bas"
	dst="$HOME/.config/$bas"

	# already pointing where we want it
	if [ "$(readlink "$dst")" = "$src" ]; then
		echo "OK      $bas"
		continue
	fi

	# something real is in the way -- keep it
	if [ -e "$dst" ] || [ -L "$dst" ]; then
		echo "BACKUP  $bas -> $bas.bak-$stamp"
		mv "$dst" "$dst.bak-$stamp"
	fi

	echo "LINK    $bas"
	ln -s "$src" "$dst"
done

# Prune links this repo used to own but no longer does. Without this, removing a
# directory from the repo leaves a dangling ~/.config entry forever -- which is
# how conky, flashfocus, i3, picom, polybar and rofi-pass ended up broken.
for dst in "$HOME"/.config/*; do
	[ -L "$dst" ] || continue
	target=$(readlink "$dst")

	# only touch links that point into this repo
	case "$target" in
		"$HOME"/dotfiles/*) ;;
		*) continue ;;
	esac

	# ...and only those whose target is gone
	[ -e "$target" ] && continue

	echo "PRUNE   $(basename "$dst") (dangling -> $target)"
	rm "$dst"
done
