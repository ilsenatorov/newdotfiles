# Dotfiles

## Installation

1. clone the repository with `git clone https://github.com/ilsenatorov/newdotfiles ~/dotfiles`
1. cd into repo with `cd ~/dotfiles`
1. link all the necessary folders with `./link.sh`
1. edit the .zshrc
1. enjoy!

## Used packages

* __rofi__ for launching software
* __rofi pass__ for password managing
* __networkmanager_dmenu__ for connection managing
* __rofi-bluetooth__ for bluetooth managing
* __waybar__ as the status bar
* __hyprland__ as the compositor/WM, with __mpvpaper__ for the video wallpaper
* __alacritty__ as the terminal emulator
* __ranger__ as the file manager in terminal
* __mako__ for notifications, __rofi__ menus for power/bluetooth/network
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
waybar, rofi, mako, hyprland, hyprlock, alacritty, starship and GTK. Change
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
back to Adwaita). `papirus-icon-theme` and `ttf-iosevka-nerd` are required.
