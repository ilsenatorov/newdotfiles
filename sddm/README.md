# sddm

The [sddm-astronaut-theme](https://github.com/Keyitdev/sddm-astronaut-theme) by
keyitdev (GPL-3.0), stripped to the single variant this machine uses: the
pixel_sakura layout with a Disco Elysium video background, retyped in Noto Serif
Display Light and recoloured with a palette sampled from that video (harbour ink
`#04242F`, deep navy fields, sun-gold text, amber/rust accents). Upstream ships
10 variants with ~36 MB of backgrounds, videos and fonts; only one is needed, so
this is ~1 MB.

The single active config is `theme/Themes/main.conf`, and
`theme/metadata.desktop` must always point at it via `ConfigFile=`. If those two
disagree the greeter silently loads *no* config and renders an unstyled white
form -- it does not error.

Not symlinked by `link.sh` -- SDDM reads its theme from `/usr/share/sddm/themes`
and its config from `/etc`, neither of which is under `$HOME`. Run instead:

    sudo ./install.sh

## What's here and why

| Path | Why it's needed |
| --- | --- |
| `theme/Main.qml` | the greeter entry point (`MainScript` in `metadata.desktop`) |
| `theme/metadata.desktop` | tells SDDM which QML to run and which variant conf to read; `ConfigFile=Themes/pixel_sakura.conf` is what selects pixel_sakura |
| `theme/Themes/main.conf` | all the colours, the font name, `FieldOpacity`, and the background path |
| `theme/Components/*.qml` | clock, login form, session picker, system buttons, virtual keyboard -- all imported by `Main.qml` |
| `theme/Assets/*.svg` | user/password icons and the shutdown/reboot/suspend/hibernate icons, referenced by `Input.qml` and `SystemButtons.qml` |
| `theme/Backgrounds/pixel_sakura.gif` | fallback background, used automatically if the video is missing |
| `theme/LICENSE` | GPL-3.0, has to travel with the code |
| `etc/sddm.conf` | selects the theme |
| `etc/sddm.conf.d/virtualkbd.conf` | enables the qtvirtualkeyboard input method the theme's keyboard button drives |

Dropped from upstream: the other 9 `Themes/*.conf` and their backgrounds/videos,
the unused fonts, `Previews/`, `setup.sh`, `.github/`, and the upstream README.

## The video background

`main.conf` sets `Background="Backgrounds/Disco-Elysium-4k.mp4"`. That file is
91 MB and is **not** in git (see `Backgrounds/.gitignore`); `install.sh` copies
it in from `$HOME_WALLPAPER` (override with `WALLPAPER=/path/to.mp4 sudo -E
./install.sh`). If it is missing, `install.sh` rewrites the installed config to
fall back to `pixel_sakura.gif`.

The path must stay **relative to the theme dir**. An absolute path into
`~/Pictures` cannot work: the greeter runs as the unprivileged `sddm` user
(uid 951) and `/home/ilya` is `drwx------`, so it cannot even traverse it.

Video decode falls back to software -- the MX250 reports no supported h264
decoder and cuda hwaccel init fails. It still renders fine.

## Switching variant

Only this one variant is vendored. To use another, copy its `.conf` and
background out of upstream over `theme/Themes/main.conf`, install whatever font
it names system-wide, and re-run `install.sh`. Note that the QML here has been
edited away from upstream: the field backgrounds read `FieldOpacity` from the
conf instead of a hardcoded `0.2`, and the clock uses weights rather than
`font.bold`.

## Dependencies

`sddm qt6-svg qt6-virtualkeyboard qt6-multimedia qt6-declarative noto-fonts` --
`install.sh` installs these on pacman systems. `Font="Noto Serif Display"` is a
*family name* lookup, so the font has to be a real system font (it comes from
`noto-fonts`); the theme dir is not a font path.

## Preview without logging out

    sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/sddm-astronaut-theme
