#!/usr/bin/env bash
# Full setup for this dotfiles repo on Arch / Manjaro.
#
#   ./install.sh                 packages + links + shell + theme
#   ./install.sh --no-packages   only links, shell and theme (no pacman/AUR)
#   ./install.sh --no-aur        skip the AUR step (mpvpaper -> no wallpaper daemon)
#   ./install.sh --sddm          also install the SDDM theme (needs sudo)
#   ./install.sh --minimal       core desktop only: no ranger previews, no extras
#
# Everything here is idempotent: re-running it is the supported way to pick up
# new packages after a `git pull`. It never deletes a config -- link.sh moves
# anything real out of the way to <name>.bak-<timestamp>.
set -euo pipefail

DOTS="${HOME}/dotfiles"
NO_PACKAGES=0; NO_AUR=0; WITH_SDDM=0; MINIMAL=0

for arg in "$@"; do
	case "$arg" in
		--no-packages) NO_PACKAGES=1 ;;
		--no-aur)      NO_AUR=1 ;;
		--sddm)        WITH_SDDM=1 ;;
		--minimal)     MINIMAL=1 ;;
		-h|--help)     sed -n '2,10p' "$0" | sed 's/^# \?//'; exit 0 ;;
		*)             echo "unknown option: $arg" >&2; exit 1 ;;
	esac
done

say()  { printf '\n\033[1;36m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33mWARN\033[0m %s\n' "$1" >&2; }
die()  { printf '\033[1;31mERROR\033[0m %s\n' "$1" >&2; exit 1; }

# ---------------------------------------------------------------- sanity ----
[ "$(id -u)" -ne 0 ] || die "run as your normal user, not root (it sudos where needed)"

# link.sh and every script in here hardcode ~/dotfiles, and so do the configs
# themselves (rofi -theme paths, ranger -r, matugen output paths). A clone
# somewhere else does not work without editing all of them.
repo="$(cd "$(dirname "$0")" && pwd)"
[ "$repo" = "$DOTS" ] || die "this repo must live at ${DOTS} (found: ${repo})"

command -v pacman >/dev/null || die "this installer is Arch/Manjaro only (no pacman)"

# ------------------------------------------------------------- packages ----
# Repo packages. Split so --minimal can drop the tail groups.
PKGS_DESKTOP=(
	# compositor + session
	hyprland uwsm hyprlock hypridle hyprsunset hyprshot hyprpolkitagent
	xdg-desktop-portal-hyprland xdg-desktop-portal-gtk polkit
	# bar, notifications, menus, dashboard
	waybar mako rofi networkmanager-dmenu quickshell
	# terminal, shell, prompt, files
	alacritty zsh starship ranger
	# theming
	matugen
	# clipboard + screenshots
	cliphist wl-clipboard wl-clip-persist grim slurp swappy
	# media / hardware keys
	mpv playerctl brightnessctl libpulse pavucontrol
	pipewire pipewire-pulse wireplumber
	# network + bluetooth
	networkmanager network-manager-applet bluez bluez-utils
	# used by the scripts
	git jq curl ffmpeg imagemagick libnotify fzf
	# fallback if hyprsunset is ever missing
	wlsunset
)
PKGS_FONTS=(
	ttf-meslo-nerd ttf-nerd-fonts-symbols-mono
	noto-fonts noto-fonts-emoji papirus-icon-theme bibata-cursor-theme
)
# ranger's scope.sh previews -- everything it shells out to.
PKGS_RANGER=(
	w3m highlight ffmpegthumbnailer mediainfo perl-image-exiftool
	atool 7zip unrar odt2txt transmission-cli elinks lynx
)
PKGS_SDDM=( sddm qt6-svg qt6-virtualkeyboard qt6-multimedia qt6-declarative )

# AUR. mpvpaper is the wallpaper daemon (stills and video); adw-gtk3 is optional
# polish the GTK config picks up on its own if present.
AUR_REQUIRED=( mpvpaper )
AUR_OPTIONAL=( adw-gtk3 )

if [ "$NO_PACKAGES" -eq 0 ]; then
	pkgs=( "${PKGS_DESKTOP[@]}" "${PKGS_FONTS[@]}" )
	[ "$MINIMAL" -eq 1 ] || pkgs+=( "${PKGS_RANGER[@]}" )
	[ "$WITH_SDDM" -eq 0 ] || pkgs+=( "${PKGS_SDDM[@]}" )

	say "installing ${#pkgs[@]} repo packages"
	sudo pacman -S --needed --noconfirm "${pkgs[@]}"

	if [ "$NO_AUR" -eq 0 ]; then
		helper=""
		for h in yay paru trizen pacaur; do
			command -v "$h" >/dev/null && { helper="$h"; break; }
		done
		if [ -n "$helper" ]; then
			say "installing AUR packages with $helper"
			"$helper" -S --needed --noconfirm "${AUR_REQUIRED[@]}" "${AUR_OPTIONAL[@]}" \
				|| warn "AUR install failed; mpvpaper is required for the wallpaper"
		else
			warn "no AUR helper found (yay/paru/trizen/pacaur)."
			warn "install manually, or the wallpaper daemon will not start:"
			warn "  ${AUR_REQUIRED[*]}  (optional: ${AUR_OPTIONAL[*]})"
		fi
	fi
fi

# ---------------------------------------------------------------- links ----
say "linking configs into ~/.config"
"${DOTS}/link.sh"

# .zshrc sits at the repo root, so link.sh (which only walks directories) does
# not touch it.
if [ "$(readlink "${HOME}/.zshrc" 2>/dev/null)" != "${DOTS}/.zshrc" ]; then
	if [ -e "${HOME}/.zshrc" ] || [ -L "${HOME}/.zshrc" ]; then
		bak="${HOME}/.zshrc.bak-$(date +%Y%m%d-%H%M%S)"
		echo "BACKUP  .zshrc -> $(basename "$bak")"
		mv "${HOME}/.zshrc" "$bak"
	fi
	echo "LINK    .zshrc"
	ln -s "${DOTS}/.zshrc" "${HOME}/.zshrc"
else
	echo "OK      .zshrc"
fi

# ------------------------------------------------------------------ zsh ----
# .zshrc sources oh-my-zsh and lists zsh-autosuggestions / zsh-syntax-highlighting
# as oh-my-zsh plugins, which means they have to be clones under $ZSH_CUSTOM --
# the /usr/share copies from the repo packages are not on oh-my-zsh's plugin path.
say "oh-my-zsh and plugins"
if [ ! -d "${HOME}/.oh-my-zsh" ]; then
	RUNZSH=no KEEP_ZSHRC=yes sh -c \
		"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
		|| die "oh-my-zsh install failed"
else
	echo "OK      oh-my-zsh"
fi

ZSH_CUSTOM="${HOME}/.oh-my-zsh/custom"
clone_plugin() {
	dst="${ZSH_CUSTOM}/plugins/$1"
	if [ -d "$dst" ]; then echo "OK      $1"; else
		echo "CLONE   $1"
		git clone --depth 1 "$2" "$dst"
	fi
}
clone_plugin zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions
clone_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting

# The .zshrc hardcodes /home/ilya paths for $ZSH and conda. Point them out rather
# than rewriting the file -- it is a tracked config, not generated.
if ! grep -q "ZSH=\"${HOME}/.oh-my-zsh\"" "${DOTS}/.zshrc"; then
	warn ".zshrc has a hardcoded \$ZSH path for another user -- edit it (line 1)"
fi
if grep -q '/home/ilya/miniconda3' "${DOTS}/.zshrc"; then
	warn ".zshrc still carries the conda block for /home/ilya/miniconda3 -- remove it if you have no conda"
fi

if [ "${SHELL##*/}" != "zsh" ]; then
	say "making zsh the login shell"
	chsh -s /usr/bin/zsh || warn "chsh failed; run 'chsh -s /usr/bin/zsh' yourself"
fi

# -------------------------------------------------------- session env ------
# Under UWSM only what the systemd user manager exports reaches apps started as
# scopes, so locale lives here rather than in hyprland.lua.
say "session environment"
mkdir -p "${HOME}/.config/environment.d"
if [ ! -f "${HOME}/.config/environment.d/10-locale.conf" ]; then
	cat > "${HOME}/.config/environment.d/10-locale.conf" <<'EOF'
# Force English UI messages for the whole systemd user session
LANG=en_US.UTF-8
LANGUAGE=en_US:en
LC_MESSAGES=en_US.UTF-8
EOF
	echo "WROTE   ~/.config/environment.d/10-locale.conf"
else
	echo "OK      ~/.config/environment.d/10-locale.conf"
fi

# GPU video decode is genuinely per-machine (this repo runs on both an
# NVIDIA-only desktop and an Intel/NVIDIA Optimus laptop), so it cannot live in
# a git-tracked config -- ~/.config/hypr is a symlink into this repo (see
# link.sh), so anything written there would sync verbatim to every machine.
# 20-va.conf lives in ~/.config/environment.d instead, is never overwritten
# once present (hand-edit it freely), and is read both by the systemd user
# environment (LIBVA_DRIVER_NAME, for VAAPI apps in general) and directly by
# hypr/scripts/wallpaper-daemon.sh (MPV_HWDEC / MPV_HWDEC_INTEROP).
if [ ! -f "${HOME}/.config/environment.d/20-va.conf" ]; then
	gpus="$(lspci -mm 2>/dev/null | grep -Ei 'VGA compatible controller|3D controller' || true)"

	if echo "$gpus" | grep -qi intel; then
		# Intel iGPU present: on a laptop (Optimus or not) it is what actually
		# drives the display, so VAAPI via iHD is correct even with an NVIDIA
		# dGPU alongside it for offload -- and forcing LIBVA_DRIVER_NAME=iHD
		# keeps VAAPI off that dGPU entirely.
		driver=iHD; hwdec=auto; interop=auto
	elif echo "$gpus" | grep -qi nvidia; then
		# NVIDIA and no Intel (this box): NVIDIA's bundled nvidia_drv_video.so
		# VAAPI shim SIGFPEs on vaInitialize, so route mpv straight through
		# NVDEC/CUDA and skip VAAPI for the wallpaper entirely. LIBVA_DRIVER_NAME
		# is deliberately left unset -- there's no known-good VAAPI driver here
		# to steer other apps to (nvidia-vaapi-driver would need to be
		# installed separately; not attempted by this script).
		driver=""; hwdec=nvdec; interop=cuda
	elif echo "$gpus" | grep -Eqi 'amd|ati|radeon'; then
		driver=radeonsi; hwdec=auto; interop=auto
	else
		driver=""; hwdec=auto; interop=auto
	fi

	{
		echo "# GPU video decode, detected at install time from:"
		echo "#   ${gpus:-<lspci found no VGA/3D controller>}"
		echo "# Not re-generated once this file exists -- edit freely, or delete"
		echo "# and re-run install.sh to redetect."
		[ -n "$driver" ] && echo "LIBVA_DRIVER_NAME=${driver}"
		echo "MPV_HWDEC=${hwdec}"
		echo "MPV_HWDEC_INTEROP=${interop}"
	} > "${HOME}/.config/environment.d/20-va.conf"
	echo "WROTE   ~/.config/environment.d/20-va.conf (hwdec=${hwdec} interop=${interop}${driver:+ driver=${driver}})"
else
	echo "OK      ~/.config/environment.d/20-va.conf"
fi

# ---------------------------------------------------------- user units ----
# hyprpolkitagent ships its own user unit (WantedBy=graphical-session.target);
# hyprland.lua deliberately does not exec it.
if [ -n "$(systemctl --user list-unit-files --no-legend hyprpolkitagent.service 2>/dev/null)" ]; then
	say "enabling hyprpolkitagent user unit"
	systemctl --user enable hyprpolkitagent.service >/dev/null 2>&1 \
		|| warn "could not enable hyprpolkitagent.service"
fi

# ---------------------------------------------------------- wallpaper ----
# The wallpaper itself is not in git (too large). Without one, mpvpaper has
# nothing to play and matugen has nothing to derive the accent from -- but the
# generated colors.* files are committed, so the desktop still comes up themed.
say "wallpaper and accent colour"
wall=""
[ -f "${DOTS}/hypr/wallpaper.conf" ] && \
	wall=$(sed -n 's/^WALLPAPER=//p' "${DOTS}/hypr/wallpaper.conf" | tail -1)

if [ -n "$wall" ] && [ -f "$wall" ]; then
	echo "OK      $wall"
elif [ -d "${HOME}/Pictures/Wallpapers" ] && \
     found=$(find "${HOME}/Pictures/Wallpapers" -type f \
		\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \
		   -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' \) | sort | head -1) && \
     [ -n "$found" ]; then
	echo "PICK    $found"
	"${DOTS}/hypr/scripts/set-wallpaper.sh" "$found" \
		|| warn "set-wallpaper.sh failed; run it by hand after login (SUPER+W)"
else
	warn "no wallpaper found. Put an image or video in ~/Pictures/Wallpapers and"
	warn "run: ~/dotfiles/hypr/scripts/set-wallpaper.sh <file>   (or SUPER+W)"
	warn "The committed colors.* files are used until then."
fi

# starship.toml is built, not imported -- rebuild in case only the base changed.
"${DOTS}/starship/build.sh" || warn "starship build failed"

# --------------------------------------------------------------- sddm ----
if [ "$WITH_SDDM" -eq 1 ]; then
	say "installing the SDDM astronaut theme (needs root)"
	sudo "${DOTS}/sddm/install.sh"
	sudo systemctl enable sddm.service || warn "could not enable sddm.service"
fi

# --------------------------------------------------------------- done ----
say "done"
cat <<EOF
Next:
  * log out and pick "Hyprland (uwsm-managed)" in the display manager
  * SUPER+D launcher, SUPER+W wallpaper+accent, SUPER+SHIFT+E exit menu
  * SDDM theme (optional):  ./install.sh --sddm
  * after a git pull:       ./install.sh   (idempotent)
EOF
