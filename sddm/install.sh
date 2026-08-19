#!/bin/sh
# Install the pixel_sakura variant of sddm-astronaut-theme from this repo.
# Needs root; everything it touches lives outside $HOME, so link.sh can't do this.
set -e

REPO="$(cd "$(dirname "$0")" && pwd)"
NAME=sddm-astronaut-theme
DST=/usr/share/sddm/themes/$NAME

# The background is no longer copied by this script: sync-wallpaper.sh does it,
# from whatever hypr/wallpaper.conf currently points at (the same file mpvpaper
# is playing on the desktop). Override for this run with:
#   WALLPAPER=/path/to.mp4 sudo -E ./install.sh

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

# Runtime deps. Main.qml pulls in QtSvg (Assets/*.svg), QtMultimedia and
# QtQuick.VirtualKeyboard, none of which ship with plain sddm.
if command -v pacman >/dev/null 2>&1; then
	pacman -S --needed --noconfirm sddm qt6-svg qt6-virtualkeyboard qt6-multimedia qt6-declarative noto-fonts
fi

# Wipe first: leftovers from a previous (full upstream) install would otherwise
# linger, and cp -r would not remove them.
rm -rf "$DST"
install -d "$DST"
cp -r "$REPO/theme/." "$DST/"

# The wallpaper is too large to keep in git, and the greeter runs as the
# unprivileged "sddm" user which cannot traverse a 0700 /home/<user> -- so it has
# to be copied inside $DST. sync-wallpaper.sh does that, and also pushes the
# current matugen accent into Themes/main.conf.
if ! "$REPO/sync-wallpaper.sh" ${WALLPAPER:+"$WALLPAPER"}; then
	echo "WARNING: wallpaper sync failed; falling back to pixel_sakura.gif" >&2
	sed -i 's|^Background=.*|Background="Backgrounds/pixel_sakura.gif"|' \
		"$DST/Themes/main.conf"
fi

# Font is resolved by family name ("Noto Serif Display" in main.conf), so it has
# to be a real system font -- the theme dir is not a font path. It ships in
# noto-fonts, installed above; refresh the cache in case that was a fresh install.
fc-cache -f >/dev/null

install -m 644 "$REPO/etc/sddm.conf" /etc/sddm.conf
install -d /etc/sddm.conf.d
install -m 644 "$REPO/etc/sddm.conf.d/virtualkbd.conf" /etc/sddm.conf.d/

echo "installed. preview with: sddm-greeter-qt6 --test-mode --theme $DST"
