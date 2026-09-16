#!/bin/sh
# Symlink every top-level config dir in this repo into ~/.config.
#
# Unlike the original version this does NOT `rm -r` the destination: anything real that
# is in the way is moved aside to <name>.bak-<timestamp> first, and correct symlinks are
# left alone. That matters because ~/.config/hypr can hold a live config.
#
#   ./link.sh            link every dir (see below), prune dangling links
#   ./link.sh --unlink   remove every symlink this repo owns, restoring the
#                        newest .bak-* for each if one exists

# Dirs that are not ~/.config configs. sddm's theme goes to /usr/share and /etc
# (see sddm/install.sh), and graphify-out is generated output.
skip="sddm graphify-out"

# Restore the newest backup for $1 (a full path, e.g. ~/.config/hypr) if one
# exists, after $1 itself has been removed. Used by --unlink so backing out
# never leaves a machine with no config at all.
restore_backup() {
	target="$1"
	newest=$(ls -1dt "${target}".bak-* 2>/dev/null | head -1)
	if [ -n "$newest" ]; then
		echo "RESTORE $(basename "$target") <- $(basename "$newest")"
		mv "$newest" "$target"
	fi
}

if [ "$1" = "--unlink" ]; then
	for dst in "$HOME"/.config/*; do
		[ -L "$dst" ] || continue
		target=$(readlink "$dst")
		case "$target" in
			"$HOME"/dotfiles/*) ;;
			*) continue ;;
		esac
		echo "UNLINK  $(basename "$dst")"
		rm "$dst"
		restore_backup "$dst"
	done

	# .zshrc sits at the repo root; link.sh's own loop below only walks
	# directories, so install.sh symlinks it separately -- unlink it here too.
	if [ "$(readlink "$HOME/.zshrc" 2>/dev/null)" = "$HOME/dotfiles/.zshrc" ]; then
		echo "UNLINK  .zshrc"
		rm "$HOME/.zshrc"
		restore_backup "$HOME/.zshrc"
	fi

	exit 0
fi

stamp=$(date +%Y%m%d-%H%M%S)

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
