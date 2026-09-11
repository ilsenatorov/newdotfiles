#!/usr/bin/env bash
# Full setup for this dotfiles repo on Arch / Manjaro.
#
#   ./install.sh                 packages + links + shell + theme
#   ./install.sh --no-packages   only links, shell and theme (no pacman/AUR)
#   ./install.sh --no-aur        skip the AUR step (mpvpaper -> no wallpaper daemon)
#   ./install.sh --sddm          also install the SDDM theme (needs sudo)
#   ./install.sh --minimal       core desktop only: no ranger previews, no extras
#   ./install.sh --reconfigure   redo hardware detection: back up and rewrite
#                                 ~/.config/dotfiles/{local.conf,local.lua} and
#                                 ~/.zshrc.local from fresh probes
#
# Everything here is idempotent: re-running it is the supported way to pick up
# new packages after a `git pull`. It never deletes a config -- link.sh moves
# anything real out of the way to <name>.bak-<timestamp>, and this script does
# the same for --reconfigure.
set -euo pipefail

DOTS="${HOME}/dotfiles"
NO_PACKAGES=0; NO_AUR=0; WITH_SDDM=0; MINIMAL=0; RECONFIGURE=0

for arg in "$@"; do
	case "$arg" in
		--no-packages) NO_PACKAGES=1 ;;
		--no-aur)      NO_AUR=1 ;;
		--sddm)        WITH_SDDM=1 ;;
		--minimal)     MINIMAL=1 ;;
		--reconfigure) RECONFIGURE=1 ;;
		-h|--help)     sed -n '2,13p' "$0" | sed 's/^# \?//'; exit 0 ;;
		*)             echo "unknown option: $arg" >&2; exit 1 ;;
	esac
done

stamp="$(date +%Y%m%d-%H%M%S)"
# Write $2 to file $1 unless it already exists, UNLESS --reconfigure was
# passed, in which case the existing file (if any) is backed up first. Used
# for every per-machine file this script generates: local.conf, local.lua,
# ~/.zshrc.local. Mirrors 20-va.conf's "detect once, never overwrite" contract.
write_local() {
	dst="$1"; content="$2"
	if [ -f "$dst" ]; then
		if [ "$RECONFIGURE" -eq 1 ]; then
			bak="${dst}.bak-${stamp}"
			echo "BACKUP  $(basename "$dst") -> $(basename "$bak")"
			cp "$dst" "$bak"
		else
			echo "OK      $(basename "$dst")"
			return 0
		fi
	fi
	printf '%s' "$content" > "$dst"
	echo "WROTE   $dst"
}

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
	# bar, notifications, menus, dashboard -- bar+notifications+panels are
	# quickshell now (see quickshell/), rofi stays for the app launcher and
	# power menu
	rofi quickshell
	# terminal, shell, prompt, files
	kitty zsh starship ranger
	# theming
	matugen
	# clipboard + screenshots
	cliphist wl-clipboard wl-clip-persist grim slurp swappy
	# media / hardware keys -- pavucontrol dropped, the quickshell Audio
	# panel (SUPER+M) replaces its default-sink slider
	mpv playerctl brightnessctl libpulse
	pipewire pipewire-pulse wireplumber
	# network + bluetooth -- network-manager-applet dropped, the bar's
	# network module + Network panel (SUPER+N) replace it
	networkmanager bluez bluez-utils
	# used by the scripts -- qrencode is the Network panel's Wi-Fi share QR
	git jq curl ffmpeg imagemagick libnotify fzf qrencode
	# fallback if hyprsunset is ever missing
	wlsunset
)
PKGS_FONTS=(
	ttf-meslo-nerd ttf-nerd-fonts-symbols-mono
	noto-fonts noto-fonts-emoji papirus-icon-theme bibata-cursor-theme
)
# ranger's scope.sh previews -- everything it shells out to. Image previews
# themselves need no package here: kitty decodes them itself (see ranger/rc.conf).
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

# ~/.zshrc.local: per-machine env/aliases that .zshrc's last line sources.
# Prefilled from an NVIDIA probe (the Wayland/VS Code workaround only applies
# there); never overwritten after that except with --reconfigure.
say "per-machine shell tail (~/.zshrc.local)"
zshrc_local_content="# Per-machine zsh tail, sourced from the end of ~/dotfiles/.zshrc. Generated
# once by install.sh, never overwritten after that -- hand-edit freely.

export CLAUDE_OBSIDIAN_VAULT=\"\$HOME/Documents/MyKnowledgeVault\"
"
if lspci -mm 2>/dev/null | grep -Eqi 'VGA compatible controller|3D controller' && \
   lspci -mm 2>/dev/null | grep -Ei 'VGA compatible controller|3D controller' | grep -qi nvidia; then
	zshrc_local_content="${zshrc_local_content}
# VS Code: native Wayland backend segfaults on this NVIDIA setup; force XWayland
alias code=\"code --ozone-platform=x11\"
"
fi
zshrc_local_content="${zshrc_local_content}
[ -r \"\$HOME/.local/bin/env\" ] && . \"\$HOME/.local/bin/env\"
"
write_local "${HOME}/.zshrc.local" "$zshrc_local_content"

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

# ------------------------------------------------------- local config ----
# Everything that would be WRONG if copied verbatim to another PC: UI scale,
# which bar modules run, which pollers are worth their cost, monitor rules,
# workspace pinning, keyboard layout. ~/.config/dotfiles/ is not a directory
# link.sh manages, so it can never become a symlink into this repo -- same
# reasoning as 20-va.conf above, generalised. local.conf (flat KEY=value) is
# read by shell scripts and quickshell/Local.qml; local.lua (a Lua table) is
# read by hypr/hyprland.lua for the knobs that are structured and
# Hyprland-only. Prefilled from cheap hardware probes below; edit either
# freely afterwards, or redo detection with --reconfigure.
say "per-machine desktop config (~/.config/dotfiles)"
mkdir -p "${HOME}/.config/dotfiles"

mem_kb=$(awk '/MemTotal/ { print $2 }' /proc/meminfo 2>/dev/null || echo 0)
ncores=$(nproc 2>/dev/null || echo 1)
weak=0
# ~4GB / 2 cores is this repo's own "small" box -- see hypr/hyprland.lua and
# quickshell/Theme.qml comments for what UI_SCALE actually changes.
[ "$mem_kb" -lt 6000000 ] 2>/dev/null && weak=1
[ "$ncores" -le 2 ] 2>/dev/null && weak=1

gpus_lc="$(lspci -mm 2>/dev/null | grep -Ei 'VGA compatible controller|3D controller' || true)"
has_nvidia=0; echo "$gpus_lc" | grep -qi nvidia && has_nvidia=1
has_battery=0; [ -d /sys/class/power_supply ] && \
	ls /sys/class/power_supply 2>/dev/null | grep -qi '^BAT' && has_battery=1

ui_scale=1.0; svc_weather=1; svc_claude=1; interval_fast=2000; interval_slow=10000
bar_center="gpu,sys,battery"
if [ "$weak" -eq 1 ]; then
	ui_scale=0.8; svc_weather=0; svc_claude=0
	interval_fast=4000; interval_slow=20000
fi
[ "$has_nvidia" -eq 1 ] || bar_center=$(echo "$bar_center" | sed 's/gpu,\?//')
[ "$has_battery" -eq 1 ] || bar_center=$(echo "$bar_center" | sed 's/,\?battery//')

local_conf_content="# Per-machine overrides -- read by shell scripts and quickshell/Local.qml.
# See hypr/hyprland.lua's per-machine block and hypr/local.lua (if present)
# for the monitor/workspace/keyboard knobs, which are structured and live
# there instead. Generated once by install.sh from hardware probes
# (mem=${mem_kb}kB cores=${ncores} nvidia=${has_nvidia} battery=${has_battery});
# never overwritten after that except with --reconfigure. Blank/absent = the
# hardcoded default in Theme.qml / SysMon.qml / etc stands.

# --- UI scale ---------------------------------------------------------
UI_SCALE=${ui_scale}
BAR_HEIGHT=
FONT_SIZE_BAR=
DASHBOARD_W=
DASHBOARD_H=
FONT=

# --- bar modules --------------------------------------------------------
# Comma-separated; a module not listed is dropped. Empty = that pill hidden.
BAR_LEFT=workspaces,submap,clock
BAR_CENTER=${bar_center}
BAR_RIGHT=network,bluetooth,audio,language

# --- services -------------------------------------------------------------
# Expensive pollers. 0 disables the poller outright, not just the widget.
SVC_WEATHER=${svc_weather}
SVC_CLAUDE_USAGE=${svc_claude}
SVC_GPU=${has_nvidia}
SYSMON_INTERVAL_FAST=${interval_fast}
SYSMON_INTERVAL_SLOW=${interval_slow}

# --- theme / wallpaper ------------------------------------------------
# Seeds hypr/wallpaper.conf on first run if set; otherwise the first image
# found in ~/Pictures/Wallpapers is used (see the wallpaper step below).
WALLPAPER=
"
write_local "${HOME}/.config/dotfiles/local.conf" "$local_conf_content"

# Detected outputs, offered as commented-out examples -- hyprctl usually isn't
# running yet during a fresh install (no session up), so this falls back to
# the DRM connector list. jq (a PKGS_DESKTOP package) is required for the
# hyprctl path -- monitors -j nests other "name" keys (workspaces, etc.) that
# a plain grep would also match.
if command -v hyprctl >/dev/null && command -v jq >/dev/null && \
   outs=$(hyprctl monitors -j 2>/dev/null) && [ -n "$outs" ]; then
	conns=$(echo "$outs" | jq -r '.[].name' 2>/dev/null)
else
	conns=$(for f in /sys/class/drm/*/status; do
		[ "$(cat "$f" 2>/dev/null)" = "connected" ] || continue
		basename "$(dirname "$f")" | sed 's#^card[0-9]*-##'
	done 2>/dev/null)
fi

local_lua_content="-- Per-machine overrides for hypr/hyprland.lua -- monitors, workspace
-- pinning, keyboard layout, optional autostarts. See local.conf (sibling
-- file) for everything else. Generated once by install.sh; never overwritten
-- after that except with --reconfigure. Both blocks below are commented out,
-- so hyprland.lua's generic defaults (eDP-1 + catch-all monitor, workspaces
-- 1-5 -> eDP-1, kb_layout us,ru) stand until you fill one in.
--
-- Detected outputs at install time:$(for c in $conns; do printf '\n--   %s' "$c"; done)

return {
    monitors = {
        -- { output = \"DP-1\", mode = \"preferred\", position = \"auto\", scale = 1 },
        -- { output = \"\",     mode = \"preferred\", position = \"auto\", scale = 1 }, -- catch-all
    },

    -- { first_workspace, last_workspace, monitor }. monitor can be a
    -- connector (\"DP-1\") or, more stable across replugs, \"desc:<hyprctl
    -- monitors description>\".
    -- workspaces = {
    --     { 1, 5,  \"eDP-1\" },
    --     { 6, 10, \"desc:Dell Inc. DELL P2422H F4JL9D3\" },
    -- },

    -- kb_layout = \"us,ru\",

    -- gaps_out = 8,  -- keep matching Theme.barMarginSide if UI_SCALE changes it

    autostart = {
        -- hypridle = true,  -- idle timeouts / auto-lock (off everywhere by default)
    },
}
"
write_local "${HOME}/.config/dotfiles/local.lua" "$local_lua_content"

# Fresh clone: seed the generated theme files from their committed snapshot so
# the desktop is themed before the wallpaper step below (or SUPER+W) ever
# runs matugen. Never overwrites a file that already exists -- those are this
# machine's actual last-set theme, not stale defaults.
say "generated theme defaults"
while IFS= read -r -d '' src; do
	rel="${src#"${DOTS}/matugen/defaults/"}"
	dst="${DOTS}/${rel}"
	if [ -f "$dst" ]; then
		echo "OK      $rel"
	else
		mkdir -p "$(dirname "$dst")"
		cp "$src" "$dst"
		echo "SEEDED  $rel"
	fi
done < <(find "${DOTS}/matugen/defaults" -type f -print0)

# ---------------------------------------------------------- user units ----
# hyprpolkitagent ships its own user unit (WantedBy=graphical-session.target);
# hyprland.lua deliberately does not exec it.
if [ -n "$(systemctl --user list-unit-files --no-legend hyprpolkitagent.service 2>/dev/null)" ]; then
	say "enabling hyprpolkitagent user unit"
	systemctl --user enable hyprpolkitagent.service >/dev/null 2>&1 \
		|| warn "could not enable hyprpolkitagent.service"
fi

# ---------------------------------------------------------- wallpaper ----
# The wallpaper itself is not in git (too large), and neither is
# hypr/wallpaper.conf any more (it's machine state, see .gitignore) -- but the
# generated colors.* files were just seeded from matugen/defaults/ above, so
# the desktop comes up themed either way.
say "wallpaper and accent colour"
wall=""
[ -f "${DOTS}/hypr/wallpaper.conf" ] && \
	wall=$(sed -n 's/^WALLPAPER=//p' "${DOTS}/hypr/wallpaper.conf" | tail -1)
[ -z "$wall" ] && [ -f "${HOME}/.config/dotfiles/local.conf" ] && \
	wall=$(sed -n 's/^WALLPAPER=//p' "${HOME}/.config/dotfiles/local.conf" | tail -1)

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
