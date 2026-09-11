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
1. writes `~/.config/dotfiles/{local.conf,local.lua}` and `~/.zshrc.local`
   from hardware probes, and seeds the generated `colors.*` theme files from
   `matugen/defaults/` -- see **Per-machine config** below. Also skipped if
   already present, unless `--reconfigure` is passed;
1. enables `hyprpolkitagent.service` as a user unit;
1. sets the wallpaper and derives the accent with matugen, if one is found.

Flags: `--no-packages` (links and theme only), `--no-aur`, `--minimal` (skips
ranger's preview tools), `--sddm` (installs the greeter theme, needs sudo),
`--reconfigure` (redo hardware detection: backs up and rewrites `local.conf`,
`local.lua` and `~/.zshrc.local`).

### After it finishes

* **Wallpaper**: not in git (too large). Drop an image or video into
  `~/Pictures/Wallpapers` and press `SUPER+W`, or run
  `hypr/scripts/set-wallpaper.sh <file>`. Until then the theme files seeded
  from `matugen/defaults/` keep the desktop themed.
* Log out and pick **"Hyprland (uwsm-managed)"** in the greeter. Every autostart
  in `hypr/hyprland.lua` goes through `uwsm app --`, so the session wants UWSM.
* Hardware video decode is auto-detected into `~/.config/environment.d/20-va.conf`
  (`LIBVA_DRIVER_NAME` + `MPV_HWDEC`/`MPV_HWDEC_INTEROP`); it is per-machine and
  not in git, so edit that file directly if the detection guesses wrong (e.g. an
  NVIDIA box with `nvidia-vaapi-driver` installed can go back to
  `LIBVA_DRIVER_NAME=nvidia` and `MPV_HWDEC=auto`).
* Check `~/.config/dotfiles/local.conf` and `local.lua` -- the installer's
  guesses (small-screen scale, dropped bar modules, monitor layout) are a
  starting point, not gospel.

## Per-machine config

This repo is symlinked wholesale into `~/.config` (`link.sh`), so anything
written there syncs to every machine that clones it. Git holds **how the
system is supposed to work**; two files outside the repo hold **what this
particular box is**:

| File | Read by | Holds |
|---|---|---|
| `~/.config/dotfiles/local.conf` | shell scripts, `quickshell/Local.qml` | UI scale, which bar modules run, poll intervals, wallpaper |
| `~/.config/dotfiles/local.lua` | `hypr/hyprland.lua` | monitor rules, workspace pinning, keyboard layout, optional autostarts |
| `~/.zshrc.local` | `.zshrc` (sourced at the end) | `$CLAUDE_OBSIDIAN_VAULT`, the NVIDIA VS Code workaround, anything else true only on this box |

All three are **generated once by `install.sh` from hardware probes and never
overwritten after that** -- the same contract `20-va.conf` already used for
GPU video decode. Edit them freely; re-run with `--reconfigure` to redo
detection (the old files are backed up, never discarded). A missing file (a
fresh clone before the first `install.sh` run) just means every default below
matches what the desktop looked like before this mechanism existed.

**Rule of thumb: if a value would be wrong copied onto another PC, it belongs
in `local.conf` or `local.lua`, not in a tracked config.**

### `local.conf` keys

```sh
# UI scale -- multiplies every geometry/font value in Theme.qml. This is the
# "make the bar fit a small screen" lever.
UI_SCALE=1.0
BAR_HEIGHT=       # blank = derive from UI_SCALE; set to override outright
FONT_SIZE_BAR=
DASHBOARD_W=
DASHBOARD_H=
FONT=             # blank = MesloLGS NF

# Bar modules, comma-separated per section. A name left out is dropped
# entirely; an empty value hides that pill. Bar.qml's registry has the full
# list: workspaces, submap, clock, gpu, sys, battery, network, bluetooth,
# audio, language.
BAR_LEFT=workspaces,submap,clock
BAR_CENTER=gpu,sys,battery
BAR_RIGHT=network,bluetooth,audio,language

# Expensive pollers. 0 disables the poller outright, not just the widget.
SVC_WEATHER=1
SVC_CLAUDE_USAGE=1
SVC_GPU=1
SYSMON_INTERVAL_FAST=2000
SYSMON_INTERVAL_SLOW=10000

# Seeds hypr/wallpaper.conf on first run.
WALLPAPER=
```

### `local.lua` shape

```lua
return {
    monitors = {
        { output = "DP-1", mode = "preferred", position = "auto", scale = 1 },
        { output = "",     mode = "preferred", position = "auto", scale = 1 }, -- catch-all
    },
    -- { first_workspace, last_workspace, monitor }
    workspaces = {
        { 1, 5,  "eDP-1" },
        { 6, 10, "desc:Dell Inc. DELL P2422H F4JL9D3" },
    },
    kb_layout = "us,ru",
    gaps_out = 8,   -- keep matching Theme.barMarginSide if UI_SCALE changes it
    autostart = { hypridle = true },
}
```

Any key (or the whole file) can be omitted; `hypr/hyprland.lua` falls back to
its generic defaults (`eDP-1` + catch-all monitor, workspaces 1-5 on `eDP-1`,
`kb_layout = "us,ru"`, `hypridle` off).

Requires **Hyprland 0.56+** -- the config is `hypr/hyprland.lua`, not
`hyprland.conf`, and Lua configs are a recent feature. Tested on 0.56.2.

## Used packages

The authoritative list is the `PKGS_*` / `AUR_*` arrays in `install.sh`; this is
the why behind them.

* __rofi__ for launching software and the power menu (`SUPER+D`, `SUPER+SHIFT+S`)
* __hyprland__ as the compositor/WM, with __mpvpaper__ for the video wallpaper
* __kitty__ as the terminal emulator -- its native graphics protocol lets
  __ranger__ preview images inline with no overlay process
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

The wallpaper is machine state, not configuration: `hypr/wallpaper.conf` holds
the current path and is **not tracked in git** (see `.gitignore`), same as
every generated `colors.*` file below -- a wallpaper picked on one PC no
longer produces a diff, let alone a merge conflict, on another.
`hypr/scripts/wallpaper-daemon.sh` (mpvpaper -- hyprpaper is gone, since it
only handles stills and mpvpaper covers both) starts the daemon at session
login and after every change.

One accent colour is derived from the wallpaper by **matugen** and pushed into
quickshell, rofi, hyprland, hyprlock, kitty, starship and GTK. Change
wallpaper and
accent together with `SUPER+W` (or `hypr/scripts/set-wallpaper.sh`), which takes
images and videos alike -- for a video it pulls a frame with ffmpeg and themes
from that. Never edit the generated `colors.*` files, edit `matugen/templates/`
instead. Each config imports its generated file first and may override anything
below the import -- except starship, which is built rather than imported (see
below). A committed snapshot in `matugen/defaults/` seeds all of them on a
fresh clone, before `set-wallpaper.sh` ever runs, so the desktop always comes
up themed.

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
