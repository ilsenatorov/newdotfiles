# Dotfiles

## Installation

Arch or Manjaro, with a Wayland-capable GPU. One command does everything:

```sh
git clone https://github.com/ilsenatorov/newdotfiles ~/dotfiles
cd ~/dotfiles
./install.sh          # add --sddm to also theme the login screen
```

The repo **must** live at `~/dotfiles` -- link.sh, the scripts and the configs
themselves (rofi `-theme` paths, `ranger -r`, matugen output paths) all hardcode
it, and the installer refuses to run from anywhere else.

`install.sh` is idempotent; re-run it after every `git pull`. It:

1. installs the repo packages (see below) and, through whichever AUR helper is
   present (`yay`/`paru`/`trizen`/`pacaur`), **mpvpaper** -- the wallpaper daemon,
   the one hard AUR dependency -- plus optional `adw-gtk3`;
1. runs `link.sh`, which symlinks every top-level directory into `~/.config`;
   anything real in the way is moved to `<name>.bak-<timestamp>`, never deleted;
1. symlinks `~/.zshrc` (link.sh only walks directories, so it skips this one);
1. installs oh-my-zsh and clones `zsh-autosuggestions` / `zsh-syntax-highlighting`
   into `$ZSH_CUSTOM/plugins` -- `.zshrc` loads them as oh-my-zsh plugins, so the
   packaged `/usr/share` copies are not on the right path;
1. writes `~/.config/environment.d/10-locale.conf` (under UWSM only what the
   systemd user manager exports reaches apps started as scopes);
1. detects the GPU via `lspci` and writes `~/.config/environment.d/20-va.conf`
   (`LIBVA_DRIVER_NAME` plus `MPV_HWDEC`/`MPV_HWDEC_INTEROP` for the wallpaper
   daemon) -- skipped if that file already exists, so a hand edit sticks;
1. enables `hyprpolkitagent.service` as a user unit;
1. sets the wallpaper and derives the accent with matugen, if one is found.

Flags: `--no-packages` (links and theme only), `--no-aur`, `--minimal` (skips
ranger's preview tools), `--sddm` (installs the greeter theme, needs sudo).

### After it finishes

* **Edit `.zshrc`** -- it still carries a hardcoded `$ZSH=/home/ilya/.oh-my-zsh`
  and a conda block for `/home/ilya/miniconda3`. The installer warns about both.
* **Wallpaper**: not in git (too large). Drop an image or video into
  `~/Pictures/Wallpapers` and press `SUPER+W`, or run
  `hypr/scripts/set-wallpaper.sh <file>`. Until then the committed `colors.*`
  files keep the desktop themed.
* Log out and pick **"Hyprland (uwsm-managed)"** in the greeter. Every autostart
  in `hypr/hyprland.lua` goes through `uwsm app --`, so the session wants UWSM.
* Hardware video decode is auto-detected into `~/.config/environment.d/20-va.conf`
  (`LIBVA_DRIVER_NAME` + `MPV_HWDEC`/`MPV_HWDEC_INTEROP`); it is per-machine and
  not in git, so edit that file directly if the detection guesses wrong (e.g. an
  NVIDIA box with `nvidia-vaapi-driver` installed can go back to
  `LIBVA_DRIVER_NAME=nvidia` and `MPV_HWDEC=auto`).

Requires **Hyprland 0.56+** -- the config is `hypr/hyprland.lua`, not
`hyprland.conf`, and Lua configs are a recent feature. Tested on 0.56.2.

## Used packages

The authoritative list is the `PKGS_*` / `AUR_*` arrays in `install.sh`; this is
the why behind them.

* __rofi__ for launching software and the power menu (`SUPER+D`, `SUPER+SHIFT+S`)
* __hyprland__ as the compositor/WM, with __mpvpaper__ for the video wallpaper
* __alacritty__ as the terminal emulator
* __ranger__ as the file manager in terminal
* __quickshell__ for the bar, notifications, and the network/bluetooth/audio/
  calendar panels (`quickshell/`; SUPER+N/Y/M/G) -- replaces waybar, mako,
  networkmanager_dmenu, rofi-bluetooth and pavucontrol
* __matugen__ for wallpaper-derived accent colours
* __sddm__ as the display manager, with the pixel_sakura astronaut theme (see `sddm/`)
* __zsh__
* __starship__ as the zsh prompt (`starship/`), gruvbox-rainbow preset on a
  matugen palette -- replaces powerlevel10k

## Theming

The wallpaper is a looping video (`Disco-Elysium-4k.mp4`) played by **mpvpaper**
on the background layer -- hyprpaper is gone, since it only handles stills and
mpvpaper covers both. `hypr/wallpaper.conf` holds the current path;
`hypr/scripts/wallpaper-daemon.sh` starts the daemon at session login and after
every change.

One accent colour is derived from the wallpaper by **matugen** and pushed into
quickshell, rofi, hyprland, hyprlock, alacritty, starship and GTK. Change
wallpaper and
accent together with `SUPER+W` (or `hypr/scripts/set-wallpaper.sh`), which takes
images and videos alike -- for a video it pulls a frame with ffmpeg and themes
from that. Never edit the generated `colors.*` files, edit `matugen/templates/`
instead. Each config imports its generated file first and may override anything
below the import -- except starship, which is built rather than imported (see
below).

Backgrounds and foregrounds stay hand-written (`#141C21` / `#93A1A1`) so only
the accent moves with the wallpaper.

* The shell prompt is the one config that is **built** rather than imported,
  because starship's TOML has no include directive.
  `starship/starship.base.toml` is the hand-written prompt,
  `starship/colors.toml` is the matugen-generated `[palettes.dots]` table, and
  `starship/build.sh` concatenates the two into `starship/starship.toml` --
  which `.zshrc` points `STARSHIP_CONFIG` at, since it is not starship's
  default path. `set-wallpaper.sh` runs the build for you; run it by hand after
  editing the base. starship re-reads its config every prompt, so open shells
  recolour themselves. The layout is starship's gruvbox-rainbow preset with its
  gruvbox_dark palette replaced by matugen. That preset needs six visibly
  different segments, which a Material scheme cannot give: every role derives
  from one source hue, so primary/secondary/tertiary land within a few degrees
  of each other and the chain collapses into a flat band. The four coloured
  slots therefore come from `[config.custom_colors]` in `matugen/config.toml`
  with `blend = true` -- fixed seed hues harmonized toward the wallpaper, so the
  chain stays a real rainbow while still belonging to the palette. It replaces
  powerlevel10k; the instant prompt and the git segment's clean/dirty background
  swap have no starship equivalent, as noted at the top of the base file.
* GTK3/GTK4 are configured in `gtk-3.0/` and `gtk-4.0/`; libadwaita and the GTK
  portal only read gsettings, which `hypr/scripts/gsettings-theme.sh` sets at
  session start.
* The SDDM greeter follows the desktop wallpaper -- video included, the
  astronaut theme plays mp4/webm natively -- via `sudo sddm/sync-wallpaper.sh`
  (called automatically from `set-wallpaper.sh` when passwordless sudo is
  available, and from `sddm/install.sh`).

Optional packages that the configs pick up automatically if installed:
`adw-gtk3` (better GTK3 match for modern apps), `bibata-cursor-theme` (falls
back to Adwaita). `papirus-icon-theme` and `ttf-meslo-nerd` are required.
