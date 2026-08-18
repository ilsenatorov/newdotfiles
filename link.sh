#!/bin/sh
# Symlink every top-level config dir in this repo into ~/.config.
#
# Unlike the original version this does NOT `rm -r` the destination: anything real that
# is in the way is moved aside to <name>.bak-<timestamp> first, and correct symlinks are
# left alone. That matters because ~/.config/hypr can hold a live config.

stamp=$(date +%Y%m%d-%H%M%S)

for i in */; do
	bas=$(basename "$i")
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
